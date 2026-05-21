import smtplib
import traceback
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from config import Config


def _send_email(to_address: str, subject: str, html_body: str) -> bool:
    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"{Config.RESTAURANT_NAME} <{Config.GMAIL_SENDER}>"
        msg["To"] = to_address

        msg.attach(MIMEText(html_body, "html"))

        with smtplib.SMTP("smtp.gmail.com", 587) as server:
            server.ehlo()
            server.starttls()
            server.login(Config.GMAIL_SENDER, Config.GMAIL_APP_PASSWORD)
            server.sendmail(Config.GMAIL_SENDER, to_address, msg.as_string())

        return True
    except Exception:
        traceback.print_exc()
        return False


def _base_wrapper(content_html: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
  <title>{Config.RESTAURANT_NAME}</title>
</head>
<body style="margin:0;padding:0;background-color:#0f0f0f;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#0f0f0f;padding:48px 16px;">
    <tr>
      <td align="center">
        <table width="560" cellpadding="0" cellspacing="0" border="0"
               style="max-width:560px;width:100%;background-color:#161616;border-radius:16px;
                      overflow:hidden;border:1px solid #2a2a2a;">

          <!-- header bar -->
          <tr>
            <td style="background:linear-gradient(135deg,#1a1a1a 0%,#222222 100%);
                       padding:32px 40px;border-bottom:1px solid #2a2a2a;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td>
                    <p style="margin:0;font-size:22px;font-weight:800;color:#ffffff;
                               letter-spacing:-0.3px;">{Config.RESTAURANT_NAME}</p>
                    <p style="margin:4px 0 0 0;font-size:11px;color:#666666;
                               letter-spacing:2px;text-transform:uppercase;">Official Communication</p>
                  </td>
                  <td align="right">
                    <div style="width:42px;height:42px;background:linear-gradient(135deg,#ff6b35,#f7931e);
                                border-radius:10px;display:inline-block;"></div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- body content -->
          {content_html}

          <!-- footer -->
          <tr>
            <td style="padding:24px 40px 32px 40px;background-color:#111111;border-top:1px solid #222222;">
              <p style="margin:0 0 6px 0;font-size:12px;color:#444444;text-align:center;">
                This is an automated message — please do not reply directly to this email.
              </p>
              <p style="margin:0;font-size:12px;color:#333333;text-align:center;">
                &copy; {Config.RESTAURANT_NAME}. All rights reserved.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""


def _otp_content(name: str, otp: str, heading: str, subheading: str, body_line: str, note: str) -> str:
    digits = "".join(
        f'<td style="width:44px;height:56px;background-color:#1e1e1e;border:1px solid #333333;'
        f'border-radius:8px;text-align:center;vertical-align:middle;'
        f'font-size:26px;font-weight:800;color:#ff6b35;letter-spacing:0;">{d}</td>'
        f'<td width="6"></td>'
        for d in otp
    )

    return f"""
          <tr>
            <td style="padding:40px 40px 0 40px;">
              <p style="margin:0 0 6px 0;font-size:13px;color:#666666;">Hello, {name if name else 'there'}</p>
              <h1 style="margin:0 0 8px 0;font-size:26px;font-weight:800;color:#ffffff;line-height:1.2;">
                {heading}
              </h1>
              <p style="margin:0;font-size:13px;color:#ff6b35;font-weight:600;
                         letter-spacing:1px;text-transform:uppercase;">{subheading}</p>
            </td>
          </tr>

          <tr>
            <td style="padding:28px 40px 0 40px;">
              <p style="margin:0;font-size:15px;color:#999999;line-height:1.7;">
                {body_line}
              </p>
            </td>
          </tr>

          <tr>
            <td style="padding:32px 40px;">
              <p style="margin:0 0 14px 0;font-size:11px;color:#555555;
                         letter-spacing:2px;text-transform:uppercase;">Your Verification Code</p>
              <table cellpadding="0" cellspacing="0" border="0">
                <tr>
                  {digits}
                </tr>
              </table>
              <p style="margin:20px 0 0 0;font-size:13px;color:#555555;">
                This code expires in <strong style="color:#ff6b35;">5 minutes</strong>.
              </p>
            </td>
          </tr>

          <tr>
            <td style="padding:0 40px 40px 40px;">
              <table cellpadding="0" cellspacing="0" border="0" width="100%"
                     style="background-color:#1a1a1a;border:1px solid #2a2a2a;border-radius:10px;">
                <tr>
                  <td style="padding:16px 20px;">
                    <p style="margin:0;font-size:12px;color:#555555;line-height:1.7;">
                      <strong style="color:#444444;">Security notice:</strong> {note}
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
    """


def send_otp_email(to_address: str, otp: str, purpose: str, name: str = "") -> bool:
    if purpose == "signup":
        subject = f"Verify your account — {Config.RESTAURANT_NAME}"
        heading = "Confirm Your Email Address"
        subheading = "Account Verification"
        body_line = (
            "You are one step away from activating your account. "
            "Enter the 6-digit code below to verify your email address and get started."
        )
        note = "If you did not create an account with us, you can safely ignore this message. Do not share this code with anyone."
    else:
        subject = f"Reset your password — {Config.RESTAURANT_NAME}"
        heading = "Reset Your Password"
        subheading = "Password Recovery"
        body_line = (
            "We received a request to reset the password associated with your account. "
            "Use the code below to proceed. If you did not make this request, no action is required."
        )
        note = "For your security, this code is single-use and expires in 5 minutes. Never share it with anyone, including our staff."

    content = _otp_content(name, otp, heading, subheading, body_line, note)
    html = _base_wrapper(content)
    return _send_email(to_address, subject, html)


def send_invoice_email(to_address: str, user_name: str, order: dict, items: list) -> bool:
    order_id = str(order.get("id", ""))
    order_id_short = order_id[:8].upper()
    order_type = order.get("order_type", "")
    subtotal = float(order.get("subtotal", 0))
    gst_amount = float(order.get("gst_amount", 0))
    total_amount = float(order.get("total_amount", 0))
    created_at_raw = str(order.get("created_at", ""))
    created_date = created_at_raw[:10] if created_at_raw else "—"
    created_time = created_at_raw[11:16] if len(created_at_raw) > 15 else "—"
    tracking_link = f"{Config.TRACKING_BASE_URL}/{order_id}"
    order_type_label = "Dine-In" if order_type == "dine_in" else "Home Delivery"

    order_type_color = "#ff6b35" if order_type == "dine_in" else "#4facfe"

    # table header
    items_rows = ""
    for item in items:
        item_name = str(item.get("item_name", ""))
        qty = int(item.get("quantity", 1))
        unit_price = float(item.get("unit_price", 0))
        item_total = float(item.get("item_total", 0))

        items_rows += f"""
              <tr>
                <td style="padding:14px 0;border-bottom:1px solid #222222;
                            font-size:14px;color:#cccccc;vertical-align:top;">
                  {item_name}
                </td>
                <td style="padding:14px 0;border-bottom:1px solid #222222;
                            font-size:14px;color:#888888;text-align:center;vertical-align:top;">
                  {qty}
                </td>
                <td style="padding:14px 0;border-bottom:1px solid #222222;
                            font-size:14px;color:#888888;text-align:right;vertical-align:top;">
                  Rs.&nbsp;{unit_price:.2f}
                </td>
                <td style="padding:14px 0;border-bottom:1px solid #222222;
                            font-size:14px;color:#ffffff;font-weight:600;text-align:right;vertical-align:top;">
                  Rs.&nbsp;{item_total:.2f}
                </td>
              </tr>"""

    content = f"""
          <!-- order badge -->
          <tr>
            <td style="padding:36px 40px 0 40px;">
              <table cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="background-color:{order_type_color}1a;border:1px solid {order_type_color}40;
                              border-radius:20px;padding:5px 14px;">
                    <p style="margin:0;font-size:11px;font-weight:700;color:{order_type_color};
                               letter-spacing:1.5px;text-transform:uppercase;">{order_type_label}</p>
                  </td>
                </tr>
              </table>
              <h1 style="margin:16px 0 4px 0;font-size:26px;font-weight:800;color:#ffffff;">
                Your Invoice is Ready
              </h1>
              <p style="margin:0;font-size:14px;color:#666666;">
                Hi {user_name}, thank you for your order. Here is your full billing summary.
              </p>
            </td>
          </tr>

          <!-- order meta -->
          <tr>
            <td style="padding:28px 40px 0 40px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0"
                     style="background-color:#1a1a1a;border:1px solid #2a2a2a;border-radius:12px;">
                <tr>
                  <td style="padding:20px 24px;border-right:1px solid #222222;" width="33%">
                    <p style="margin:0 0 4px 0;font-size:10px;color:#555555;
                               letter-spacing:1.5px;text-transform:uppercase;">Order ID</p>
                    <p style="margin:0;font-size:14px;font-weight:700;color:#ff6b35;
                               font-family:monospace;">{order_id_short}</p>
                  </td>
                  <td style="padding:20px 24px;border-right:1px solid #222222;" width="33%">
                    <p style="margin:0 0 4px 0;font-size:10px;color:#555555;
                               letter-spacing:1.5px;text-transform:uppercase;">Date</p>
                    <p style="margin:0;font-size:14px;font-weight:700;color:#cccccc;">{created_date}</p>
                  </td>
                  <td style="padding:20px 24px;" width="33%">
                    <p style="margin:0 0 4px 0;font-size:10px;color:#555555;
                               letter-spacing:1.5px;text-transform:uppercase;">Time</p>
                    <p style="margin:0;font-size:14px;font-weight:700;color:#cccccc;">{created_time} IST</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- items table -->
          <tr>
            <td style="padding:28px 40px 0 40px;">
              <p style="margin:0 0 16px 0;font-size:11px;color:#555555;
                         letter-spacing:2px;text-transform:uppercase;">Order Summary</p>
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <th style="padding:0 0 12px 0;font-size:11px;color:#444444;font-weight:600;
                              text-align:left;letter-spacing:1px;text-transform:uppercase;
                              border-bottom:1px solid #2a2a2a;">Item</th>
                  <th style="padding:0 0 12px 0;font-size:11px;color:#444444;font-weight:600;
                              text-align:center;letter-spacing:1px;text-transform:uppercase;
                              border-bottom:1px solid #2a2a2a;">Qty</th>
                  <th style="padding:0 0 12px 0;font-size:11px;color:#444444;font-weight:600;
                              text-align:right;letter-spacing:1px;text-transform:uppercase;
                              border-bottom:1px solid #2a2a2a;">Rate</th>
                  <th style="padding:0 0 12px 0;font-size:11px;color:#444444;font-weight:600;
                              text-align:right;letter-spacing:1px;text-transform:uppercase;
                              border-bottom:1px solid #2a2a2a;">Total</th>
                </tr>
                {items_rows}
              </table>
            </td>
          </tr>

          <!-- billing totals -->
          <tr>
            <td style="padding:20px 40px 0 40px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="padding:8px 0;" colspan="2">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td style="font-size:13px;color:#777777;">Subtotal</td>
                        <td style="font-size:13px;color:#aaaaaa;text-align:right;">
                          Rs.&nbsp;{subtotal:.2f}
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td colspan="2">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td style="padding:8px 0;font-size:13px;color:#777777;">
                          GST <span style="color:#555555;">(18%)</span>
                        </td>
                        <td style="padding:8px 0;font-size:13px;color:#aaaaaa;text-align:right;">
                          Rs.&nbsp;{gst_amount:.2f}
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td colspan="2" style="padding-top:4px;">
                    <div style="height:1px;background:linear-gradient(90deg,#333333,#ff6b3540,#333333);"></div>
                  </td>
                </tr>
                <tr>
                  <td colspan="2">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td style="padding:16px 0 0 0;font-size:16px;font-weight:800;color:#ffffff;">
                          Total Paid
                        </td>
                        <td style="padding:16px 0 0 0;font-size:20px;font-weight:800;
                                    color:#ff6b35;text-align:right;">
                          Rs.&nbsp;{total_amount:.2f}
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- track order CTA -->
          <tr>
            <td style="padding:32px 40px 40px 40px;">
              <table cellpadding="0" cellspacing="0" border="0" width="100%"
                     style="background:linear-gradient(135deg,#1e1e1e,#1a1a1a);
                             border:1px solid #2a2a2a;border-radius:12px;">
                <tr>
                  <td style="padding:24px 28px;">
                    <p style="margin:0 0 4px 0;font-size:13px;color:#888888;">
                      Want to know where your order is?
                    </p>
                    <p style="margin:0 0 18px 0;font-size:16px;font-weight:700;color:#ffffff;">
                      Track your order in real time
                    </p>
                    <a href="{tracking_link}"
                       style="display:inline-block;background:linear-gradient(135deg,#ff6b35,#f7931e);
                               color:#ffffff;text-decoration:none;padding:12px 28px;
                               border-radius:8px;font-size:14px;font-weight:700;
                               letter-spacing:0.3px;">
                      Track Order &rarr;
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
    """

    html = _base_wrapper(content)
    subject = f"Invoice #{order_id_short} — {Config.RESTAURANT_NAME}"
    return _send_email(to_address, subject, html)
