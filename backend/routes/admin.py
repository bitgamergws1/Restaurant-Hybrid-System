from collections import defaultdict
from flask import Blueprint, request
from extensions import get_db
from middleware.auth_middleware import require_admin
from services.email_service import (
    send_delay_notification_email,
    send_complaint_resolution_email,
    send_order_cancelled_email,
)
from utils.response import success_response, error_response
from utils.validators import validate_uuid

admin_bp = Blueprint("admin", __name__)


@admin_bp.route("/analytics", methods=["GET"], strict_slashes=False)
@require_admin
def get_analytics():
    db = get_db()

    date_from = request.args.get("from")
    date_to = request.args.get("to")

    orders_query = db.table("orders").select("*")

    if date_from:
        orders_query = orders_query.gte("created_at", date_from)
    if date_to:
        orders_query = orders_query.lte("created_at", date_to)

    orders_result = orders_query.execute()
    all_orders = orders_result.data or []

    total_orders = len(all_orders)
    paid_orders = [o for o in all_orders if o["payment_status"] == "paid"]
    cancelled_orders = [o for o in all_orders if o["status"] == "cancelled"]

    total_revenue = sum(float(o["total_amount"]) for o in paid_orders)
    total_gst = sum(float(o["gst_amount"]) for o in paid_orders)
    total_subtotal = sum(float(o["subtotal"]) for o in paid_orders)

    dine_in_count = sum(1 for o in all_orders if o["order_type"] == "dine_in")
    delivery_count = sum(1 for o in all_orders if o["order_type"] == "delivery")

    daily_revenue = defaultdict(float)
    daily_order_count = defaultdict(int)

    for o in paid_orders:
        date_key = o["created_at"][:10]
        daily_revenue[date_key] += float(o["total_amount"])
        daily_order_count[date_key] += 1

    daily_breakdown = sorted(
        [
            {
                "date": date,
                "revenue": round(daily_revenue[date], 2),
                "orders": daily_order_count[date]
            }
            for date in daily_revenue
        ],
        key=lambda x: x["date"],
        reverse=True
    )

    order_ids = [o["id"] for o in paid_orders]
    top_items = []

    if order_ids:
        items_result = db.table("order_items").select(
            "item_name, quantity, item_total"
        ).in_("order_id", order_ids).execute()
        all_items = items_result.data or []

        item_aggregates = defaultdict(lambda: {"quantity": 0, "revenue": 0.0})
        for item in all_items:
            name = item["item_name"]
            item_aggregates[name]["quantity"] += int(item["quantity"])
            item_aggregates[name]["revenue"] += float(item["item_total"])

        sorted_items = sorted(
            [
                {
                    "item_name": name,
                    "total_quantity_sold": agg["quantity"],
                    "total_revenue": round(agg["revenue"], 2)
                }
                for name, agg in item_aggregates.items()
            ],
            key=lambda x: x["total_quantity_sold"],
            reverse=True
        )

        top_items = sorted_items[:20]

    complaints_result = db.table("complaints").select("priority, status").execute()
    complaints_all = complaints_result.data or []

    complaints_by_priority = defaultdict(int)
    complaints_by_status = defaultdict(int)

    for c in complaints_all:
        complaints_by_priority[c.get("priority", "unknown")] += 1
        complaints_by_status[c.get("status", "unknown")] += 1

    menu_result = db.table("menu_items").select("is_available").execute()
    menu_items = menu_result.data or []
    total_menu_items = len(menu_items)
    available_menu_items = sum(1 for m in menu_items if m["is_available"])

    tables_result = db.table("restaurant_tables").select("status").execute()
    all_tables = tables_result.data or []
    active_tables = sum(1 for t in all_tables if t["status"] == "occupied")

    pending_orders = sum(1 for o in all_orders if o["status"] == "pending")

    return success_response(
        {
            "summary": {
                "total_orders": total_orders,
                "paid_orders": len(paid_orders),
                "cancelled_orders": len(cancelled_orders),
                "pending_orders": pending_orders,
                "dine_in_orders": dine_in_count,
                "delivery_orders": delivery_count,
                "total_revenue": round(total_revenue, 2),
                "total_gst_collected": round(total_gst, 2),
                "total_subtotal": round(total_subtotal, 2),
                "average_order_value": round(total_revenue / len(paid_orders), 2) if paid_orders else 0.0,
                "active_tables": active_tables,
                "total_tables": len(all_tables)
            },
            "daily_breakdown": daily_breakdown,
            "top_selling_items": top_items,
            "complaints": {
                "total": len(complaints_all),
                "by_priority": dict(complaints_by_priority),
                "by_status": dict(complaints_by_status)
            },
            "menu": {
                "total_items": total_menu_items,
                "available_items": available_menu_items,
                "unavailable_items": total_menu_items - available_menu_items
            }
        },
        "Analytics compiled successfully",
        200
    )


