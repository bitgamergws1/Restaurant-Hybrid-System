from flask import Blueprint, request
from extensions import get_db
from middleware.auth_middleware import require_auth, require_admin
from utils.response import success_response, error_response
from utils.validators import validate_uuid
import uuid

tables_bp = Blueprint("tables", __name__)


# ── Customer-facing: fetch all non-inactive tables ────────────────────────────
@tables_bp.route("/available", methods=["GET"], strict_slashes=False)
@require_auth
def get_available_tables():
    db = get_db()
    result = db.table("restaurant_tables") \
    .select("*") \
    .neq("status", "inactive") \
    .order("table_number") \
    .execute()
    tables = result.data or []
    return success_response({"tables": tables, "count": len(tables)}, "Tables fetched", 200)


# ── Admin: all tables ─────────────────────────────────────────────────────────
@tables_bp.route("/", methods=["GET"], strict_slashes=False)
@require_admin
def get_tables():
    db = get_db()
    result = db.table("restaurant_tables").select("*").order("table_number").execute()
    tables = result.data or []
    return success_response({"tables": tables, "count": len(tables)}, "Tables fetched", 200)


@tables_bp.route("/", methods=["POST"], strict_slashes=False)
@require_admin
def create_table():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    table_number = str(data.get("table_number", "")).strip()
    if not table_number:
        return error_response("table_number is required", 400)

    capacity = data.get("capacity", 4)
    try:
        capacity = int(capacity)
        if capacity < 1:
            raise ValueError
    except (ValueError, TypeError):
        return error_response("capacity must be a positive integer", 400)

    floor = str(data.get("floor", "Ground Floor")).strip()
    qr_token = str(uuid.uuid4())

    db = get_db()
    existing = db.table("restaurant_tables").select("id").eq("table_number", table_number).execute()
    if existing.data:
        return error_response(f"Table '{table_number}' already exists", 409)

    result = db.table("restaurant_tables").insert({
        "table_number": table_number,
        "capacity": capacity,
        "floor": floor,
        "status": "free",
        "qr_token": qr_token
    }).execute()

    if not result.data:
        return error_response("Failed to create table", 500)

    return success_response({"table": result.data[0]}, "Table created", 201)


@tables_bp.route("/<table_id>", methods=["PATCH"], strict_slashes=False)
@require_admin
def update_table(table_id):
    if not validate_uuid(table_id):
        return error_response("Invalid table ID", 400)

    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    allowed = {"table_number", "capacity", "floor", "status"}
    valid_statuses = {"free", "occupied", "reserved", "inactive"}
    payload = {}

    for field in allowed:
        if field not in data:
            continue
        if field == "capacity":
            try:
                val = int(data[field])
                if val < 1:
                    raise ValueError
                payload[field] = val
            except (ValueError, TypeError):
                return error_response("capacity must be a positive integer", 400)
        elif field == "status":
            val = str(data[field]).strip()
            if val not in valid_statuses:
                return error_response(f"Invalid status. Must be one of: {', '.join(valid_statuses)}", 400)
            payload[field] = val
        else:
            payload[field] = str(data[field]).strip()

    if not payload:
        return error_response("No valid fields to update", 400)

    db = get_db()
    result = db.table("restaurant_tables").update(payload).eq("id", table_id).execute()
    if not result.data:
        return error_response("Table not found", 404)

    return success_response({"table": result.data[0]}, "Table updated", 200)


@tables_bp.route("/<table_id>", methods=["DELETE"], strict_slashes=False)
@require_admin
def delete_table(table_id):
    if not validate_uuid(table_id):
        return error_response("Invalid table ID", 400)

    db = get_db()
    existing = db.table("restaurant_tables").select("id").eq("id", table_id).execute()
    if not existing.data:
        return error_response("Table not found", 404)

    db.table("restaurant_tables").delete().eq("id", table_id).execute()
    return success_response({}, "Table deleted", 200)


@tables_bp.route("/<table_id>/regenerate-qr", methods=["POST"], strict_slashes=False)
@require_admin
def regenerate_qr(table_id):
    if not validate_uuid(table_id):
        return error_response("Invalid table ID", 400)

    new_token = str(uuid.uuid4())
    db = get_db()
    result = db.table("restaurant_tables").update({"qr_token": new_token}).eq("id", table_id).execute()
    if not result.data:
        return error_response("Table not found", 404)

    return success_response({"table": result.data[0]}, "QR regenerated", 200)
