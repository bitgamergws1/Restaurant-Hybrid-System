from flask import jsonify


def success_response(data: dict, message: str = "Success", status_code: int = 200):
    return jsonify({
        "success": True,
        "message": message,
        "data": data
    }), status_code


def error_response(message: str, status_code: int = 400, details: dict = None):
    body = {
        "success": False,
        "message": message
    }
    if details:
        body["details"] = details
    return jsonify(body), status_code
