import logging
import httpx
from datetime import datetime, timezone, timedelta
from app.core.config import VANCOUVER_LAT, VANCOUVER_LNG, REQUEST_HEADERS

logger = logging.getLogger(__name__)

# Unofficial but widely-used public Flipp consumer search endpoint. No API
# key required. See app.core.config.FLIPP_API_BASE.
SEARCH_URL = "https://backflipp.wishabi.com/flipp/items/search"

# A Vancouver downtown postal code — Flipp scopes flyer availability by
# postal code, so results are local to this area.
POSTAL_CODE = "V6B1A1"

# Category-keyword searches, tagged separately so Electronics gets its own
# filter instead of being lumped into general Retail.
ELECTRONICS_QUERIES = ["electronics", "computers", "phones", "tv", "headphones"]
GENERAL_RETAIL_QUERIES = ["furniture", "clothing", "toys", "appliances", "shoes"]

# Direct merchant-name searches. Category keywords alone miss chains whose
# flyers are mostly hardware/automotive/seasonal (Canadian Tire) rather
# than matching any of the generic category words above — searching the
# store name directly guarantees their real flyer items show up.
MERCHANT_QUERIES = {
    "Canadian Tire": "Retail",
    "Best Buy": "Electronics",
    "The Home Depot": "Retail",
    "Staples": "Retail",
    "London Drugs": "Retail",
}

# Approximate downtown/Metro Vancouver coordinates for common big-box retail
# chains. Falls back to a generic Vancouver coordinate for anything else.
RETAIL_STORE_LOCATIONS = {
    "best buy": (49.2627, -123.1139),
    "canadian tire": (49.2500, -123.1050),
    "the home depot": (49.2450, -123.1100),
    "staples": (49.2650, -123.1200),
    "london drugs": (49.2827, -123.1207),
    "winners": (49.2700, -123.1250),
    "structube": (49.2600, -123.1150),
    "sport chek": (49.2830, -123.1180),
    "the bay": (49.2836, -123.1177),
    "ikea": (49.2010, -122.9070),
    "toys r us": (49.2200, -123.0000),
}

# Merchants to skip even if returned — mainly grocery chains that are
# already handled by grocery_scraper.py, to avoid the same store showing
# up under two different categories with overlapping deals.
EXCLUDE_MERCHANTS = {
    "save-on-foods", "safeway", "no frills", "superstore", "whole foods",
    "t&t", "costco", "sobeys", "freshco",
}


def scrape_retail_deals() -> list[dict]:
    logger.info("Starting retail deals scrape (Flipp)...")
    deals: list[dict] = []
    seen_ids = set()

    for query in ELECTRONICS_QUERIES:
        _run_query(query, "Electronics", deals, seen_ids)

    for query in GENERAL_RETAIL_QUERIES:
        _run_query(query, "Retail", deals, seen_ids)

    for merchant_name, category in MERCHANT_QUERIES.items():
        _run_query(merchant_name, category, deals, seen_ids)

    logger.info(f"Retail scrape complete — {len(deals)} deals total.")
    return deals


def _run_query(query: str, category: str, deals: list[dict], seen_ids: set) -> None:
    try:
        items = _search_flipp(query)
        for item in items:
            deal = _build_deal(item, category)
            if deal is None:
                continue
            if deal["source_id"] in seen_ids:
                continue
            seen_ids.add(deal["source_id"])
            deals.append(deal)
    except Exception as e:
        logger.warning(f"Flipp search failed for '{query}': {e}")


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


def _build_deal(item: dict, category: str) -> dict | None:
    name = item.get("name")
    merchant = item.get("merchant_name")
    price = item.get("current_price")

    if not name or not merchant or price is None:
        return None

    if merchant.lower() in EXCLUDE_MERCHANTS:
        return None

    if not _is_currently_live(item):
        return None

    try:
        price = float(price)
    except (TypeError, ValueError):
        return None

    lat, lng = RETAIL_STORE_LOCATIONS.get(merchant.lower(), (VANCOUVER_LAT, VANCOUVER_LNG))

    expires_at = _parse_valid_to(item.get("valid_to"))
    item_id = item.get("id") or f"{merchant}_{name}"

    original_price = item.get("original_price")
    description = f"{name} at {merchant}"
    if original_price and original_price != price:
        description += f" — was ${original_price}, now ${price}"

    return {
        "source": "flipp",
        "source_id": f"flipp_{item_id}",
        "title": name[:80],
        "storeName": merchant,
        "category": category,
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
    """Only keep items whose flyer is actually active right now — Flipp
    occasionally returns items for a flyer that hasn't started yet or has
    already ended, so this checks valid_from/valid_to explicitly rather
    than assuming every returned item is live. Missing dates are treated
    as live, since Flipp mostly returns currently-active flyers anyway.
    """
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