@admin_bp.route("/orders", methods=["GET"], strict_slashes=False)
@require_admin
def get_admin_orders():
    db = get_db()

    status = request.args.get("status", "").strip()
    order_type = request.args.get("type", "").strip()
    try:
        limit = int(request.args.get("limit", 100))
        limit = max(1, min(limit, 500))
    except (ValueError, TypeError):
        limit = 100

    query = db.table("orders").select(
        "*, riders(id, name, phone)"
    ).order("created_at", desc=True).limit(limit)

    if status:
        query = query.eq("status", status)
    if order_type:
        query = query.eq("order_type", order_type)

    result = query.execute()
    orders = result.data or []

    return success_response(
        {"orders": orders, "count": len(orders)},
        "Orders fetched successfully",
        200
    )


# ── NEW: Admin sends delay notification to customer ───────────────────────────
@admin_bp.route("/orders/<order_id>/notify-delay", methods=["POST"], strict_slashes=False)
@require_admin
def notify_delay(order_id):
    """
    Admin manually notifies the customer about a delay.

    Body:
        message       (str, required)  — custom message explaining the delay
        eta_minutes   (int, optional)  — updated estimate in minutes
    """
    if not validate_uuid(order_id):
        return error_response("Invalid order ID format", 400)

    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    message = str(data.get("message", "")).strip()
    if not message:
        return error_response("'message' is required", 400)

    eta_minutes = data.get("eta_minutes")
    if eta_minutes is not None:
        try:
            eta_minutes = int(eta_minutes)
            if eta_minutes < 1 or eta_minutes > 300:
                raise ValueError
        except (ValueError, TypeError):
            return error_response("eta_minutes must be an integer between 1 and 300", 400)

    db = get_db()
    order_result = db.table("orders").select("*").eq("id", order_id).execute()
    if not order_result.data:
        return error_response("Order not found", 404)

    order = order_result.data[0]

    # Fetch customer info
    user_result = db.table("users").select("email, name").eq("id", order["user_id"]).execute()
    if not user_result.data:
        return error_response("Customer account not found", 404)

    user = user_result.data[0]

    email_sent = send_delay_notification_email(
        to_address=user["email"],
        user_name=user["name"],
        order=order,
        message=message,
        new_eta_minutes=eta_minutes
    )

    if not email_sent:
        return error_response("Failed to send delay notification email.", 500)

    return success_response(
        {
            "order_id": order_id,
            "notified_email": user["email"],
            "eta_minutes": eta_minutes
        },
        "Delay notification sent to customer successfully.",
        200
    )


# ── NEW: Admin cancels order (with optional reason + email) ───────────────────
@admin_bp.route("/orders/<order_id>/cancel", methods=["POST"], strict_slashes=False)
@require_admin
def admin_cancel_order(order_id):
    """
    Admin cancels any non-terminal order and optionally sends a reason email.

    Body:
        reason  (str, optional) — reason shown in the cancellation email
    """
    if not validate_uuid(order_id):
        return error_response("Invalid order ID format", 400)

    data = request.get_json(silent=True) or {}
    reason = str(data.get("reason", "")).strip()

    db = get_db()
    order_result = db.table("orders").select("*").eq("id", order_id).execute()
    if not order_result.data:
        return error_response("Order not found", 404)

    order = order_result.data[0]
    terminal_states = {"delivered", "cancelled", "rejected"}

    if order["status"] in terminal_states:
        return error_response(
            f"Order is already '{order['status']}' and cannot be cancelled.", 400
        )

    result = db.table("orders").update({"status": "cancelled"}).eq("id", order_id).execute()
    cancelled_order = result.data[0]

    # Notify customer
    try:
        user_result = db.table("users").select("email, name").eq("id", order["user_id"]).execute()
        if user_result.data:
            u = user_result.data[0]
            send_order_cancelled_email(
                to_address=u["email"],
                user_name=u["name"],
                order=cancelled_order,
                cancelled_by="admin",
                reason=reason
            )
    except Exception as e:
        print(f"[admin] Cancel email failed for order {order_id}: {e}")

    return success_response(
        {"order": cancelled_order},
        "Order cancelled and customer notified.",
        200
    )


