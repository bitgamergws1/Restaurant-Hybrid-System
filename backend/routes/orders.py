from flask import Blueprint, request
from extensions import get_db
from middleware.auth_middleware import require_auth, require_admin
from services.billing_service import calculate_bill
from services.postal_service import lookup_pincode, build_delivery_address
from utils.response import success_response, error_response
from utils.validators import (
    validate_required_fields, validate_pincode, validate_uuid
)

orders_bp = Blueprint("orders", __name__)

VALID_STATUS_TRANSITIONS = {
    "pending":          {"confirmed", "cancelled"},
    "confirmed":        {"preparing", "cancelled"},
    "preparing":        {"ready"},
    "ready":            {"out_for_delivery", "delivered"},
    "out_for_delivery": {"delivered"},
    "delivered":        set(),
    "cancelled":        set()
}


@orders_bp.route("/", methods=["POST"], strict_slashes=False)
@require_auth
def create_order():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    missing = validate_required_fields(data, ["order_type", "items"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    order_type = str(data["order_type"]).strip()
    if order_type not in ("dine_in", "delivery"):
        return error_response("order_type must be 'dine_in' or 'delivery'", 400)

    items_raw = data.get("items", [])
    if not isinstance(items_raw, list) or len(items_raw) == 0:
        return error_response("Order must contain at least one item", 400)

    db = get_db()
    user = request.current_user

    resolved_items = []
    for entry in items_raw:
        menu_item_id = str(entry.get("menu_item_id", "")).strip()
        quantity = entry.get("quantity", 1)

        if not validate_uuid(menu_item_id):
            return error_response(f"Invalid menu_item_id: {menu_item_id}", 400)

        try:
            quantity = int(quantity)
            if quantity < 1:
                raise ValueError
        except (ValueError, TypeError):
            return error_response("Item quantity must be a positive integer", 400)

        menu_result = db.table("menu_items").select(
            "id, name, price, is_available"
        ).eq("id", menu_item_id).execute()

        if not menu_result.data:
            return error_response(f"Menu item not found: {menu_item_id}", 404)

        menu_item = menu_result.data[0]

        if not menu_item["is_available"]:
            return error_response(f"'{menu_item['name']}' is currently unavailable", 400)

        resolved_items.append({
            "menu_item_id": menu_item["id"],
            "item_name": menu_item["name"],
            "unit_price": float(menu_item["price"]),
            "quantity": quantity
        })

    bill = calculate_bill(resolved_items)

    table_id = None
    delivery_address = None
    delivery_coordinates = None

    if order_type == "dine_in":
        table_id = str(data.get("table_id", "")).strip()
        if not table_id:
            return error_response("table_id is required for dine-in orders", 400)

        table_result = db.table("restaurant_tables") \
            .select("id, table_number, status") \
            .eq("table_number", table_id) \
            .execute()

        if not table_result.data:
            return error_response(
                f"Table '{table_id}' does not exist. Please scan a valid QR code.", 400
            )

        table_row = table_result.data[0]
        if table_row["status"] == "inactive":
            return error_response(
                f"Table '{table_id}' is currently inactive and cannot accept orders.", 400
            )

    elif order_type == "delivery":
        pincode = str(data.get("pincode", "")).strip()
        address_line = str(data.get("address_line", "")).strip()

        if not validate_pincode(pincode):
            return error_response(
                "Invalid pincode. Must be a 6-digit Indian postal code.", 400
            )

        if not address_line:
            return error_response("address_line is required for delivery orders", 400)

        pincode_result = lookup_pincode(pincode)
        if not pincode_result["success"]:
            return error_response(pincode_result["message"], 400)

        coordinates_raw = data.get("coordinates")
        built = build_delivery_address(pincode_result, address_line, coordinates_raw)

        delivery_address = built["address"]
        delivery_coordinates = built["coordinates"]

    order_payload = {
        "user_id": user["id"],
        "order_type": order_type,
        "table_id": table_id,
        "delivery_address": delivery_address,
        "delivery_coordinates": delivery_coordinates,
        "subtotal": bill["subtotal"],
        "gst_amount": bill["gst_amount"],
        "total_amount": bill["total_amount"],
        "special_instructions": str(data.get("special_instructions", "")).strip() or None,
        "status": "pending",
        "payment_status": "pending"
    }

    order_result = db.table("orders").insert(order_payload).execute()
    if not order_result.data:
        return error_response("Failed to create order. Please try again.", 500)

    order = order_result.data[0]
    order_id = order["id"]

    order_items_payload = [
        {
            "order_id": order_id,
            "menu_item_id": item["menu_item_id"],
            "item_name": item["item_name"],
            "quantity": item["quantity"],
            "unit_price": item["unit_price"],
            "item_total": item["item_total"]
        }
        for item in bill["line_items"]
    ]

    db.table("order_items").insert(order_items_payload).execute()

    return success_response(
        {
            "order": order,
            "items": bill["line_items"],
            "billing": {
                "subtotal": bill["subtotal"],
                "gst_amount": bill["gst_amount"],
                "gst_rate": bill["gst_rate"],
                "total_amount": bill["total_amount"]
            }
        },
        "Order placed successfully",
        201
    )


@orders_bp.route("/<order_id>", methods=["GET"], strict_slashes=False)
@require_auth
def get_order(order_id):
    if not validate_uuid(order_id):
        return error_response("Invalid order ID format", 400)

    db = get_db()
    user = request.current_user

    order_result = db.table("orders").select("*").eq("id", order_id).execute()
    if not order_result.data:
        return error_response("Order not found", 404)

    order = order_result.data[0]

    if user["role"] not in ("admin", "staff") and order["user_id"] != user["id"]:
        return error_response("Access denied. This order does not belong to you.", 403)

    items_result = db.table("order_items").select("*").eq("order_id", order_id).execute()

    return success_response(
        {"order": order, "items": items_result.data or []},
        "Order fetched successfully",
        200
    )


@orders_bp.route("/<order_id>/status", methods=["PATCH"], strict_slashes=False)
@require_admin
def update_order_status(order_id):
    if not validate_uuid(order_id):
        return error_response("Invalid order ID format", 400)

    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    new_status = str(data.get("status", "")).strip()
    if not new_status:
        return error_response("status field is required", 400)

    db = get_db()
    order_result = db.table("orders").select("id, status").eq("id", order_id).execute()

    if not order_result.data:
        return error_response("Order not found", 404)

    current_status = order_result.data[0]["status"]
    allowed_next = VALID_STATUS_TRANSITIONS.get(current_status, set())

    if new_status not in allowed_next:
        return error_response(
            f"Invalid status transition. '{current_status}' cannot move to '{new_status}'. "
            f"Allowed: {', '.join(allowed_next) if allowed_next else 'none'}",
            400
        )

    result = db.table("orders").update({"status": new_status}).eq("id", order_id).execute()

    return success_response({"order": result.data[0]}, "Order status updated successfully", 200)


@orders_bp.route("/<order_id>/eta", methods=["PATCH"], strict_slashes=False)
@require_admin
def set_order_eta(order_id):
    if not validate_uuid(order_id):
        return error_response("Invalid order ID format", 400)

    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    payload = {}

    if "estimated_delivery_time" in data:
        payload["estimated_delivery_time"] = data["estimated_delivery_time"]

    if "estimated_table_time" in data:
        payload["estimated_table_time"] = data["estimated_table_time"]

    eta_minutes = data.get("eta_minutes")
    if eta_minutes is not None and not payload:
        try:
            mins = int(eta_minutes)
            if mins < 1 or mins > 300:
                raise ValueError
            from datetime import datetime, timedelta, timezone
            eta_iso = (datetime.now(timezone.utc) + timedelta(minutes=mins)).isoformat()
            payload["estimated_delivery_time"] = eta_iso
            payload["estimated_table_time"] = eta_iso
        except (ValueError, TypeError):
            return error_response("eta_minutes must be an integer between 1 and 300", 400)

    if not payload:
        return error_response(
            "Provide at least one of: estimated_delivery_time, estimated_table_time, eta_minutes",
            400
        )

    db = get_db()
    result = db.table("orders").update(payload).eq("id", order_id).execute()
    if not result.data:
        return error_response("Order not found", 404)

    return success_response({"order": result.data[0]}, "ETA updated successfully", 200)


@orders_bp.route("/<order_id>/assign-rider", methods=["PATCH"], strict_slashes=False)
@require_admin
def assign_rider(order_id):
    if not validate_uuid(order_id):
        return error_response("Invalid order ID format", 400)

    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    rider_id = str(data.get("rider_id", "")).strip()
    if not rider_id or not validate_uuid(rider_id):
        return error_response("Valid rider_id is required", 400)

    db = get_db()

    order_result = db.table("orders").select(
        "id, order_type, status"
    ).eq("id", order_id).execute()

    if not order_result.data:
        return error_response("Order not found", 404)

    order = order_result.data[0]
    if order["order_type"] != "delivery":
        return error_response("Rider assignment is only valid for delivery orders", 400)

    rider_result = db.table("riders").select(
        "id, name, phone"
    ).eq("id", rider_id).eq("is_active", True).execute()

    if not rider_result.data:
        return error_response("Active rider not found", 404)

    rider = rider_result.data[0]

    result = db.table("orders").update({"rider_id": rider_id}).eq("id", order_id).execute()
    if not result.data:
        return error_response("Failed to assign rider", 500)

    return success_response(
        {"order": result.data[0], "rider": rider},
        f"Rider '{rider['name']}' assigned successfully",
        200
    )


@orders_bp.route("/user/<user_id>", methods=["GET"], strict_slashes=False)
@require_auth
def get_user_orders(user_id):
    if not validate_uuid(user_id):
        return error_response("Invalid user ID format", 400)

    current_user = request.current_user

    if current_user["role"] not in ("admin", "staff") and current_user["id"] != user_id:
        return error_response("Access denied", 403)

    db = get_db()
    result = db.table("orders").select("*").eq("user_id", user_id).order(
        "created_at", desc=True
    ).execute()

    return success_response(
        {"orders": result.data or [], "count": len(result.data or [])},
        "Orders fetched successfully",
        200
    )
