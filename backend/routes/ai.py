from flask import Blueprint, request
from extensions import get_db
from middleware.auth_middleware import require_auth
from services.ai_service import get_ai_recommendation, triage_complaint, check_proxy_health
from utils.response import success_response, error_response
from utils.validators import validate_required_fields, validate_uuid

ai_bp = Blueprint("ai", __name__)


# ai waiter recommendation
@ai_bp.route("/recommend", methods=["POST"])
@require_auth
def recommend():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    missing = validate_required_fields(data, ["prompt"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    prompt = str(data["prompt"]).strip()
    if len(prompt) < 3:
        return error_response("Prompt is too short", 400)

    if len(prompt) > 1000:
        return error_response("Prompt must be under 1000 characters", 400)

    db = get_db()
    menu_result = db.table("menu_items").select(
        "name, category, price, description"
    ).eq("is_available", True).order("sort_order").execute()

    menu_context = menu_result.data or []

    if not menu_context:
        return error_response("Menu is currently empty. Cannot generate recommendations.", 400)

    result = get_ai_recommendation(prompt, menu_context)

    if not result["success"]:
        return error_response(result["message"], 503)

    return success_response(
        {
            "recommendation": result["recommendation"],
            "model_used": result["model_used"]
        },
        "Recommendation generated successfully",
        200
    )


# ai complaint triage
@ai_bp.route("/triage", methods=["POST"])
@require_auth
def triage():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    missing = validate_required_fields(data, ["raw_text"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    raw_text = str(data["raw_text"]).strip()
    if len(raw_text) < 5:
        return error_response("Complaint text is too short", 400)

    if len(raw_text) > 3000:
        return error_response("Complaint text must be under 3000 characters", 400)

    user_id = data.get("user_id")
    order_id = data.get("order_id")

    if order_id and not validate_uuid(str(order_id)):
        return error_response("Invalid order_id format", 400)

    result = triage_complaint(raw_text)

    if not result["success"]:
        return error_response(result["message"], 503)

    triage_data = result["triage"]
    db = get_db()

    complaint_payload = {
        "raw_text": raw_text,
        "category": triage_data["category"],
        "sentiment": triage_data["sentiment"],
        "priority": triage_data["priority"],
        "status": "open"
    }

    if user_id and validate_uuid(str(user_id)):
        complaint_payload["user_id"] = str(user_id)

    if order_id:
        complaint_payload["order_id"] = str(order_id)

    complaint_result = db.table("complaints").insert(complaint_payload).execute()

    return success_response(
        {
            "complaint_id": complaint_result.data[0]["id"] if complaint_result.data else None,
            "triage": triage_data,
            "model_used": result["model_used"]
        },
        "Complaint received and triaged successfully",
        201
    )


# proxy health check
@ai_bp.route("/health", methods=["GET"])
def proxy_health():
    result = check_proxy_health()
    status_code = 200 if result["online"] else 503
    return success_response(result, "Proxy health checked", status_code)
