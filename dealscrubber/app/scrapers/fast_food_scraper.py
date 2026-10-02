import html
import logging
import re
import httpx
import xml.etree.ElementTree as ET
from datetime import datetime, timezone, timedelta
from app.core.config import REQUEST_HEADERS, VANCOUVER_LAT, VANCOUVER_LNG

logger = logging.getLogger(__name__)

ATOM_NS = "http://www.w3.org/2005/Atom"

# Tier 1 national chains. Matched strictly against these names — a much
# stronger signal than generic words ("off", "$", "sale"), which is why
# it's safe to also scan the noisier Hot Deals forum here, unlike the
# grocery scraper which had to drop it.
CHAINS = [
    "mcdonald's", "mcdonalds", "tim hortons", "a&w", "subway", "kfc",
    "pizza hut", "domino's", "dominos", "wendy's", "wendys",
    "dairy queen", "starbucks", "freshslice", "jollibee", "boston pizza",
    "white spot", "triple o's", "triple o", "panago", "freshii",
]

# Real forum sources — both scanned now, since fast food promos post to
# either one and chain-name matching is specific enough to stay clean.
FEED_URLS = [
    "https://forums.redflagdeals.com/feed/forum/18",  # Food & Drink
    "https://forums.redflagdeals.com/feed/forum/9",   # Hot Deals
]


def scrape_fast_food_deals() -> list[dict]:
    logger.info("Starting fast food deals scrape...")
    deals: list[dict] = []
    seen_titles = set()
    expires_at = datetime.now(timezone.utc) + timedelta(days=3)

    for url in FEED_URLS:
        try:
            entries = _fetch_entries(url)
        except Exception as e:
            logger.warning(f"Fast food feed {url} failed: {e}")
            continue

        for entry in entries:
            title_el = entry.find(f"{{{ATOM_NS}}}title")
            if title_el is None or not title_el.text:
                continue

            title = html.unescape(title_el.text.strip())
            if len(title) < 5 or title in seen_titles:
                continue

            content_el = entry.find(f"{{{ATOM_NS}}}content")
            content = html.unescape(content_el.text or "") if content_el is not None else ""
            combined = (title + " " + content).lower()

            matched_chain = next((c for c in CHAINS if c in combined), None)
            if not matched_chain:
                continue

            price = _extract_price(title) or _extract_price(content)
            if price <= 0:
                continue  # no real priced offer found — skip rather than fabricate one

            seen_titles.add(title)
            deals.append({
                "source": "redflagdeals",
                "source_id": f"fastfood_rfd_{abs(hash(title))}",
                "title": title[:80],
                "storeName": _canonical_name(matched_chain),
                "category": "Fast Food",
                "price": price,
                "latitude": VANCOUVER_LAT,
                "longitude": VANCOUVER_LNG,
                "description": f"Deal from RedFlagDeals: {title}",
                "imageUrl": None,
                "isHot": price < 5.0,
                "expires_at": expires_at,
                "scraped_at": datetime.now(timezone.utc),
            })

    logger.info(f"Fast food scrape complete — {len(deals)} real deals found.")
    return deals


def _fetch_entries(url: str) -> list:
    with httpx.Client(headers=REQUEST_HEADERS, timeout=15, follow_redirects=True) as client:
        resp = client.get(url)
        resp.raise_for_status()

    root = ET.fromstring(resp.text)
    ns = {"atom": ATOM_NS}
    entries = root.findall("atom:entry", ns)
    if not entries:
        entries = root.findall("entry")
    return entries


def _extract_price(title: str) -> float:
    match = re.search(r"\$(\d+\.?\d*)", title)
    if match:
        try:
            return float(match.group(1))
        except ValueError:
            pass
    return 0.0


def _canonical_name(matched: str) -> str:
    names = {
        "mcdonald's": "McDonald's", "mcdonalds": "McDonald's",
        "tim hortons": "Tim Hortons", "a&w": "A&W", "subway": "Subway",
        "kfc": "KFC", "pizza hut": "Pizza Hut",
        "domino's": "Domino's", "dominos": "Domino's",
        "wendy's": "Wendy's", "wendys": "Wendy's",
        "dairy queen": "Dairy Queen", "starbucks": "Starbucks",
        "freshslice": "Freshslice", "jollibee": "Jollibee",
        "boston pizza": "Boston Pizza", "white spot": "White Spot",
        "triple o's": "Triple O's", "triple o": "Triple O's",
        "panago": "Panago", "freshii": "Freshii",
    }
    return names.get(matched, matched.title())