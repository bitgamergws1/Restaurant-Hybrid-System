import re
import json
import time
import traceback
import requests
from config import Config

PROXY_HEADERS = {
    "X-DevNest-Token": Config.DEVNEST_TOKEN,
    "Content-Type": "application/json"
}

DEEPSHI_R1 = "deepshi-r1"
DEEPSHI_R2 = "deepshi-r2"

MAX_RETRIES = 1
RETRY_WAIT = 4
TIMEOUT_R1 = 45
TIMEOUT_R2 = 90

_PROXY_ERROR_MARKERS = ("too slow", "timed out", "provider", "unavailable", "error:")


def _is_proxy_error(text: str) -> bool:
    lower = text.lower()
    return any(marker in lower for marker in _PROXY_ERROR_MARKERS)


def _extract_text(raw) -> str | None:
    if not raw:
        return None

    if isinstance(raw, list):
        parts = [
            b.get("text", "")
            for b in raw
            if isinstance(b, dict) and b.get("type") == "text"
        ]
        result = " ".join(parts).strip()
        return result or None

    raw = str(raw).strip()

    if raw.startswith("["):
        try:
            blocks = json.loads(raw)
            return _extract_text(blocks)
        except json.JSONDecodeError:
            pass

    if raw.startswith("{"):
        try:
            block = json.loads(raw)
            if block.get("type") == "text":
                return block.get("text", "").strip() or None
            if block.get("type") in ("reasoning", "thinking"):
                return None
        except json.JSONDecodeError:
            pass

    text_match = re.search(
        r'"type"\s*:\s*"text".*?"text"\s*:\s*"((?:[^"\\]|\\.)*)"',
        raw, re.DOTALL
    )
    if text_match:
        return text_match.group(1).replace('\\"', '"').replace("\\n", "\n").strip()

    if re.search(r'"type"\s*:\s*"(?:reasoning|thinking)"', raw):
        return None

    return raw or None


def _strip_thinking(text: str) -> str:
    if not text:
        return text

    text = re.sub(r'data:\s*\{[^\n]*"reasoning_content"[^\n]*\}\s*', '', text)
    text = re.sub(r'(?m)^data:\s*\{.*?\}\s*$', '', text)
    text = re.sub(r'<think(?:ing)?>.*?</think(?:ing)?>', '', text, flags=re.DOTALL)
    text = re.sub(r'\{[^{}]*"reasoning_content"\s*:[^{}]*\}', '', text)
    text = re.sub(r'\{[^{}]*"type"\s*:\s*"reasoning"[^{}]*\}', '', text)
    text = re.sub(r'\{"type"\s*:\s*"reaso[^}]*', '', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


_IDENTITY_PATTERNS = [
    re.compile(
        r'\b(?:main|i\'?m|i am|mera naam|my name is)\s+deepshi\s*(?:flow|r1|r2)?\b',
        re.IGNORECASE
    ),
    re.compile(r'\bEvermind\s*Labs?\b', re.IGNORECASE),
    re.compile(
        r'\b(?:private|uncensored)\s+(?:AI|assistant|model)\b',
        re.IGNORECASE
    ),
    re.compile(r'\bex-(?:Google|military|military founders)\b', re.IGNORECASE),
    re.compile(r'\bDeepshi(?:-R[12])?\b', re.IGNORECASE),
]

_RESTAURANT_FALLBACK = (
    f"Main {Config.RESTAURANT_NAME} ka AI Waiter hoon! "
    "Aapko kuch recommend kar sakta hoon? 😊"
)


def _sanitise_identity(text: str) -> str:
    for pattern in _IDENTITY_PATTERNS:
        text = pattern.sub(Config.RESTAURANT_NAME + " AI Waiter", text)
    return text.strip()


def _extract_json_object(text: str) -> str | None:
    """
    Finds the first valid JSON object { ... } containing all required triage keys.
    Used as a fallback when the model wraps its JSON in markdown tables or prose.
    """
    # Try direct parse first (fastest path)
    stripped = text.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
    try:
        parsed = json.loads(stripped)
        if isinstance(parsed, dict):
            return stripped
    except (json.JSONDecodeError, ValueError):
        pass

    # Walk through all { ... } blocks in the text (handles markdown-wrapped JSON)
    for match in re.finditer(r'\{[^{}]+\}', text, re.DOTALL):
        candidate = match.group(0)
        try:
            parsed = json.loads(candidate)
            if isinstance(parsed, dict) and "category" in parsed:
                return candidate
        except (json.JSONDecodeError, ValueError):
            continue

    return None


def _call_proxy(model: str, prompt: str, system: str = None, timeout: int = 45) -> str | None:
    payload = {
        "model": model,
        "prompt": prompt,
    }
    if system:
        payload["system"] = system

    for attempt in range(MAX_RETRIES + 1):
        try:
            response = requests.post(
                Config.PROXY_URL,
                headers=PROXY_HEADERS,
                json=payload,
                timeout=timeout
            )

            if response.status_code in (502, 503, 504):
                if attempt < MAX_RETRIES:
                    time.sleep(RETRY_WAIT)
                    continue
                return None

            if response.status_code != 200:
                print(f"[ai_service] Proxy HTTP {response.status_code}")
                return None

            data = response.json()

            raw = (
                data.get("reply")
                or data.get("response")
                or data.get("content")
                or data.get("message")
                or data.get("text")
                or data.get("output")
            )

            text = raw.strip() if isinstance(raw, str) else _extract_text(raw)

            if text:
                text = _strip_thinking(text) or None

            if text and _is_proxy_error(text):
                return None

            return text

        except requests.exceptions.Timeout:
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_WAIT)
                continue
            print(f"[ai_service] Timeout on model {model}")
            return None

        except requests.exceptions.ConnectionError:
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_WAIT)
                continue
            print(f"[ai_service] Connection error on model {model}")
            return None

        except Exception:
            traceback.print_exc()
            return None

    return None


