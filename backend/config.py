import os


class Config:
    # supabase
    SUPABASE_URL = os.environ.get("SUPABASE_URL")
    SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")

    # brevo http api (replaces gmail smtp)
    BREVO_API_KEY = os.environ.get("BREVO_API_KEY")
    BREVO_SENDER_EMAIL = os.environ.get("BREVO_SENDER_EMAIL")
    BREVO_SENDER_NAME = os.environ.get("BREVO_SENDER_NAME", "Spice Route")

    # devnest proxy
    PROXY_URL = "https://devnest-proxy-server.onrender.com/v1/proxy/ai"
    PROXY_HEALTH_URL = "https://devnest-proxy-server.onrender.com/health"
    DEVNEST_TOKEN = os.environ.get("DEVNEST_TOKEN", "DEVNEST_EVAL_2026")

    # frontend
    FRONTEND_ORIGIN = os.environ.get("FRONTEND_ORIGIN", "*")

    # restaurant identity
    RESTAURANT_NAME = os.environ.get("RESTAURANT_NAME", "Spice Route")
    RESTAURANT_SUPPORT_EMAIL = os.environ.get("RESTAURANT_SUPPORT_EMAIL", "")
    TRACKING_BASE_URL = os.environ.get("TRACKING_BASE_URL", "https://yourapp.com/track")

    # business constants
    GST_RATE = 0.18
    OTP_EXPIRY_SECONDS = 300
    SESSION_EXPIRY_HOURS = 24

    # external apis
    POSTAL_API_BASE = "https://api.postalpincode.in/pincode"
    BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"
