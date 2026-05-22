from config import Config


def calculate_bill(items: list) -> dict:
    subtotal = 0.0

    line_items = []

    for item in items:
        unit_price = round(float(item.get("unit_price", 0)), 2)
        quantity = int(item.get("quantity", 1))
        item_total = round(unit_price * quantity, 2)
        subtotal += item_total

        line_items.append({
            "menu_item_id": item.get("menu_item_id"),
            "item_name": item.get("item_name", ""),
            "quantity": quantity,
            "unit_price": unit_price,
            "item_total": item_total
        })

    subtotal = round(subtotal, 2)
    gst_amount = round(subtotal * Config.GST_RATE, 2)
    total_amount = round(subtotal + gst_amount, 2)

    return {
        "line_items": line_items,
        "subtotal": subtotal,
        "gst_rate": Config.GST_RATE,
        "gst_amount": gst_amount,
        "total_amount": total_amount
    }