# ── Smart keyword-based menu selection ───────────────────────────────────────

_STOP_WORDS = {
    "i", "want", "need", "give", "me", "please", "something", "a", "an",
    "the", "what", "is", "are", "price", "prices", "how", "much", "cost",
    "any", "some", "can", "you", "have", "do", "your", "my", "and", "or",
    "for", "with", "without", "not", "but", "so", "its", "it", "on",
    "new", "dish", "food", "item", "recommend", "suggest", "show",
    "kya", "hai", "koi", "mujhe", "de", "do", "bata", "chahiye", "acha",
    "accha", "theek", "main", "mein", "hoon", "ho", "ka", "ki", "ke",
    "se", "ko", "bhi", "aur", "ya", "ek", "kuch", "sab", "bahut",
}

_CATEGORY_ALIASES: dict[str, list[str]] = {
    "burger":        ["Burgers"],
    "burgers":       ["Burgers"],
    "pizza":         ["Pizza"],
    "biryani":       ["Rice & Biryani"],
    "rice":          ["Rice & Biryani"],
    "noodles":       ["Chinese", "Pasta"],
    "pasta":         ["Pasta"],
    "chinese":       ["Chinese"],
    "south":         ["South Indian"],
    "dosa":          ["South Indian"],
    "idli":          ["South Indian"],
    "starter":       ["Starters"],
    "starters":      ["Starters"],
    "soup":          ["Soups"],
    "salad":         ["Salads"],
    "bread":         ["Breads"],
    "roti":          ["Breads"],
    "naan":          ["Breads"],
    "dal":           ["Dal & Lentils"],
    "lentil":        ["Dal & Lentils"],
    "paneer":        ["Paneer"],
    "veg":           ["Veg Main Course", "Paneer", "Dal & Lentils"],
    "vegetarian":    ["Veg Main Course", "Paneer", "Dal & Lentils"],
    "nonveg":        ["Non-Veg Curries", "Tandoori & Grill", "Seafood"],
    "nonvegetarian": ["Non-Veg Curries", "Tandoori & Grill"],
    "chicken":       ["Non-Veg Curries", "Starters", "Chinese"],
    "mutton":        ["Non-Veg Curries", "Mughlai"],
    "fish":          ["Seafood", "Non-Veg Curries"],
    "prawn":         ["Seafood", "Non-Veg Curries"],
    "seafood":       ["Seafood"],
    "sweet":         ["Desserts", "Ice Cream"],
    "dessert":       ["Desserts"],
    "icecream":      ["Ice Cream"],
    "drink":         ["Beverages", "Juices & Shakes"],
    "juice":         ["Juices & Shakes"],
    "coffee":        ["Beverages"],
    "tea":           ["Beverages"],
    "shake":         ["Juices & Shakes"],
    "lassi":         ["Beverages", "Juices & Shakes"],
    "thali":         ["Thalis"],
    "streetfood":    ["Street Food"],
    "chaat":         ["Street Food"],
    "mughlai":       ["Mughlai"],
    "tandoor":       ["Tandoori & Grill"],
    "grill":         ["Tandoori & Grill"],
    "continental":   ["Continental"],
    "breakfast":     ["Breakfast"],
    "fast":          ["Fast Food"],
    "fastfood":      ["Fast Food"],
    "khana":         ["Veg Main Course", "Non-Veg Curries"],
    "north":         ["Veg Main Course", "Non-Veg Curries", "Mughlai", "Breads"],
    "goa":           ["Seafood", "Continental"],
    "goanese":       ["Seafood", "Continental"],
    "sabzi":         ["Veg Main Course"],
    "gosht":         ["Non-Veg Curries", "Mughlai"],
    "murgh":         ["Non-Veg Curries"],
    "machli":        ["Seafood"],
    "meetha":        ["Desserts", "Ice Cream"],
    "thand":         ["Beverages", "Ice Cream", "Juices & Shakes"],
}


