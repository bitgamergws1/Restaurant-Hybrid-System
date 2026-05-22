from supabase import create_client, Client
from config import Config

_client: Client = None


def init_supabase() -> Client:
    global _client
    if _client is None:
        if not Config.SUPABASE_URL or not Config.SUPABASE_SERVICE_KEY:
            raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in environment")
        _client = create_client(Config.SUPABASE_URL, Config.SUPABASE_SERVICE_KEY)
    return _client


def get_db() -> Client:
    if _client is None:
        return init_supabase()
    return _client
