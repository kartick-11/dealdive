import html
import logging
import re
import httpx
import xml.etree.ElementTree as ET
from datetime import datetime, timezone, timedelta
from app.core.config import REQUEST_HEADERS, VANCOUVER_LAT, VANCOUVER_LNG

logger = logging.getLogger(__name__)

STORE_LOCATIONS = {
    "save-on-foods": (49.2827, -123.1207),
    "safeway": (49.2600, -123.1100),
    "no frills": (49.2400, -123.0800),
    "superstore": (49.2300, -123.0700),
    "whole foods": (49.2850, -123.1300),
    "t&t": (49.2780, -123.1050),
    "costco": (49.1900, -122.8490),
    "walmart": (49.1850, -122.8400),
    "sobeys": (49.2500, -123.1150),
    "freshco": (49.2350, -123.0850),
}

ATOM_NS = "http://www.w3.org/2005/Atom"

# Named grocery/supermarket chains — a required signal, not just any generic
# "sale"/"off"/"$" word, which used to let unrelated posts (game keys, news
# articles) slip through as long as they contained a price symbol.
GROCERY_STORE_KEYWORDS = list(STORE_LOCATIONS.keys())

# Food/product terms that support a match ONLY when combined with a grocery
# store name above — on their own they're too generic (e.g. "chicken" alone
# shows up in unrelated posts too).
FOOD_PRODUCT_KEYWORDS = [
    "grocery", "produce", "meat", "chicken", "beef", "pork", "fish",
    "bread", "milk", "cheese", "fruit", "vegetable", "flyer", "pc optimum",
    "scene+", "pantry", "snack",
]

# Titles containing any of these are excluded outright, regardless of other
# matches — these are the categories that were polluting grocery results.
EXCLUDE_KEYWORDS = [
    "steam key", "epic games", "green man gaming", "xbox", "playstation",
    "nintendo", "video game", "gaming", "gpu", "graphics card", "cpu",
    "laptop", "smartphone", "smart tv", "headphones", "earbuds",
    "software", "vpn", "subscription", "streaming service",
]


def scrape_grocery_deals() -> list[dict]:
    logger.info("Starting grocery deals scrape...")
    deals: list[dict] = []

    try:
        rfd_deals = _scrape_redflagdeals()
        deals.extend(rfd_deals)
    except Exception as e:
        logger.error(f"RedFlagDeals scrape failed: {e}")

    logger.info(f"Grocery scrape complete — {len(deals)} deals total.")
    return deals


def _scrape_redflagdeals() -> list[dict]:
    deals = []
    expires_at = datetime.now(timezone.utc) + timedelta(days=3)

    # Food & Drink forum only. The general "Hot Deals" forum (9) was the
    # main source of unrelated results (electronics, games, news) and has
    # been dropped rather than filtered, since no keyword list reliably
    # separates food deals from everything else posted there.
    urls = [
        "https://forums.redflagdeals.com/feed/forum/18",  # Food & Drink
    ]

    all_entries = []
    seen_ids = set()

    for url in urls:
        try:
            with httpx.Client(
                headers=REQUEST_HEADERS, timeout=15, follow_redirects=True
            ) as client:
                resp = client.get(url)
                resp.raise_for_status()

            root = ET.fromstring(resp.text)
            ns = {"atom": ATOM_NS}

            entries = root.findall("atom:entry", ns)
            if not entries:
                entries = root.findall("entry")
            if not entries:
                channel = root.find("channel")
                if channel:
                    entries = channel.findall("item")

            all_entries.extend(entries)
            logger.info(f"RFD {url}: {len(entries)} entries")

        except Exception as e:
            logger.warning(f"RFD feed {url} failed: {e}")

    for entry in all_entries:
        title_el = entry.find(f"{{{ATOM_NS}}}title")
        if title_el is None:
            title_el = entry.find("title")
        if title_el is None or not title_el.text:
            continue

        title = html.unescape(title_el.text.strip())
        if not title or len(title) < 5:
            continue

        if title in seen_ids:
            continue
        seen_ids.add(title)

        content_el = entry.find(f"{{{ATOM_NS}}}content")
        content = html.unescape(content_el.text or "") if content_el is not None else ""
        combined = (title + " " + content).lower()

        # Hard exclude non-grocery categories first.
        if any(k in combined for k in EXCLUDE_KEYWORDS):
            continue

        has_store = any(k in combined for k in GROCERY_STORE_KEYWORDS)
        has_food_term = any(k in combined for k in FOOD_PRODUCT_KEYWORDS)

        # Require a named grocery store, OR a food term alongside some
        # store/product signal — either alone was too weak before.
        if not (has_store or has_food_term):
            continue

        store_name, lat, lng = _guess_store(title)
        price = _extract_price_from_title(title)

        # No extractable price means we can't trust this is a priced deal
        # at all — skip rather than silently writing $0.00.
        if price <= 0:
            continue

        deal = {
            "source": "redflagdeals",
            "source_id": f"rfd_{abs(hash(title))}",
            "title": title[:80],
            "storeName": store_name,
            "category": "Grocery",
            "city": "Vancouver",
            "price": price,
            "latitude": lat,
            "longitude": lng,
            "description": f"Deal from RedFlagDeals: {title}",
            "imageUrl": None,
            "isHot": price < 5.0,
            "expires_at": expires_at,
            "scraped_at": datetime.now(timezone.utc),
        }
        deals.append(deal)

    logger.info(f"RedFlagDeals: {len(deals)} deals total")
    return deals


def _guess_store(title: str) -> tuple[str, float, float]:
    lower = title.lower()
    for key, (lat, lng) in STORE_LOCATIONS.items():
        if key in lower:
            return key.title(), lat, lng
    return "Grocery Store", VANCOUVER_LAT, VANCOUVER_LNG


def _extract_price_from_title(title: str) -> float:
    match = re.search(r"\$(\d+\.?\d*)", title)
    if match:
        try:
            return float(match.group(1))
        except ValueError:
            pass
    return 0.0