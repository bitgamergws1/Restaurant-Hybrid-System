import secrets
from datetime import datetime, timedelta, timezone
from extensions import get_db
from config import Config


def _generate_otp() -> str:
    return str(secrets.randbelow(900000) + 100000)


def create_otp(email: str, purpose: str, metadata: dict = None) -> str:
    db = get_db()
    otp = _generate_otp()
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=Config.OTP_EXPIRY_SECONDS)

    db.table("user_otps").delete().eq("email", email).eq("purpose", purpose).execute()

    db.table("user_otps").insert({
        "email": email,
        "otp_code": otp,
        "purpose": purpose,
        "metadata": metadata,
        "expires_at": expires_at.isoformat(),
        "is_verified": False
    }).execute()

    return otp


def verify_otp(email: str, otp: str, purpose: str) -> tuple[bool, dict | None]:
    db = get_db()

    result = db.table("user_otps") \
        .select("*") \
        .eq("email", email) \
        .eq("otp_code", otp) \
        .eq("purpose", purpose) \
        .eq("is_verified", False) \
        .execute()

    if not result.data:
        return False, None

    record = result.data[0]
    expires_at = datetime.fromisoformat(record["expires_at"].replace("Z", "+00:00"))

    if datetime.now(timezone.utc) > expires_at:
        db.table("user_otps").delete().eq("id", record["id"]).execute()
        return False, None

    db.table("user_otps").update({"is_verified": True}).eq("id", record["id"]).execute()

    return True, record.get("metadata")


def get_pending_metadata(email: str, purpose: str) -> dict | None:
    db = get_db()

    result = db.table("user_otps") \
        .select("metadata") \
        .eq("email", email) \
        .eq("purpose", purpose) \
        .eq("is_verified", False) \
        .execute()

    if not result.data:
        return None

    return result.data[0].get("metadata")


def clear_otp(email: str, purpose: str):
    get_db().table("user_otps").delete().eq("email", email).eq("purpose", purpose).execute()
