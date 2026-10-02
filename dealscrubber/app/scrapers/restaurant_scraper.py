import logging
import httpx
from datetime import datetime, timezone, timedelta
from app.core.config import REQUEST_HEADERS, VANCOUVER_LAT, VANCOUVER_LNG

logger = logging.getLogger(__name__)

STATIC_DEALS = [
    {
        "title": "Happy Hour – 50% OFF Appetizers",
        "storeName": "Earls Kitchen + Bar (Bentall)",
        "category": "Food",
        "price": 6.00,
        "latitude": 49.2850,
        "longitude": -123.1215,
        "description": "Half-price appetizers and drink specials Mon–Fri 3–5 PM.",
        "imageUrl": "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445",
        "isHot": True,
    },
    {
        "title": "Lunch Special – Ramen + Gyoza Combo",
        "storeName": "Motomachi Shokudo",
        "category": "Food",
        "price": 14.50,
        "latitude": 49.2810,
        "longitude": -123.1080,
        "description": "Ramen bowl + 3 gyoza lunch combo, weekdays only.",
        "imageUrl": "https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d",
        "isHot": False,
    },
    {
        "title": "Student Deal – Pho + Spring Roll",
        "storeName": "Pho Boi Vietnamese",
        "category": "Student",
        "price": 9.99,
        "latitude": 49.2655,
        "longitude": -123.2494,
        "description": "Student ID required. Large pho + 2 spring rolls.",
        "imageUrl": "https://images.unsplash.com/photo-1555126634-323283e090fa",
        "isHot": True,
    },
    {
        "title": "2-for-1 Tacos – Taco Tuesday",
        "storeName": "La Taqueria Pinche Taco Shop",
        "category": "Food",
        "price": 4.50,
        "latitude": 49.2798,
        "longitude": -123.1093,
        "description": "Every Tuesday – buy one taco, get one free.",
        "imageUrl": "https://images.unsplash.com/photo-1551504734-5ee1c4a1479b",
        "isHot": True,
    },
    {
        "title": "Breakfast Special – Eggs + Coffee",
        "storeName": "Bon's Off Broadway",
        "category": "Food",
        "price": 7.25,
        "latitude": 49.2627,
        "longitude": -123.0785,
        "description": "Classic diner breakfast with eggs, toast, and drip coffee.",
        "imageUrl": "https://images.unsplash.com/photo-1533089860892-a7c6f0a88666",
        "isHot": False,
    },
    {
        "title": "AYCE Sushi – Lunch",
        "storeName": "Samurai Sushi Robson",
        "category": "Food",
        "price": 19.99,
        "latitude": 49.2839,
        "longitude": -123.1255,
        "description": "All-you-can-eat sushi lunch special, weekdays 11:30 AM–2:30 PM.",
        "imageUrl": "https://images.unsplash.com/photo-1579871494447-9811cf80d66c",
        "isHot": True,
    },
]


def scrape_restaurant_deals() -> list[dict]:
    logger.info("Starting restaurant deals scrape...")
    deals: list[dict] = []

    deals.extend(_build_static_deals())

    try:
        live = _scrape_scout_rss()
        deals.extend(live)
        logger.info(f"Scout RSS: {len(live)} deals")
    except Exception as e:
        logger.warning(f"Scout RSS scrape failed (non-fatal): {e}")

    logger.info(f"Restaurant scrape complete — {len(deals)} deals.")
    return deals


def _build_static_deals() -> list[dict]:
    result = []
    expires_at = datetime.now(timezone.utc) + timedelta(days=1)

    for i, d in enumerate(STATIC_DEALS):
        result.append({
            **d,
            "source": "static",
            "source_id": f"static_restaurant_{i}",
            "city": "Vancouver",
            "expires_at": expires_at,
            "scraped_at": datetime.now(timezone.utc),
        })
    return result


def _scrape_scout_rss() -> list[dict]:
    import xml.etree.ElementTree as ET

    url = "https://www.scoutmagazine.ca/category/eat-drink/deals/feed/"
    expires_at = datetime.now(timezone.utc) + timedelta(days=3)

    with httpx.Client(headers=REQUEST_HEADERS, timeout=15) as client:
        resp = client.get(url)
        resp.raise_for_status()

    root = ET.fromstring(resp.text)
    channel = root.find("channel")
    if channel is None:
        return []

    deals = []
    for item in channel.findall("item")[:10]:
        title = _xml_text(item, "title")
        description = _xml_text(item, "description")
        link = _xml_text(item, "link")

        if not title:
            continue

        deal = {
            "source": "scout_rss",
            "source_id": f"scout_{abs(hash(title))}",
            "title": title[:80],
            "storeName": "See description",
            "category": "Food",
            "city": "Vancouver",
            "price": 0.0,
            "latitude": VANCOUVER_LAT,
            "longitude": VANCOUVER_LNG,
            "description": _strip_html(description)[:300] if description else link or "",
            "imageUrl": None,
            "isHot": False,
            "expires_at": expires_at,
            "scraped_at": datetime.now(timezone.utc),
        }
        deals.append(deal)

    return deals


def _xml_text(element, tag: str) -> str | None:
    child = element.find(tag)
    return child.text.strip() if child is not None and child.text else None


def _strip_html(text: str) -> str:
    import re
    return re.sub(r"<[^>]+>", "", text).strip()