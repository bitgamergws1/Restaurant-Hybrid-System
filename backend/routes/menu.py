from flask import Blueprint, request
from extensions import get_db
from middleware.auth_middleware import require_admin
from utils.response import success_response, error_response
from utils.validators import validate_required_fields, validate_uuid

menu_bp = Blueprint("menu", __name__)


# public - get menu
@menu_bp.route("/", methods=["GET"])
def get_menu():
    db = get_db()

    category = request.args.get("category", "").strip()
    available_only = request.args.get("available", "true").lower() == "true"
    search = request.args.get("search", "").strip().lower()

    query = db.table("menu_items").select("*")

    if available_only:
        query = query.eq("is_available", True)

    if category:
        query = query.eq("category", category)

    query = query.order("sort_order").order("name")
    result = query.execute()
    items = result.data or []

    if search:
        items = [
            item for item in items
            if search in item["name"].lower()
            or search in (item.get("description") or "").lower()
            or search in (item.get("subcategory") or "").lower()
        ]

    return success_response({"items": items, "count": len(items)}, "Menu fetched successfully", 200)


# public - get all categories
@menu_bp.route("/categories", methods=["GET"])
def get_categories():
    db = get_db()
    result = db.table("menu_items").select("category").eq("is_available", True).execute()
    categories = sorted(set(item["category"] for item in (result.data or [])))
    return success_response({"categories": categories}, "Categories fetched", 200)


# public - single item
@menu_bp.route("/<item_id>", methods=["GET"])
def get_menu_item(item_id):
    if not validate_uuid(item_id):
        return error_response("Invalid item ID format", 400)

    db = get_db()
    result = db.table("menu_items").select("*").eq("id", item_id).execute()

    if not result.data:
        return error_response("Menu item not found", 404)

    return success_response({"item": result.data[0]}, "Menu item fetched", 200)


# admin - create item
@menu_bp.route("/", methods=["POST"])
@require_admin
def create_menu_item():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    missing = validate_required_fields(data, ["name", "price", "category"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    try:
        price = float(data["price"])
        if price < 0:
            raise ValueError
    except (ValueError, TypeError):
        return error_response("Price must be a non-negative number", 400)

    tags = data.get("tags", [])
    if not isinstance(tags, list):
        tags = []

    db = get_db()
    result = db.table("menu_items").insert({
        "name": str(data["name"]).strip(),
        "description": str(data.get("description", "")).strip() or None,
        "price": round(price, 2),
        "category": str(data["category"]).strip(),
        "subcategory": str(data.get("subcategory", "")).strip() or None,
        "is_available": bool(data.get("is_available", True)),
        "image_url": data.get("image_url") or None,
        "tags": tags,
        "sort_order": int(data.get("sort_order", 0))
    }).execute()

    if not result.data:
        return error_response("Failed to create menu item", 500)

    return success_response({"item": result.data[0]}, "Menu item created successfully", 201)


# admin - partial update
@menu_bp.route("/<item_id>", methods=["PATCH"])
@require_admin
def update_menu_item(item_id):
    if not validate_uuid(item_id):
        return error_response("Invalid item ID format", 400)

    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    allowed_fields = {
        "name", "description", "price", "category",
        "subcategory", "is_available", "image_url", "tags", "sort_order"
    }
    update_payload = {}

    for field in allowed_fields:
        if field not in data:
            continue

        if field == "price":
            try:
                val = float(data[field])
                if val < 0:
                    raise ValueError
                update_payload[field] = round(val, 2)
            except (ValueError, TypeError):
                return error_response("Price must be a non-negative number", 400)

        elif field == "is_available":
            update_payload[field] = bool(data[field])

        elif field == "sort_order":
            try:
                update_payload[field] = int(data[field])
            except (ValueError, TypeError):
                return error_response("sort_order must be an integer", 400)

        elif field == "tags":
            update_payload[field] = list(data[field]) if isinstance(data[field], list) else []

        else:
            update_payload[field] = str(data[field]).strip() or None

    if not update_payload:
        return error_response("No valid fields provided for update", 400)

    db = get_db()
    result = db.table("menu_items").update(update_payload).eq("id", item_id).execute()

    if not result.data:
        return error_response("Menu item not found", 404)

    return success_response({"item": result.data[0]}, "Menu item updated successfully", 200)


# admin - delete item
@menu_bp.route("/<item_id>", methods=["DELETE"])
@require_admin
def delete_menu_item(item_id):
    if not validate_uuid(item_id):
        return error_response("Invalid item ID format", 400)

    db = get_db()

    existing = db.table("menu_items").select("id").eq("id", item_id).execute()
    if not existing.data:
        return error_response("Menu item not found", 404)

    db.table("menu_items").delete().eq("id", item_id).execute()

    return success_response({}, "Menu item deleted successfully", 200)
