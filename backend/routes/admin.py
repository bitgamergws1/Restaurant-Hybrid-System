from collections import defaultdict
from flask import Blueprint, request
from extensions import get_db
from middleware.auth_middleware import require_admin
from utils.response import success_response, error_response

admin_bp = Blueprint("admin", __name__)


# ── Main analytics dashboard ─────────────────────────────────────────────────
@admin_bp.route("/analytics", methods=["GET"])
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

    # daily revenue breakdown
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

    # top selling items (Pareto sort)
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

    # complaints summary
    complaints_result = db.table("complaints").select("priority, status").execute()
    complaints_all = complaints_result.data or []

    complaints_by_priority = defaultdict(int)
    complaints_by_status = defaultdict(int)

    for c in complaints_all:
        complaints_by_priority[c.get("priority", "unknown")] += 1
        complaints_by_status[c.get("status", "unknown")] += 1

    # menu stats
    menu_result = db.table("menu_items").select("is_available").execute()
    menu_items = menu_result.data or []
    total_menu_items = len(menu_items)
    available_menu_items = sum(1 for m in menu_items if m["is_available"])

    # active tables
    tables_result = db.table("restaurant_tables").select("status").execute()
    all_tables = tables_result.data or []
    active_tables = sum(1 for t in all_tables if t["status"] == "occupied")

    # pending orders count
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


# ── All orders with filters (admin live orders view) ─────────────────────────
@admin_bp.route("/orders", methods=["GET"])
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

    # Join riders table to get rider name directly
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


# ── All complaints with filters ───────────────────────────────────────────────
@admin_bp.route("/complaints", methods=["GET"])
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


# ── Update complaint status ───────────────────────────────────────────────────
@admin_bp.route("/complaints/<complaint_id>/status", methods=["PATCH"])
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


# ── All users list ────────────────────────────────────────────────────────────
@admin_bp.route("/users", methods=["GET"])
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
