from datetime import datetime, timezone
from flask import Blueprint, request
from extensions import get_db
from middleware.auth_middleware import require_auth
from services.email_service import send_invoice_email
from utils.response import success_response, error_response
from utils.validators import validate_required_fields, validate_uuid

payments_bp = Blueprint("payments", __name__)


@payments_bp.route("/verify", methods=["POST"], strict_slashes=False)
@require_auth
def verify_payment():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    missing = validate_required_fields(data, ["order_id", "razorpay_payment_id", "razorpay_order_id"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    order_id = str(data["order_id"]).strip()
    razorpay_payment_id = str(data["razorpay_payment_id"]).strip()
    razorpay_order_id = str(data["razorpay_order_id"]).strip()

    if not validate_uuid(order_id):
        return error_response("Invalid order ID format", 400)

    db = get_db()
    user = request.current_user

    order_result = db.table("orders").select("*").eq("id", order_id).execute()
    if not order_result.data:
        return error_response("Order not found", 404)

    order = order_result.data[0]

    if order["user_id"] != user["id"] and user["role"] not in ("admin", "staff"):
        return error_response("Access denied. This order does not belong to you.", 403)

    if order["payment_status"] == "paid":
        return error_response("Payment already verified for this order", 409)

    mock_valid = (
        razorpay_payment_id.startswith("pay_")
        and razorpay_order_id.startswith("order_")
        and len(razorpay_payment_id) > 6
        and len(razorpay_order_id) > 8
    )

    if not mock_valid:
        db.table("payments").insert({
            "order_id": order_id,
            "razorpay_payment_id": razorpay_payment_id,
            "razorpay_order_id": razorpay_order_id,
            "amount": float(order["total_amount"]),
            "status": "failed",
            "gateway_response": data
        }).execute()

        return error_response("Payment verification failed. Invalid payment credentials.", 400)

    verified_at = datetime.now(timezone.utc).isoformat()

    payment_result = db.table("payments").insert({
        "order_id": order_id,
        "razorpay_payment_id": razorpay_payment_id,
        "razorpay_order_id": razorpay_order_id,
        "amount": float(order["total_amount"]),
        "status": "success",
        "gateway_response": data,
        "verified_at": verified_at
    }).execute()

    db.table("orders").update({
        "payment_status": "paid",
        "payment_id": razorpay_payment_id,
        "status": "confirmed"
    }).eq("id", order_id).execute()

    return success_response(
        {
            "payment": payment_result.data[0] if payment_result.data else {},
            "order_id": order_id,
            "verified_at": verified_at
        },
        "Payment verified successfully. Order confirmed.",
        200
    )


@payments_bp.route("/invoice/<order_id>", methods=["POST"], strict_slashes=False)
@require_auth
def send_invoice(order_id):
    if not validate_uuid(order_id):
        return error_response("Invalid order ID format", 400)

    db = get_db()
    user = request.current_user

    order_result = db.table("orders").select("*").eq("id", order_id).execute()
    if not order_result.data:
        return error_response("Order not found", 404)

    order = order_result.data[0]

    if order["user_id"] != user["id"] and user["role"] not in ("admin", "staff"):
        return error_response("Access denied", 403)

    if order["payment_status"] != "paid":
        return error_response("Invoice can only be sent for paid orders", 400)

    items_result = db.table("order_items").select("*").eq("order_id", order_id).execute()
    items = items_result.data or []

    email_sent = send_invoice_email(
        to_address=user["email"],
        user_name=user["name"],
        order=order,
        items=items
    )

    if not email_sent:
        return error_response("Failed to send invoice email. Please try again.", 500)

    db.table("orders").update({"invoice_sent": True}).eq("id", order_id).execute()

    return success_response(
        {"order_id": order_id, "sent_to": user["email"]},
        "Invoice sent successfully to your registered email.",
        200
    )
