import logging
import httpx
from datetime import datetime, timezone, timedelta
from app.core.config import VANCOUVER_LAT, VANCOUVER_LNG, REQUEST_HEADERS

logger = logging.getLogger(__name__)

# Same unofficial Flipp consumer search endpoint retail_scraper.py uses —
# it carries real, current grocery flyer items (Save-On-Foods, Safeway,
# Superstore, etc.), which is a far more reliable source than scanning a
# RedFlagDeals RSS forum and hoping a post happens to name a store and a
# dollar price in its title (that approach returned ~0 deals almost every
# cycle — see git history).
SEARCH_URL = "https://backflipp.wishabi.com/flipp/items/search"

POSTAL_CODE = "V6B1A1"

# Generic grocery-term searches, to catch flyer items that don't surface
# under a specific merchant search.
GROCERY_QUERIES = [
    "produce", "meat", "dairy", "bakery", "frozen food", "snacks",
]

# Direct merchant searches — guarantees each chain's real flyer items show
# up even if their items don't match a generic term above.
MERCHANT_QUERIES = [
    "Save-On-Foods", "Safeway", "No Frills", "Real Canadian Superstore",
    "Walmart", "T&T Supermarket", "Costco", "Whole Foods", "Sobeys",
    "FreshCo",
]

GROCERY_STORE_LOCATIONS = {
    "save-on-foods": (49.2827, -123.1207),
    "safeway": (49.2600, -123.1100),
    "no frills": (49.2400, -123.0800),
    "real canadian superstore": (49.2300, -123.0700),
    "superstore": (49.2300, -123.0700),
    "whole foods": (49.2850, -123.1300),
    "t&t supermarket": (49.2780, -123.1050),
    "t&t": (49.2780, -123.1050),
    "costco": (49.1900, -122.8490),
    "walmart": (49.1850, -122.8400),
    "sobeys": (49.2500, -123.1150),
    "freshco": (49.2350, -123.0850),
}


def scrape_grocery_deals() -> list[dict]:
    logger.info("Starting grocery deals scrape (Flipp)...")
    deals: list[dict] = []
    seen_ids: set[str] = set()

    for query in GROCERY_QUERIES:
        _run_query(query, deals, seen_ids)

    for merchant in MERCHANT_QUERIES:
        _run_query(merchant, deals, seen_ids)

    logger.info(f"Grocery scrape complete — {len(deals)} deals total.")
    return deals


def _run_query(query: str, deals: list[dict], seen_ids: set) -> None:
    try:
        items = _search_flipp(query)
        for item in items:
            deal = _build_deal(item)
            if deal is None:
                continue
            if deal["source_id"] in seen_ids:
                continue
            seen_ids.add(deal["source_id"])
            deals.append(deal)
    except Exception as e:
        logger.warning(f"Flipp grocery search failed for '{query}': {e}")


def _search_flipp(query: str) -> list[dict]:
    with httpx.Client(headers=REQUEST_HEADERS, timeout=15, follow_redirects=True) as client:
        resp = client.get(
            SEARCH_URL,
            params={"q": query, "postal_code": POSTAL_CODE, "locale": "en-ca"},
        )
        resp.raise_for_status()
        data = resp.json()

    items = data.get("items") or data.get("data", {}).get("items") or []
    return items


def _build_deal(item: dict) -> dict | None:
    name = item.get("name")
    merchant = item.get("merchant_name")
    price = item.get("current_price")

    if not name or not merchant or price is None:
        return None

    if not _is_currently_live(item):
        return None

    try:
        price = float(price)
    except (TypeError, ValueError):
        return None

    lat, lng = GROCERY_STORE_LOCATIONS.get(
        merchant.lower(), (VANCOUVER_LAT, VANCOUVER_LNG)
    )

    expires_at = _parse_valid_to(item.get("valid_to"))
    item_id = item.get("id") or f"{merchant}_{name}"

    original_price = item.get("original_price")
    description = f"{name} at {merchant}"
    if original_price and original_price != price:
        description += f" — was ${original_price}, now ${price}"

    return {
        "source": "flipp",
        "source_id": f"flipp_grocery_{item_id}",
        "title": name[:80],
        "storeName": merchant,
        "category": "Grocery",
        "city": "Vancouver",
        "price": price,
        "latitude": lat,
        "longitude": lng,
        "description": description[:300],
        "imageUrl": item.get("image_url"),
        "isHot": bool(original_price) and price < float(original_price) * 0.7,
        "expires_at": expires_at,
        "scraped_at": datetime.now(timezone.utc),
    }


def _parse_valid_to(valid_to: str | None) -> datetime:
    fallback = datetime.now(timezone.utc) + timedelta(days=3)
    if not valid_to:
        return fallback
    try:
        return datetime.fromisoformat(valid_to.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return fallback


def _is_currently_live(item: dict) -> bool:
    now = datetime.now(timezone.utc)

    valid_from = item.get("valid_from")
    if valid_from:
        try:
            start = datetime.fromisoformat(valid_from.replace("Z", "+00:00"))
            if now < start:
                return False
        except (ValueError, AttributeError):
            pass

    valid_to = item.get("valid_to")
    if valid_to:
        try:
            end = datetime.fromisoformat(valid_to.replace("Z", "+00:00"))
            if now > end:
                return False
        except (ValueError, AttributeError):
            pass

    return True
