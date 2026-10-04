import logging
import re
import httpx
from bs4 import BeautifulSoup
from datetime import datetime, timezone, timedelta
from app.core.config import REQUEST_HEADERS, VANCOUVER_LAT, VANCOUVER_LNG

logger = logging.getLogger(__name__)

VANCOUVER_STATIONS = [
    {"name": "Shell Kingsway", "lat": 49.2445, "lng": -123.0650},
    {"name": "Esso Hastings", "lat": 49.2827, "lng": -123.0690},
    {"name": "Chevron Broadway", "lat": 49.2630, "lng": -123.1010},
    {"name": "Petro-Canada Granville", "lat": 49.2730, "lng": -123.1440},
    {"name": "Shell Denman", "lat": 49.2890, "lng": -123.1390},
]

# Kent Group was rebranded to Kalibrate Canada Inc. and their old public
# consumer gas-price page (kent.ca/en/gas-prices) has been 404ing — moved
# to a B2B analytics product with no simple public page. Kept here as the
# first attempt in case it ever comes back or redirects somewhere usable;
# falls through to a real Vancouver-specific source if it doesn't.
KENT_URL = "https://www.kent.ca/en/gas-prices"

# Real, Vancouver-specific, updated daily. Note: this is explicitly a
# forecast/prediction (Canadians for Affordable Energy's "Gas Wizard", by
# Dan McTeague), not a verified official retail average — labelled as such
# in the deal description rather than implied as measured.
FORECAST_URL = "https://www.affordableenergy.ca/gas-prices/vancouver/"


def scrape_gas_deals() -> list[dict]:
    logger.info("Starting gas price scrape...")
    deals: list[dict] = []

    price, source_label = _get_price_with_fallbacks()
    deals = _build_deals_from_price(price, source_label)

    logger.info(f"Gas scrape complete — {len(deals)} deals (source: {source_label}).")
    return deals


def _get_price_with_fallbacks() -> tuple[float, str]:
    # 1. Try Kent/Kalibrate first, in case their public page ever returns.
    try:
        price = _scrape_kent_gas_price()
        if price:
            logger.info(f"Got Vancouver gas price from Kent: ${price}/L")
            return price, "kent"
    except Exception as e:
        logger.warning(f"Kent gas price scrape failed: {e}")

    # 2. Real Vancouver-specific forecast source.
    try:
        price = _scrape_vancouver_forecast()
        if price:
            logger.info(f"Got Vancouver gas price forecast: ${price}/L")
            return price, "forecast"
    except Exception as e:
        logger.warning(f"Vancouver gas forecast scrape failed: {e}")

    # 3. Last resort — static estimate, clearly labelled as such.
    logger.warning("All gas price sources failed, using hardcoded fallback.")
    return 1.799, "fallback"


def _scrape_kent_gas_price() -> float | None:
    with httpx.Client(headers=REQUEST_HEADERS, timeout=15, follow_redirects=True) as client:
        resp = client.get(KENT_URL)
        resp.raise_for_status()

    soup = BeautifulSoup(resp.text, "html.parser")

    for el in soup.find_all(string=True):
        text = el.strip()
        if "vancouver" in text.lower():
            parent = el.parent
            price_text = parent.get_text(strip=True) if parent else ""
            price = _parse_cents_or_dollars(price_text)
            if price:
                return price

    price_els = soup.select(".price, .gas-price, .fuel-price")
    for el in price_els:
        price = _parse_cents_or_dollars(el.get_text(strip=True))
        if price:
            return price

    return None


def _scrape_vancouver_forecast() -> float | None:
    with httpx.Client(headers=REQUEST_HEADERS, timeout=15, follow_redirects=True) as client:
        resp = client.get(FORECAST_URL)
        resp.raise_for_status()

    # A clear, stable sentence pattern rather than positional table
    # scraping: "Regular gas in Vancouver is forecast at 203.9¢/L"
    match = re.search(r"forecast at\s*(\d+\.\d+)\s*¢", resp.text, re.IGNORECASE)
    if match:
        cents = float(match.group(1))
        return round(cents / 100, 3)

    return None


def _parse_cents_or_dollars(text: str) -> float | None:
    match = re.search(r"(\d{1,3}\.?\d*)", text)
    if match:
        try:
            val = float(match.group(1))
            return val / 100 if val > 10 else val
        except ValueError:
            pass
    return None


def _build_deals_from_price(price: float, source_label: str) -> list[dict]:
    expires_at = datetime.now(timezone.utc) + timedelta(hours=6)
    deals = []

    label_text = {
        "kent": "measured price (Kent/Kalibrate)",
        "forecast": "forecast (Canadians for Affordable Energy)",
        "fallback": "fallback estimate — live sources unavailable",
    }[source_label]

    # Previously each station got a random +/-2c jitter to look like a real
    # measured per-station price. That was fabricated precision — the
    # source only gives one citywide number — so every station now shows
    # that same real number, with the description honest about what it is.
    for station in VANCOUVER_STATIONS:
        deals.append({
            "source": source_label,
            "source_id": f"gas_{station['name'].replace(' ', '_')}",
            "title": f"Gas – ${price:.3f}/L",
            "storeName": station["name"],
            "category": "Gas",
            "city": "Vancouver",
            "price": price,
            "latitude": station["lat"],
            "longitude": station["lng"],
            "description": (
                f"Vancouver regular unleaded, {label_text}. This is a "
                f"citywide figure, not a price measured at {station['name']} "
                f"specifically — check the pump for the exact price."
            ),
            "imageUrl": None,
            "isHot": price < 1.95,
            "expires_at": expires_at,
            "scraped_at": datetime.now(timezone.utc),
        })

    deals.sort(key=lambda d: d["price"])
    return deals