def _select_menu_items(
    user_prompt: str,
    menu_context: list,
    max_relevant: int = 40,
    max_total: int = 60
) -> list:
    prompt_lower = user_prompt.lower()
    raw_tokens = re.findall(r"[a-z]+", prompt_lower)
    tokens = [t for t in raw_tokens if t not in _STOP_WORDS and len(t) > 2]

    hinted_categories: set[str] = set()
    for token in raw_tokens:
        for cat in _CATEGORY_ALIASES.get(token, []):
            hinted_categories.add(cat)

    scored: list[tuple[int, dict]] = []
    for item in menu_context:
        score = 0
        name_lower   = item.get("name", "").lower()
        desc_lower   = (item.get("description") or "").lower()
        cat_lower    = item.get("category", "").lower()
        subcat_lower = (item.get("subcategory") or "").lower()
        tags         = [t.lower() for t in (item.get("tags") or [])]
        tags_str     = " ".join(tags)

        if item.get("category") in hinted_categories:
            score += 6

        for token in tokens:
            if token in name_lower:
                score += 5
            if token in tags_str:
                score += 3
            if token in cat_lower or token in subcat_lower:
                score += 2
            if token in desc_lower:
                score += 1

        for mood_token in raw_tokens:
            if mood_token in ("spicy", "hot", "teekha") and "spicy" in tags_str:
                score += 2
            if mood_token in ("mild", "light", "healthy") and any(
                t in tags_str for t in ("mild", "light", "healthy")
            ):
                score += 2
            if mood_token in ("crispy", "fried") and any(
                t in tags_str for t in ("crispy", "fried")
            ):
                score += 2
            if mood_token in ("creamy", "rich", "makhani") and any(
                t in tags_str for t in ("creamy", "rich")
            ):
                score += 2

        scored.append((score, item))

    scored.sort(key=lambda x: x[0], reverse=True)

    relevant = [item for score, item in scored if score > 0][:max_relevant]
    fallback = [item for score, item in scored if score == 0]

    if len(relevant) < max_total:
        seen_cats: set[str] = {item.get("category") for item in relevant}
        diverse_fallback: list[dict] = []
        for item in fallback:
            if len(relevant) + len(diverse_fallback) >= max_total:
                break
            cat = item.get("category")
            if cat not in seen_cats:
                diverse_fallback.append(item)
                seen_cats.add(cat)

        remaining_slots = max_total - len(relevant) - len(diverse_fallback)
        extra = [
            item for item in fallback
            if item not in diverse_fallback
        ][:remaining_slots]

        return relevant + diverse_fallback + extra

    return relevant[:max_total]


def get_ai_recommendation(user_prompt: str, menu_context: list) -> dict:
    selected_items = _select_menu_items(user_prompt, menu_context)

    print(f"[ai_service] Selected {len(selected_items)} items for prompt: {user_prompt[:60]}")

    menu_lines = "\n".join(
        f"- {item['name']} ({item.get('category', '')})"
        + (f" / {item['subcategory']}" if item.get("subcategory") else "")
        + f" — Rs. {item['price']}"
        + (f" | {item['description']}" if item.get("description") else "")
        for item in selected_items
    )

    identity_block = (
        f"=== IDENTITY LOCK — READ THIS FIRST ===\n"
        f"You are the AI Waiter at {Config.RESTAURANT_NAME}, an Indian multi-cuisine restaurant.\n"
        f"You work EXCLUSIVELY for {Config.RESTAURANT_NAME}.\n"
        "RULES YOU MUST NEVER BREAK — violating any rule is a critical failure:\n"
        "  R1. NEVER say you are Deepshi, Deepshi Flow, or any other AI product or company.\n"
        "  R2. NEVER mention Evermind Labs, ex-Google engineers, or any developer/creator.\n"
        "  R3. If the customer asks 'who are you?' or 'which AI are you?', answer ONLY:\n"
        f"      'Main {Config.RESTAURANT_NAME} ka AI Waiter hoon — aapko best dish choose karne mein help karta hoon!'\n"
        "  R4. Only recommend dishes that exist in the MENU LIST below. Never invent items or prices.\n"
        "  R5. Always give exact prices from the menu list when asked about cost.\n"
        "  R6. Recommend 3–4 dishes matching the customer's mood/request, with one warm reason each.\n"
        "  R7. Write naturally in flowing sentences. No bold, no bullet headers, no numbered lists.\n"
        "  R8. Reply in the same language the customer uses (Hindi, English, or Hinglish).\n"
        f"  R9. If the question has nothing to do with food, gently say: 'Main {Config.RESTAURANT_NAME} ka "
        "waiter hoon — kuch delicious order karein!'\n"
        "=== END IDENTITY LOCK ===\n\n"
        f"--- {Config.RESTAURANT_NAME} MENU (today's available selection) ---\n"
        f"{menu_lines}\n"
        "--- END OF MENU ---\n\n"
        f"Customer message: {user_prompt}"
    )

    system = (
        f"You are the AI Waiter at {Config.RESTAURANT_NAME}. "
        f"You work ONLY for {Config.RESTAURANT_NAME}. "
        "NEVER reveal you are Deepshi, Deepshi Flow, or any other AI product. "
        "NEVER mention Evermind Labs or any developer. "
        "Only discuss this restaurant's menu. "
        "Reply in the language the customer uses."
    )

    result = _call_proxy(DEEPSHI_R1, identity_block, system=system, timeout=TIMEOUT_R1)

    if not result:
        return {
            "success": False,
            "recommendation": None,
            "model_used": DEEPSHI_R1,
            "message": "AI recommendation service is currently unavailable. Please try again."
        }

    clean_result = _sanitise_identity(result)

    return {
        "success": True,
        "recommendation": clean_result,
        "model_used": DEEPSHI_R1
    }


