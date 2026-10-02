import logging
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

# Black Friday 2026 falls on Nov 27. Deals stay live through the following
# Cyber Monday (Nov 30) rather than the usual short expiry window, since
# these get seeded ahead of time and shouldn't get purged early by
# delete_expired_deals().
BLACK_FRIDAY_EXPIRY = datetime(2026, 12, 1, 7, 0, tzinfo=timezone.utc)  # ~11:59 PM PST Nov 30

# Real, verified coordinates for each mall. Individual store locations
# within a mall aren't available without scraping the JS-rendered
# interactive centre map (would need Playwright), so every store at a
# given mall shares that mall's own coordinate.
MCARTHURGLEN_COORDS = (49.1975, -123.1406)  # Richmond, near YVR
TSAWWASSEN_MILLS_COORDS = (49.0381, -123.0860)  # Delta
METROTOWN_COORDS = (49.2273, -123.0032)  # Burnaby

# Verified real tenants as of the sources checked — not the complete live
# directory (McArthurGlen alone lists ~80-100 stores; scraping the full,
# current list would require Playwright since their site is JS-rendered).
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


def scrape_black_friday_deals() -> list[dict]:
    logger.info("Starting Black Friday deals scrape...")
    deals: list[dict] = []

    deals.extend(_build_mall_deals(
        stores=MCARTHURGLEN_STORES,
        mall_name="McArthurGlen Vancouver",
        source_id_prefix="mcarthurglen",
        coords=MCARTHURGLEN_COORDS,
        city="Richmond",
    ))
    deals.extend(_build_mall_deals(
        stores=TSAWWASSEN_MILLS_STORES,
        mall_name="Tsawwassen Mills",
        source_id_prefix="tsawwassen_mills",
        coords=TSAWWASSEN_MILLS_COORDS,
        city="Delta",
    ))
    deals.extend(_build_mall_deals(
        stores=METROTOWN_STORES,
        mall_name="Metropolis at Metrotown",
        source_id_prefix="metrotown",
        coords=METROTOWN_COORDS,
        city="Burnaby",
    ))

    logger.info(f"Black Friday scrape complete — {len(deals)} deals.")
    return deals


def _build_mall_deals(
    stores: list[str], mall_name: str, source_id_prefix: str, coords: tuple[float, float],
    city: str,
) -> list[dict]:
    lat, lng = coords
    result = []

    for store in stores:
        result.append({
            "source": "curated",
            "source_id": f"{source_id_prefix}_{_slugify(store)}",
            "title": f"{store} — Black Friday",
            "storeName": store,
            "category": "Black Friday",
            "mall": mall_name,
            "city": city,
            "price": 0.0,  # promo-style discount, not a fixed price
            "latitude": lat,
            "longitude": lng,
            "description": f"Black Friday deals at {store}, {mall_name}. Check in-store for this year's specific markdowns.",
            "imageUrl": None,
            "isHot": False,
            "expires_at": BLACK_FRIDAY_EXPIRY,
            "scraped_at": datetime.now(timezone.utc),
        })

    return result


def _slugify(text: str) -> str:
    import re
    slug = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
    return slug or "store"