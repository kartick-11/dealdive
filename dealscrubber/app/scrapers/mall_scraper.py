import logging
from datetime import datetime, timezone, timedelta

logger = logging.getLogger(__name__)

# Same three malls as black_friday_scraper.py, but these entries are an
# ongoing store directory, refreshed on the normal scrape cycle rather than
# tied to the Black Friday seasonal window.
#
# Tagged as its own "Mall Directory" category (not "Retail") because these
# have no real price or promotion — they're a list of tenants, not deals.
# Mixing them into Retail diluted the real, priced Flipp-sourced deals with
# generic "check in-store for offers" filler.
MCARTHURGLEN_COORDS = (49.1975, -123.1406)
TSAWWASSEN_MILLS_COORDS = (49.0381, -123.0860)
METROTOWN_COORDS = (49.2273, -123.0032)

MCARTHURGLEN_STORES = [
    "Nike", "Coach", "Polo Ralph Lauren", "Michael Kors", "Aritzia",
    "BOSS", "Burberry", "Levi's", "Lululemon", "Tory Burch",
    "Stuart Weitzman", "Under Armour", "The North Face", "Tommy Hilfiger",
    "Arc'teryx", "Knix", "Fossil", "Swarovski", "Sunglass Hut",
    "Gap Factory", "Banana Republic Factory", "Icebreaker Merino",
    "Mavi Jeans", "People's Jewellers", "Columbia Sportswear", "Vans",
    "Skechers", "Old Navy Outlet", "Jimmy Choo", "Club Monaco",
    "Cole Haan", "Tumi", "The Cosmetics Company Store",
]

TSAWWASSEN_MILLS_STORES = [
    "Bass Pro Shops", "Saks OFF 5TH", "DSW", "Forever 21", "H&M",
    "Marshalls", "Nike Factory Store", "Old Navy", "Sport Chek",
    "Tommy Hilfiger", "Urban Planet", "Winners", "American Eagle Outfitters",
    "Bath & Body Works", "The Children's Place", "Banana Republic",
    "Aritzia", "Michael Kors", "Kate Spade", "Browns Shoes", "Lululemon",
    "Coach Outlet", "Brooks Brothers", "Harry Rosen Outlet", "La Vie En Rose",
    "GNC", "Hollister", "Hot Topic", "Claire's", "Express Factory Outlet",
]

METROTOWN_STORES = [
    "Hudson's Bay", "Walmart", "Real Canadian Superstore", "Winners",
    "HomeSense", "T&T Supermarket", "Sport Chek", "H&M", "Victoria's Secret",
    "Indigo", "Sephora", "Shoppers Drug Mart", "Old Navy", "Zara", "Gap",
    "Apple", "Uniqlo", "Swarovski", "American Eagle Outfitters",
    "Lululemon", "JD Sports", "Foot Locker",
]


def scrape_mall_deals() -> list[dict]:
    logger.info("Starting day-to-day mall deals scrape...")
    deals: list[dict] = []

    deals.extend(_build_mall_deals(
        stores=MCARTHURGLEN_STORES,
        mall_name="McArthurGlen Vancouver",
        source_id_prefix="mall_mcarthurglen",
        coords=MCARTHURGLEN_COORDS,
        city="Richmond",
    ))
    deals.extend(_build_mall_deals(
        stores=TSAWWASSEN_MILLS_STORES,
        mall_name="Tsawwassen Mills",
        source_id_prefix="mall_tsawwassen_mills",
        coords=TSAWWASSEN_MILLS_COORDS,
        city="Delta",
    ))
    deals.extend(_build_mall_deals(
        stores=METROTOWN_STORES,
        mall_name="Metropolis at Metrotown",
        source_id_prefix="mall_metrotown",
        coords=METROTOWN_COORDS,
        city="Burnaby",
    ))

    logger.info(f"Mall scrape complete — {len(deals)} deals.")
    return deals


def _build_mall_deals(
    stores: list[str], mall_name: str, source_id_prefix: str, coords: tuple[float, float],
    city: str,
) -> list[dict]:
    lat, lng = coords
    # Ongoing listings, refreshed each 6h cycle like the rest of Retail —
    # a short rolling expiry keeps them current rather than seasonal.
    expires_at = datetime.now(timezone.utc) + timedelta(days=3)
    result = []

    for store in stores:
        result.append({
            "source": "curated",
            "source_id": f"{source_id_prefix}_{_slugify(store)}",
            "title": f"{store} at {mall_name}",
            "storeName": store,
            "category": "Mall Directory",
            "mall": mall_name,
            "city": city,
            "price": 0.0,
            "latitude": lat,
            "longitude": lng,
            "description": f"{store} at {mall_name}. Check in-store for current promotions and offers.",
            "imageUrl": None,
            "isHot": False,
            "expires_at": expires_at,
            "scraped_at": datetime.now(timezone.utc),
        })

    return result


def _slugify(text: str) -> str:
    import re
    slug = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
    return slug or "store"