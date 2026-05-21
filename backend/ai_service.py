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


def get_ai_recommendation(user_prompt: str, menu_context: list) -> dict:
    menu_lines = "\n".join(
        f"- {item['name']} | {item['category']} | Rs. {item['price']}"
        + (f" | {item['description']}" if item.get("description") else "")
        for item in menu_context[:50]
    )

    system = (
        f"You are a friendly AI waiter at {Config.RESTAURANT_NAME}, an Indian restaurant. "
        "Suggest food items from the menu below based on the customer's preference. "
        "Keep the tone warm, conversational, and concise. "
        "Recommend 3 to 4 items with a one-line reason for each. "
        "Never invent items or prices. Only recommend items present in the menu list. "
        "Do not add section headers or bullet formatting — write naturally.\n\n"
        f"Menu:\n{menu_lines}"
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

        category = str(parsed.get("category", "")).strip()
        sentiment = str(parsed.get("sentiment", "")).strip()
        priority = str(parsed.get("priority", "")).strip()

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
