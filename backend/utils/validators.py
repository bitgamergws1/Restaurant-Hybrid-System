import re


def validate_required_fields(data: dict, fields: list) -> list:
    return [f for f in fields if not data.get(f)]


def validate_email_format(email: str) -> bool:
    pattern = r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$'
    return bool(re.match(pattern, email))


def validate_pincode(pin: str) -> bool:
    return bool(re.match(r'^\d{6}$', str(pin)))


def validate_phone(phone: str) -> bool:
    return bool(re.match(r'^[6-9]\d{9}$', str(phone)))


def sanitize_string(value: str, max_length: int = 255) -> str:
    return str(value).strip()[:max_length]


def validate_uuid(value: str) -> bool:
    pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    return bool(re.match(pattern, str(value).lower()))
