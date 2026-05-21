from functools import wraps
from datetime import datetime, timezone
from flask import request
from extensions import get_db
from utils.response import error_response


def _resolve_session(token: str):
    if not token:
        return None, None

    db = get_db()
    result = db.table("sessions").select("user_id, expires_at").eq("token", token).execute()

    if not result.data:
        return None, None

    session = result.data[0]
    expires_at = datetime.fromisoformat(session["expires_at"].replace("Z", "+00:00"))

    if datetime.now(timezone.utc) > expires_at:
        db.table("sessions").delete().eq("token", token).execute()
        return None, None

    user_result = db.table("users").select("id, name, email, role, is_verified").eq("id", session["user_id"]).execute()

    if not user_result.data:
        return None, None

    return user_result.data[0], token


def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get("X-Session-Token", "").strip()
        user, _ = _resolve_session(token)

        if not user:
            return error_response("Authentication required. Invalid or expired session.", 401)

        request.current_user = user
        return f(*args, **kwargs)

    return decorated


def require_admin(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get("X-Session-Token", "").strip()
        user, _ = _resolve_session(token)

        if not user:
            return error_response("Authentication required. Invalid or expired session.", 401)

        if user["role"] not in ("admin", "staff"):
            return error_response("Access denied. Insufficient permissions.", 403)

        request.current_user = user
        return f(*args, **kwargs)

    return decorated
