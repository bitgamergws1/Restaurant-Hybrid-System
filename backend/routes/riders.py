from flask import Blueprint, request
from extensions import get_db
from middleware.auth_middleware import require_admin
from utils.response import success_response, error_response
from utils.validators import validate_uuid, validate_phone

riders_bp = Blueprint("riders", __name__)


@riders_bp.route("/", methods=["GET"], strict_slashes=False)
@require_admin
def get_riders():
    db = get_db()
    active_only = request.args.get("active", "").lower() == "true"
    query = db.table("riders").select("*").order("name")
    if active_only:
        query = query.eq("is_active", True)
    result = query.execute()
    riders = result.data or []
    return success_response({"riders": riders, "count": len(riders)}, "Riders fetched", 200)


@riders_bp.route("/", methods=["POST"], strict_slashes=False)
@require_admin
def create_rider():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    name = str(data.get("name", "")).strip()
    phone = str(data.get("phone", "")).strip()

    if not name:
        return error_response("name is required", 400)
    if not phone or not validate_phone(phone):
        return error_response("Valid 10-digit Indian phone is required", 400)

    db = get_db()
    existing = db.table("riders").select("id").eq("phone", phone).execute()
    if existing.data:
        return error_response("A rider with this phone already exists", 409)

    result = db.table("riders").insert({
        "name": name,
        "phone": phone,
        "is_active": True
    }).execute()

    if not result.data:
        return error_response("Failed to create rider", 500)

    return success_response({"rider": result.data[0]}, "Rider created", 201)


@riders_bp.route("/<rider_id>", methods=["PATCH"], strict_slashes=False)
@require_admin
def update_rider(rider_id):
    if not validate_uuid(rider_id):
        return error_response("Invalid rider ID", 400)

    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    payload = {}
    if "name" in data:
        payload["name"] = str(data["name"]).strip()
    if "phone" in data:
        phone = str(data["phone"]).strip()
        if not validate_phone(phone):
            return error_response("Valid 10-digit Indian phone required", 400)
        payload["phone"] = phone
    if "is_active" in data:
        payload["is_active"] = bool(data["is_active"])

    if not payload:
        return error_response("No valid fields to update", 400)

    db = get_db()
    result = db.table("riders").update(payload).eq("id", rider_id).execute()
    if not result.data:
        return error_response("Rider not found", 404)

    return success_response({"rider": result.data[0]}, "Rider updated", 200)


@riders_bp.route("/<rider_id>", methods=["DELETE"], strict_slashes=False)
@require_admin
def delete_rider(rider_id):
    if not validate_uuid(rider_id):
        return error_response("Invalid rider ID", 400)

    db = get_db()
    existing = db.table("riders").select("id").eq("id", rider_id).execute()
    if not existing.data:
        return error_response("Rider not found", 404)

    db.table("riders").delete().eq("id", rider_id).execute()
    return success_response({}, "Rider deleted", 200)
