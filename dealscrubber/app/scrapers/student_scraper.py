import logging
from datetime import datetime, timezone, timedelta

logger = logging.getLogger(__name__)

UBC_COORDS = (49.2606, -123.2460)
BCIT_COORDS = (49.2496, -122.9989)

# Verified, publicly documented student discounts as of the sources
# checked. Real discount percentages, not placeholder text — these are
# genuine, named offers.
UBC_DEALS = [
    {
        "storeName": "Urban Fare",
        "title": "10% off with UBC student ID",
        "description": "10% off everything (excluding tobacco and lottery) with valid UBC student ID and a More Rewards card.",
    },
    {
        "storeName": "IGA (West 4th)",
        "title": "10% off with UBC student ID",
        "description": "10% off regular-priced items (excluding tobacco and lottery) for currently enrolled UBC students showing their student card.",
    },
    {
        "storeName": "Bulk Barn",
        "title": "15% off Wednesdays with student ID",
        "description": "15% off regular-priced items every Wednesday with a valid student ID.",
    },
    {
        "storeName": "Four Olives",
        "title": "20% off dine-in after 8pm",
        "description": "20% off all dine-in main courses after 8pm with the purchase of a beverage.",
    },
    {
        "storeName": "BAK'D Cookies",
        "title": "AUS Purple Card discount",
        "description": "Discount for UBC Arts undergraduate students with the AUS Purple Card.",
    },
    {
        "storeName": "Chatime (UBC)",
        "title": "AUS Purple Card discount",
        "description": "Discount for UBC Arts undergraduate students with the AUS Purple Card.",
    },
    {
        "storeName": "TEADOT",
        "title": "AUS Purple Card discount",
        "description": "Discount for UBC Arts undergraduate students with the AUS Purple Card.",
    },
    {
        "storeName": "Loafe Café",
        "title": "AUS Purple Card discount",
        "description": "Discount for UBC Arts undergraduate students with the AUS Purple Card.",
    },
    {
        "storeName": "Booster Juice (UBC)",
        "title": "5% off with UBC Card",
        "description": "5% off when paying with the UBC Card value plan at this campus food outlet.",
    },
    {
        "storeName": "Subway (UBC)",
        "title": "5% off with UBC Card",
        "description": "5% off when paying with the UBC Card value plan at this campus food outlet.",
    },
]

BCIT_ALUMNI_DEALS = [
    {
        "storeName": "Best Western",
        "title": "20% off with BCIT Alumni Perks",
        "description": "Save 20% at Best Western with BCIT Alumni Perks. Note: this is BCIT's alumni program, not a current-student discount.",
    },
    {
        "storeName": "Element Vancouver Metrotown Hotel",
        "title": "Up to 20% off with BCIT Alumni Perks",
        "description": "Save up to 20% off your stay with BCIT Alumni Perks. Note: this is BCIT's alumni program, not a current-student discount.",
    },
    {
        "storeName": "Delta Hotels Burnaby Conference Centre",
        "title": "15% off with BCIT Alumni Perks",
        "description": "Get 15% off the best available rate with BCIT Alumni Perks. Note: this is BCIT's alumni program, not a current-student discount.",
    },
]


def scrape_student_deals() -> list[dict]:
    logger.info("Starting student deals scrape...")
    deals: list[dict] = []
    expires_at = datetime.now(timezone.utc) + timedelta(days=14)

    for d in UBC_DEALS:
        deals.append(_build_deal(d, "UBC", UBC_COORDS, "Vancouver", expires_at))

    for d in BCIT_ALUMNI_DEALS:
        deals.append(_build_deal(d, "BCIT", BCIT_COORDS, "Burnaby", expires_at))

    logger.info(f"Student scrape complete — {len(deals)} deals.")
    return deals


def _build_deal(d: dict, campus: str, coords: tuple[float, float], city: str, expires_at) -> dict:
    lat, lng = coords
    return {
        "source": "curated",
        "source_id": f"student_{_slugify(campus)}_{_slugify(d['storeName'])}",
        "title": d["title"],
        "storeName": d["storeName"],
        "category": "Student",
        "city": city,
        "price": 0.0,  # percentage discount, not a fixed price
        "latitude": lat,
        "longitude": lng,
        "description": d["description"],
        "imageUrl": None,
        "isHot": False,
        "expires_at": expires_at,
        "scraped_at": datetime.now(timezone.utc),
    }


def _slugify(text: str) -> str:
    import re
    slug = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
    return slug or "item"