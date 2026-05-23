import secrets
from datetime import datetime, timedelta, timezone
from flask import Blueprint, request
from werkzeug.security import generate_password_hash, check_password_hash
from extensions import get_db
from services.otp_service import create_otp, verify_otp, get_pending_metadata, clear_otp
from services.email_service import send_otp_email
from utils.response import success_response, error_response
from utils.validators import validate_required_fields, validate_email_format
from config import Config

auth_bp = Blueprint("auth", __name__)


def _generate_session_token() -> str:
    return secrets.token_hex(32)


def _create_session(user_id: str) -> str:
    db = get_db()
    token = _generate_session_token()
    expires_at = datetime.now(timezone.utc) + timedelta(hours=Config.SESSION_EXPIRY_HOURS)

    db.table("sessions").insert({
        "user_id": user_id,
        "token": token,
        "expires_at": expires_at.isoformat()
    }).execute()

    return token


@auth_bp.route("/signup", methods=["POST"], strict_slashes=False)
def signup():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    missing = validate_required_fields(data, ["name", "email", "password"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    name = str(data["name"]).strip()
    email = str(data["email"]).strip().lower()
    password = str(data["password"])
    phone = str(data.get("phone", "")).strip()

    if not validate_email_format(email):
        return error_response("Invalid email format", 400)

    if len(password) < 8:
        return error_response("Password must be at least 8 characters", 400)

    db = get_db()
    existing = db.table("users").select("id, is_verified").eq("email", email).execute()

    if existing.data:
        user = existing.data[0]
        if user["is_verified"]:
            return error_response("An account with this email already exists", 409)
        otp = create_otp(email, "signup", {
            "name": name,
            "password_hash": generate_password_hash(password),
            "phone": phone
        })
        send_otp_email(email, otp, "signup", name)
        return success_response({"email": email}, "OTP resent to your email. Please verify.", 200)

    otp = create_otp(email, "signup", {
        "name": name,
        "password_hash": generate_password_hash(password),
        "phone": phone
    })

    email_sent = send_otp_email(email, otp, "signup", name)
    if not email_sent:
        return error_response("Failed to send verification email. Please try again.", 500)

    return success_response({"email": email}, "OTP sent to your email. Please verify to complete registration.", 201)


@auth_bp.route("/verify-otp", methods=["POST"], strict_slashes=False)
def verify_otp_route():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    missing = validate_required_fields(data, ["email", "otp", "purpose"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    email = str(data["email"]).strip().lower()
    otp = str(data["otp"]).strip()
    purpose = str(data["purpose"]).strip()

    if purpose not in ("signup", "reset"):
        return error_response("Invalid OTP purpose", 400)

    is_valid, metadata = verify_otp(email, otp, purpose)
    if not is_valid:
        return error_response("Invalid or expired OTP", 400)

    if purpose == "signup":
        if not metadata:
            return error_response("Registration session expired. Please sign up again.", 400)

        db = get_db()
        existing_user = db.table("users").select("id").eq("email", email).execute()

        if existing_user.data:
            db.table("users").update({
                "name": metadata["name"],
                "password_hash": metadata["password_hash"],
                "phone": metadata.get("phone", ""),
                "is_verified": True
            }).eq("email", email).execute()
            user = db.table("users").select("id, name, email, role").eq("email", email).execute().data[0]
        else:
            result = db.table("users").insert({
                "name": metadata["name"],
                "email": email,
                "password_hash": metadata["password_hash"],
                "phone": metadata.get("phone", ""),
                "is_verified": True,
                "role": "customer"
            }).execute()

            if not result.data:
                return error_response("Failed to create account. Please try again.", 500)

            user = result.data[0]

        token = _create_session(user["id"])
        clear_otp(email, "signup")

        return success_response(
            {
                "user": {
                    "id": user["id"],
                    "name": user["name"],
                    "email": user["email"],
                    "role": user["role"]
                },
                "token": token
            },
            "Account verified and created successfully",
            201
        )

    return success_response({"email": email}, "OTP verified. Proceed to reset your password.", 200)


@auth_bp.route("/resend-otp", methods=["POST"], strict_slashes=False)
def resend_otp():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    missing = validate_required_fields(data, ["email", "purpose"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    email = str(data["email"]).strip().lower()
    purpose = str(data["purpose"]).strip()

    if purpose not in ("signup", "reset"):
        return error_response("Invalid OTP purpose", 400)

    if not validate_email_format(email):
        return error_response("Invalid email format", 400)

    db = get_db()

    if purpose == "signup":
        metadata = get_pending_metadata(email, "signup")
        if not metadata:
            return error_response("No pending registration found. Please sign up again.", 400)
        name = metadata.get("name", "")
        otp = create_otp(email, "signup", metadata)
    else:
        user_result = db.table("users").select("name").eq("email", email).eq("is_verified", True).execute()
        if not user_result.data:
            return success_response({}, "If an account with that email exists, an OTP has been sent.", 200)
        name = user_result.data[0].get("name", "")
        otp = create_otp(email, "reset")

    email_sent = send_otp_email(email, otp, purpose, name)
    if not email_sent:
        return error_response("Failed to send OTP. Please try again.", 500)

    return success_response({"email": email}, "OTP resent successfully.", 200)


@auth_bp.route("/login", methods=["POST"], strict_slashes=False)
def login():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    missing = validate_required_fields(data, ["email", "password"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    email = str(data["email"]).strip().lower()
    password = str(data["password"])

    if not validate_email_format(email):
        return error_response("Invalid email format", 400)

    db = get_db()
    result = db.table("users").select("*").eq("email", email).execute()

    if not result.data:
        return error_response("Invalid email or password", 401)

    user = result.data[0]

    if not user.get("is_verified"):
        return error_response("Account not verified. Please verify your email first.", 403)

    if not check_password_hash(user["password_hash"], password):
        return error_response("Invalid email or password", 401)

    token = _create_session(user["id"])

    return success_response(
        {
            "user": {
                "id": user["id"],
                "name": user["name"],
                "email": user["email"],
                "role": user["role"],
                "phone": user.get("phone", "")
            },
            "token": token
        },
        "Login successful",
        200
    )


@auth_bp.route("/logout", methods=["POST"], strict_slashes=False)
def logout():
    token = request.headers.get("X-Session-Token", "").strip()
    if not token:
        return error_response("No session token provided", 400)

    get_db().table("sessions").delete().eq("token", token).execute()
    return success_response({}, "Logged out successfully", 200)


@auth_bp.route("/forgot-password", methods=["POST"], strict_slashes=False)
def forgot_password():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    email = str(data.get("email", "")).strip().lower()
    if not validate_email_format(email):
        return error_response("Invalid email format", 400)

    db = get_db()
    result = db.table("users").select("name, is_verified").eq("email", email).execute()

    if not result.data or not result.data[0].get("is_verified"):
        return success_response({}, "If an account with that email exists, a reset OTP has been sent.", 200)

    name = result.data[0].get("name", "")
    otp = create_otp(email, "reset")
    send_otp_email(email, otp, "reset", name)

    return success_response({}, "If an account with that email exists, a reset OTP has been sent.", 200)


@auth_bp.route("/reset-password", methods=["POST"], strict_slashes=False)
def reset_password():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Invalid JSON body", 400)

    missing = validate_required_fields(data, ["email", "otp", "new_password"])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    email = str(data["email"]).strip().lower()
    otp = str(data["otp"]).strip()
    new_password = str(data["new_password"])

    if len(new_password) < 8:
        return error_response("Password must be at least 8 characters", 400)

    is_valid, _ = verify_otp(email, otp, "reset")
    if not is_valid:
        return error_response("Invalid or expired OTP", 400)

    db = get_db()
    result = db.table("users").update({
        "password_hash": generate_password_hash(new_password)
    }).eq("email", email).execute()

    if not result.data:
        return error_response("User not found", 404)

    user_id = result.data[0]["id"]
    db.table("sessions").delete().eq("user_id", user_id).execute()
    clear_otp(email, "reset")

    return success_response({}, "Password reset successfully. Please log in with your new password.", 200)
