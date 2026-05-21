from flask import Blueprint
from services.postal_service import lookup_pincode
from middleware.auth_middleware import require_auth
from utils.response import success_response, error_response
from utils.validators import validate_pincode

postal_bp = Blueprint("postal", __name__)


@postal_bp.route("/<pin>", methods=["GET"])
@require_auth
def get_pincode_info(pin):
    pin = str(pin).strip()

    if not validate_pincode(pin):
        return error_response("Invalid pincode. Must be a 6-digit Indian postal code.", 400)

    result = lookup_pincode(pin)

    if not result["success"]:
        return error_response(result["message"], 400)

    return success_response(result, "Pincode resolved successfully", 200)
