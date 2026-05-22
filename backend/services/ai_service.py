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
TIMEOUT_R1 = 35
TIMEOUT_R2 = 70

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

    # raw SSE lines leaked into reply
    text = re.sub(r'data:\s*\{[^\n]*"reasoning_content"[^\n]*\}\s*', '', text)
    text = re.sub(r'(?m)^data:\s*\{.*?\}\s*$', '', text)

    # XML-style thinking blocks
    text = re.sub(r'<think(?:ing)?>.*?</think(?:ing)?>', '', text, flags=re.DOTALL)

    # orphaned reasoning_content JSON
    text = re.sub(r'\{[^{}]*"reasoning_content"\s*:[^{}]*\}', '', text)

    # type:reasoning blocks
    text = re.sub(r'\{[^{}]*"type"\s*:\s*"reasoning"[^{}]*\}', '', text)
    text = re.sub(r'\{"type"\s*:\s*"reaso[^}]*', '', text)

    # collapse excessive blank lines
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def _call_proxy(model: str, prompt: str, system: str = None, timeout: int = 35) -> str | None:
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


# ── FIX: smart keyword-based menu selection ──────────────────────────────────
# Problem was menu_context[:50] — only first 50 items by sort_order were sent,
# so most of the 700-item menu was invisible to the AI.
# Now we score items by keyword relevance to the user prompt and send the top
# 60 matches (up to 40 relevant + 20 popular fallbacks), covering the whole menu.

_STOP_WORDS = {
    "i", "want", "need", "give", "me", "please", "something", "a", "an",
    "the", "what", "is", "are", "price", "prices", "how", "much", "cost",
    "any", "some", "can", "you", "have", "do", "your", "my", "and", "or",
    "for", "with", "without", "not", "but", "so", "its", "it", "on",
    "new", "dish", "food", "item", "recommend", "suggest", "show",
}

_CATEGORY_ALIASES: dict[str, list[str]] = {
    "burger":      ["Burgers"],
    "burgers":     ["Burgers"],
    "pizza":       ["Pizza"],
    "biryani":     ["Rice & Biryani"],
    "rice":        ["Rice & Biryani"],
    "noodles":     ["Chinese", "Pasta"],
    "pasta":       ["Pasta"],
    "chinese":     ["Chinese"],
    "south":       ["South Indian"],
    "dosa":        ["South Indian"],
    "idli":        ["South Indian"],
    "starter":     ["Starters"],
    "starters":    ["Starters"],
    "soup":        ["Soups"],
    "salad":       ["Salads"],
    "bread":       ["Breads"],
    "roti":        ["Breads"],
    "naan":        ["Breads"],
    "dal":         ["Dal & Lentils"],
    "lentil":      ["Dal & Lentils"],
    "paneer":      ["Paneer"],
    "veg":         ["Veg Main Course", "Paneer", "Dal & Lentils"],
    "vegetarian":  ["Veg Main Course", "Paneer", "Dal & Lentils"],
    "nonveg":      ["Non-Veg Curries", "Tandoori & Grill", "Seafood"],
    "nonvegetarian": ["Non-Veg Curries", "Tandoori & Grill"],
    "chicken":     ["Non-Veg Curries", "Starters", "Chinese"],
    "mutton":      ["Non-Veg Curries", "Mughlai"],
    "fish":        ["Seafood", "Non-Veg Curries"],
    "prawn":       ["Seafood", "Non-Veg Curries"],
    "seafood":     ["Seafood"],
    "sweet":       ["Desserts", "Ice Cream"],
    "dessert":     ["Desserts"],
    "icecream":    ["Ice Cream"],
    "drink":       ["Beverages", "Juices & Shakes"],
    "juice":       ["Juices & Shakes"],
    "coffee":      ["Beverages"],
    "tea":         ["Beverages"],
    "shake":       ["Juices & Shakes"],
    "lassi":       ["Beverages", "Juices & Shakes"],
    "thali":       ["Thalis"],
    "streetfood":  ["Street Food"],
    "chaat":       ["Street Food"],
    "mughlai":     ["Mughlai"],
    "tandoor":     ["Tandoori & Grill"],
    "grill":       ["Tandoori & Grill"],
    "continental": ["Continental"],
    "breakfast":   ["Breakfast"],
    "fast":        ["Fast Food"],
    "fastfood":    ["Fast Food"],
}