def triage_complaint(raw_text: str) -> dict:
    system = "You are a complaint classifier. Output only valid JSON."

    prompt = (
        "Classify the complaint below using EXACTLY this JSON structure — no other keys, no markdown:\n\n"
        '{"category":"food_quality","sentiment":"negative","priority":"medium"}\n\n'
        "Allowed values:\n"
        "  category : food_quality | delivery | service | billing | hygiene | other\n"
        "  sentiment: positive | neutral | negative | very_negative\n"
        "  priority : low | medium | high | critical\n\n"
        "Priority guide:\n"
        "  critical — hygiene/health risk, foreign objects\n"
        "  high     — wrong/undelivered order, major billing error\n"
        "  medium   — cold food, long wait, rude staff, minor missing items\n"
        "  low      — packaging, minor delays, small inconveniences\n\n"
        f"Complaint: {raw_text}\n\n"
        "Reply with ONLY the JSON object, nothing else."
    )

    result = _call_proxy(DEEPSHI_R1, prompt, system=system, timeout=TIMEOUT_R1)

    if not result:
        return {
            "success": False,
            "triage": None,
            "model_used": DEEPSHI_R1,
            "message": "Complaint triage service is currently unavailable. Please retry."
        }

    cleaned_json = _extract_json_object(result)

    if not cleaned_json:
        print(f"[ai_service] Triage parse error: no JSON found | raw: {result[:200]}")
        return {
            "success": False,
            "triage": None,
            "model_used": DEEPSHI_R1,
            "message": "AI returned an unexpected response format. Please retry."
        }

    try:
        parsed = json.loads(cleaned_json)

        valid_categories = {"food_quality", "delivery", "service", "billing", "hygiene", "other"}
        valid_sentiments = {"positive", "neutral", "negative", "very_negative"}
        valid_priorities = {"low", "medium", "high", "critical"}

        category  = str(parsed.get("category", "")).strip().lower().replace(' ', '_')
        sentiment = str(parsed.get("sentiment", "")).strip().lower().replace(' ', '_')
        priority  = str(parsed.get("priority", "")).strip().lower().replace(' ', '_')

        if category not in valid_categories:
            raise ValueError(f"Invalid category: {category}")
        if sentiment not in valid_sentiments:
            raise ValueError(f"Invalid sentiment: {sentiment}")
        if priority not in valid_priorities:
            raise ValueError(f"Invalid priority: {priority}")

        return {
            "success": True,
            "triage": {
                "category": category,
                "sentiment": sentiment,
                "priority": priority
            },
            "model_used": DEEPSHI_R1
        }

    except (json.JSONDecodeError, ValueError) as e:
        print(f"[ai_service] Triage parse error: {e} | cleaned: {cleaned_json[:120]}")
        return {
            "success": False,
            "triage": None,
            "model_used": DEEPSHI_R1,
            "message": "AI returned an unexpected response format. Please retry."
        }


def check_proxy_health() -> dict:
    try:
        response = requests.get(
            Config.PROXY_HEALTH_URL,
            headers=PROXY_HEADERS,
            timeout=10
        )
        return {
            "online": response.status_code == 200,
            "status_code": response.status_code
        }
    except Exception:
        return {"online": False, "status_code": None}