@admin_bp.route("/complaints", methods=["GET"], strict_slashes=False)
@require_admin
def get_complaints():
    db = get_db()

    status = request.args.get("status", "").strip()
    priority = request.args.get("priority", "").strip()

    query = db.table("complaints").select("*").order("created_at", desc=True)

    if status:
        query = query.eq("status", status)
    if priority:
        query = query.eq("priority", priority)

    result = query.execute()
    complaints = result.data or []

    return success_response(
        {"complaints": complaints, "count": len(complaints)},
        "Complaints fetched successfully",
        200
    )


@admin_bp.route("/complaints/<complaint_id>/status", methods=["PATCH"], strict_slashes=False)
@require_admin
def update_complaint_status(complaint_id):
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    new_status = str(data.get("status", "")).strip()
    valid_statuses = {"open", "in_review", "resolved", "closed"}

    if new_status not in valid_statuses:
        return error_response(
            f"Invalid status. Must be one of: {', '.join(valid_statuses)}", 400
        )

    db = get_db()
    result = db.table("complaints").update({"status": new_status}).eq("id", complaint_id).execute()

    if not result.data:
        return error_response("Complaint not found", 404)

    return success_response({"complaint": result.data[0]}, "Complaint status updated", 200)


# ── NEW: Admin resolves complaint + sends resolution email ────────────────────
@admin_bp.route("/complaints/<complaint_id>/resolve", methods=["POST"], strict_slashes=False)
@require_admin
def resolve_complaint(complaint_id):
    """
    Admin resolves a complaint and sends a resolution email to the customer.

    Body:
        resolution_message  (str, required)  — admin's resolution text
        status              (str, optional)  — 'resolved' (default) or 'closed'
    """
    if not validate_uuid(complaint_id):
        return error_response("Invalid complaint ID format", 400)

    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    resolution_message = str(data.get("resolution_message", "")).strip()
    if not resolution_message:
        return error_response("'resolution_message' is required", 400)

    new_status = str(data.get("status", "resolved")).strip()
    if new_status not in ("resolved", "closed"):
        return error_response("status must be 'resolved' or 'closed'", 400)

    db = get_db()
    complaint_result = db.table("complaints").select("*").eq("id", complaint_id).execute()
    if not complaint_result.data:
        return error_response("Complaint not found", 404)

    complaint = complaint_result.data[0]

    if complaint["status"] in ("resolved", "closed"):
        return error_response(
            f"Complaint is already '{complaint['status']}'.", 400
        )

    # Update status
    result = db.table("complaints").update({"status": new_status}).eq("id", complaint_id).execute()
    updated_complaint = result.data[0]

    # Send resolution email if complaint has a user_id
    email_sent = False
    if complaint.get("user_id"):
        try:
            user_result = db.table("users").select("email, name").eq("id", complaint["user_id"]).execute()
            if user_result.data:
                u = user_result.data[0]
                email_sent = send_complaint_resolution_email(
                    to_address=u["email"],
                    user_name=u["name"],
                    complaint=complaint,
                    resolution_message=resolution_message
                )
        except Exception as e:
            print(f"[admin] Resolution email failed for complaint {complaint_id}: {e}")

    return success_response(
        {
            "complaint": updated_complaint,
            "resolution_message": resolution_message,
            "email_sent": email_sent
        },
        "Complaint resolved" + (" and customer notified via email." if email_sent else ". (No email — anonymous complaint)"),
        200
    )


@admin_bp.route("/users", methods=["GET"], strict_slashes=False)
@require_admin
def get_users():
    db = get_db()
    result = db.table("users").select(
        "id, name, email, phone, role, is_verified, created_at"
    ).order("created_at", desc=True).execute()
    users = result.data or []
    return success_response(
        {"users": users, "count": len(users)},
        "Users fetched successfully",
        200
    )
