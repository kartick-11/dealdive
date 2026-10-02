import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DATA_PATH = os.path.join(BASE_DIR, "data", "deals.json")
LOG_FILE = os.path.join(BASE_DIR, "logs", "app.log")

FIREBASE_CREDENTIALS = os.environ.get(
    "FIREBASE_CREDENTIALS",
    os.path.join(BASE_DIR, "firebase_credentials.json"),
)

SCRAPE_INTERVAL_HOURS = int(os.environ.get("SCRAPE_INTERVAL_HOURS", "6"))

VANCOUVER_LAT = 49.2827
VANCOUVER_LNG = -123.1207
SEARCH_RADIUS_KM = 25

FLIPP_API_BASE = "https://backflipp.wishabi.com/flipp"
GASBUDDY_URL = "https://www.gasbuddy.com/graphql"

REQUEST_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-CA,en;q=0.9",
}