def _select_menu_items(user_prompt: str, menu_context: list, max_relevant: int = 40, max_total: int = 60) -> list:
    """
    Score every item against the user prompt and return the most relevant ones.
    Falls back to a spread of popular items when nothing matches well.
    """
    prompt_lower = user_prompt.lower()

    # tokenise — remove stop words
    raw_tokens = re.findall(r"[a-z]+", prompt_lower)
    tokens = [t for t in raw_tokens if t not in _STOP_WORDS and len(t) > 2]

    # resolve category hints from aliases
    hinted_categories: set[str] = set()
    for token in raw_tokens:
        for cats in _CATEGORY_ALIASES.get(token, []):
            hinted_categories.add(cats)

    scored: list[tuple[int, dict]] = []
    for item in menu_context:
        score = 0
        name_lower   = item.get("name", "").lower()
        desc_lower   = (item.get("description") or "").lower()
        cat_lower    = item.get("category", "").lower()
        subcat_lower = (item.get("subcategory") or "").lower()
        tags         = [t.lower() for t in (item.get("tags") or [])]
        tags_str     = " ".join(tags)

        # exact category hint (strong signal)
        if item.get("category") in hinted_categories:
            score += 6

        for token in tokens:
            if token in name_lower:
                score += 5          # name match is most valuable
            if token in tags_str:
                score += 3
            if token in cat_lower or token in subcat_lower:
                score += 2
            if token in desc_lower:
                score += 1

        # spicy / mild / light hints via tags
        for mood_token in raw_tokens:
            if mood_token in ("spicy", "hot") and "spicy" in tags_str:
                score += 2
            if mood_token in ("mild", "light", "healthy") and any(
                t in tags_str for t in ("mild", "light", "healthy")
            ):
                score += 2
            if mood_token in ("crispy", "fried") and any(
                t in tags_str for t in ("crispy", "fried")
            ):
                score += 2
            if mood_token in ("creamy", "rich") and any(
                t in tags_str for t in ("creamy", "rich")
            ):
                score += 2

        scored.append((score, item))

    # sort by score descending
    scored.sort(key=lambda x: x[0], reverse=True)

    relevant   = [item for score, item in scored if score > 0][:max_relevant]
    fallback   = [item for score, item in scored if score == 0]

    # pick a diverse fallback spread across categories when we need padding
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

        # if still need more, just append
        remaining_slots = max_total - len(relevant) - len(diverse_fallback)
        extra = [
            item for item in fallback
            if item not in diverse_fallback
        ][:remaining_slots]

        return relevant + diverse_fallback + extra

    return relevant[:max_total]


def get_ai_recommendation(user_prompt: str, menu_context: list) -> dict:
    # ── FIX: use smart selection instead of naive [:50] ──
    selected_items = _select_menu_items(user_prompt, menu_context)

    menu_lines = "\n".join(
        f"- {item['name']} ({item['category']}) — Rs. {item['price']}"
        + (f" | {item['description']}" if item.get("description") else "")
        for item in selected_items
    )

    # ── FIX: stronger system prompt to prevent model from breaking character ──
    system = (
        f"You are the AI Waiter at {Config.RESTAURANT_NAME}, an Indian multi-cuisine restaurant. "
        f"Your ONLY job is to help customers choose dishes from the {Config.RESTAURANT_NAME} menu listed below. "
        "STRICT RULES you must NEVER break:\n"
        "1. You are the AI Waiter of this restaurant — never say you are any other AI, product, or company.\n"
        "2. Only recommend items that exist in the menu list below. Never invent dishes or prices.\n"
        "3. Always answer in the context of this restaurant's menu. If the customer asks about prices, "
        "give the exact price from the menu list.\n"
        "4. Recommend 3–4 dishes that match the customer's mood or request, with one warm reason each.\n"
        "5. Keep tone warm, helpful, and conversational — like a friendly human waiter.\n"
        "6. Do not use bullet headers, bold markdown, or numbered lists — write naturally in flowing sentences.\n"
        "7. If the customer asks something completely unrelated to food or the restaurant, "
        f"gently steer them back: 'I'm your waiter at {Config.RESTAURANT_NAME} — let me help you pick "
        "something delicious from our menu!'\n\n"
        f"--- {Config.RESTAURANT_NAME} MENU (today's selection) ---\n"
        f"{menu_lines}\n"
        "--- END OF MENU ---"
    )

    result = _call_proxy(DEEPSHI_R1, user_prompt, system=system, timeout=TIMEOUT_R1)

    if not result:
        return {
            "success": False,
            "recommendation": None,
            "model_used": DEEPSHI_R1,
            "message": "AI recommendation service is currently unavailable. Please try again."
        }

    return {
        "success": True,
        "recommendation": result,
        "model_used": DEEPSHI_R1
    }


def triage_complaint(raw_text: str) -> dict:
    system = (
        "You are a complaint triage engine for a restaurant management system. "
        "Analyse the customer complaint and classify it. "
        "Respond with ONLY a raw JSON object — no markdown, no backticks, no explanation. "
        "The JSON must have exactly these three keys:\n"
        '{"category": "<food_quality|delivery|service|billing|hygiene|other>", '
        '"sentiment": "<positive|neutral|negative|very_negative>", '
        '"priority": "<low|medium|high|critical>"}\n\n'
        "Priority rules:\n"
        "- critical: hygiene issues, health risk, foreign objects in food\n"
        "- high: completely wrong order, food not delivered, major billing error\n"
        "- medium: cold food, long wait, minor missing items, rude staff\n"
        "- low: small inconveniences, packaging issues, minor delays"
    )

    prompt = f"Customer complaint: {raw_text}"

    result = _call_proxy(DEEPSHI_R2, prompt, system=system, timeout=TIMEOUT_R2)

    if not result:
        return {
            "success": False,
            "triage": None,
            "model_used": DEEPSHI_R2,
            "message": "Complaint triage service is currently unavailable. Please retry."
        }

    cleaned = (
        result.strip()
        .removeprefix("```json")
        .removeprefix("```")
        .removesuffix("```")
        .strip()
    )

    try:
        parsed = json.loads(cleaned)

        valid_categories = {"food_quality", "delivery", "service", "billing", "hygiene", "other"}
        valid_sentiments = {"positive", "neutral", "negative", "very_negative"}
        valid_priorities = {"low", "medium", "high", "critical"}

        category  = str(parsed.get("category", "")).strip()
        sentiment = str(parsed.get("sentiment", "")).strip()
        priority  = str(parsed.get("priority", "")).strip()

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
            "model_used": DEEPSHI_R2
        }

    except (json.JSONDecodeError, ValueError) as e:
        print(f"[ai_service] Triage parse error: {e} | raw: {result[:120]}")
        return {
            "success": False,
            "triage": None,
            "model_used": DEEPSHI_R2,
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
