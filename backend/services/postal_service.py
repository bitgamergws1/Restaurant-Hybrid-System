import traceback
import requests
from config import Config

TIMEOUT = 10


def lookup_pincode(pin: str) -> dict:
    try:
        url = f"{Config.POSTAL_API_BASE}/{pin}"
        response = requests.get(url, timeout=TIMEOUT)
        response.raise_for_status()

        data = response.json()

        if not data or data[0].get("Status") != "Success":
            return {
                "success": False,
                "message": "No data found for this pincode. Please check and try again.",
                "pincode": pin
            }

        post_offices = data[0].get("PostOffice", [])

        if not post_offices:
            return {
                "success": False,
                "message": "No post offices found for this pincode.",
                "pincode": pin
            }

        primary = post_offices[0]

        structured = {
            "pincode": pin,
            "district": primary.get("District", ""),
            "state": primary.get("State", ""),
            "country": primary.get("Country", "India"),
            "division": primary.get("Division", ""),
            "region": primary.get("Region", ""),
            "areas": [po.get("Name", "") for po in post_offices if po.get("Name")]
        }

        return {
            "success": True,
            "message": "Pincode resolved successfully.",
            "location": structured
        }

    except requests.exceptions.Timeout:
        return {
            "success": False,
            "message": "Postal lookup timed out. Please try again.",
            "pincode": pin
        }
    except requests.exceptions.HTTPError as e:
        print(f"[postal_service] HTTP error: {e}")
        return {
            "success": False,
            "message": "Failed to reach postal API.",
            "pincode": pin
        }
    except Exception:
        traceback.print_exc()
        return {
            "success": False,
            "message": "Unexpected error during pincode lookup.",
            "pincode": pin
        }


def build_delivery_address(pincode_data: dict, address_line: str, coordinates: dict = None) -> dict:
    location = pincode_data.get("location", {})

    address = {
        "address_line": address_line.strip(),
        "area": location.get("areas", [""])[0],
        "district": location.get("district", ""),
        "state": location.get("state", ""),
        "pincode": location.get("pincode", ""),
        "country": location.get("country", "India")
    }

    delivery_coordinates = None
    if coordinates and isinstance(coordinates, dict):
        lat = coordinates.get("lat") or coordinates.get("latitude")
        lng = coordinates.get("lng") or coordinates.get("longitude")
        if lat is not None and lng is not None:
            try:
                delivery_coordinates = {
                    "lat": float(lat),
                    "lng": float(lng)
                }
            except (TypeError, ValueError):
                delivery_coordinates = None

    return {
        "address": address,
        "coordinates": delivery_coordinates
    }
