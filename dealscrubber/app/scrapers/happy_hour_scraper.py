import logging
import re
import httpx
from bs4 import BeautifulSoup
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin
from app.core.config import REQUEST_HEADERS, VANCOUVER_LAT, VANCOUVER_LNG

logger = logging.getLogger(__name__)

BASE_URL = "https://happyhourvancouver.ca/daily-specials/{day}"
DAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

# Fallback only — used if a venue's own page can't be reached or doesn't
# have a "Get Directions" coordinate embedded. Real per-venue coordinates
# (see _get_venue_coords below) are used whenever available, since a
# neighbourhood centroid can be well off from the venue's actual address.
NEIGHBOURHOOD_COORDS = {
    "kitsilano": (49.2673, -123.1547),
    "mount pleasant": (49.2620, -123.1000),
    "west end": (49.2860, -123.1350),
    "gastown": (49.2833, -123.1088),
    "yaletown": (49.2734, -123.1216),
    "commercial drive": (49.2620, -123.0700),
    "granville": (49.2789, -123.1310),
    "central": (49.2827, -123.1207),
    "chinatown": (49.2799, -123.1004),
    "stadium": (49.2768, -123.1093),
    "coal harbour": (49.2900, -123.1210),
    "false creek": (49.2730, -123.1150),
    "downtown": (49.2827, -123.1207),
}

# Cache of venue page URL -> (lat, lng), shared across the whole scrape run
# so a venue open multiple days only gets its own page fetched once.
_venue_coord_cache: dict[str, tuple[float, float] | None] = {}


def _slugify(text: str) -> str:
    # Firestore document IDs can't contain "/" (or be "." or ".."), so
    # venue names with slashes or other odd punctuation need sanitizing
    # before being used to build a source_id.
    slug = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
    return slug or "venue"


def scrape_happy_hour_deals() -> list[dict]:
    logger.info("Starting Happy Hour Vancouver scrape...")
    deals: list[dict] = []
    _venue_coord_cache.clear()

    for day in DAYS:
        try:
            day_deals = _scrape_day(day)
            deals.extend(day_deals)
            logger.info(f"Happy Hour {day}: {len(day_deals)} venues")
        except Exception as e:
            logger.warning(f"Happy Hour scrape failed for {day}: {e}")

    logger.info(f"Happy Hour scrape complete — {len(deals)} deals total.")
    return deals


def _scrape_day(day: str) -> list[dict]:
    url = BASE_URL.format(day=day)
    # Recurring weekly specials — keep alive well past the next scheduled
    # scrape (every 6h) so they don't vanish between refreshes.
    expires_at = datetime.now(timezone.utc) + timedelta(days=8)

    with httpx.Client(headers=REQUEST_HEADERS, timeout=15, follow_redirects=True) as client:
        resp = client.get(url)
        resp.raise_for_status()

    soup = BeautifulSoup(resp.text, "html.parser")
    deals = []

    for h3 in soup.find_all("h3"):
        link = h3.find("a")
        if not link or not link.text.strip():
            continue
        venue_name = link.text.strip()
        venue_href = link.get("href")

        if "not quite right" in venue_name.lower():
            continue  # skip the feedback footer heading

        neighbourhood = "Vancouver"
        specials: list[str] = []

        for sibling in h3.find_next_siblings():
            if sibling.name == "h3":
                break
            if sibling.name in ("p", "div"):
                text = sibling.get_text(strip=True)
                if text.endswith("/"):
                    neighbourhood = text.rstrip("/").strip()
            if sibling.name == "ul":
                specials = [
                    li.get_text(strip=True)
                    for li in sibling.find_all("li")
                    if li.get_text(strip=True)
                ]

        if not specials or specials in (["None"], ["-"]):
            continue

        price = _min_price(specials)
        if price <= 0:
            continue  # no priced special found — skip rather than show $0.00

        # Real venue-specific coordinate from the venue's own page, when
        # reachable — falls back to the neighbourhood centroid otherwise.
        coords = _get_venue_coords(venue_href) if venue_href else None
        if coords is None:
            coords = NEIGHBOURHOOD_COORDS.get(
                neighbourhood.lower(), (VANCOUVER_LAT, VANCOUVER_LNG)
            )
        lat, lng = coords

        deals.append({
            "source": "happyhourvancouver",
            "source_id": f"hhv_{_slugify(venue_name)}_{day}",
            "title": f"{venue_name} — {day.capitalize()} Happy Hour",
            "storeName": venue_name,
            "category": "Happy Hour",
            "city": "Vancouver",
            "price": price,
            "latitude": lat,
            "longitude": lng,
            "description": " • ".join(specials)[:300],
            "imageUrl": None,
            "isHot": 0 < price < 8.0,
            "day": day.capitalize(),
            "neighbourhood": neighbourhood,
            "expires_at": expires_at,
            "scraped_at": datetime.now(timezone.utc),
        })

    return deals


def _get_venue_coords(venue_href: str) -> tuple[float, float] | None:
    """Fetches a venue's own page and extracts the real coordinate embedded
    in its 'Get Directions' link (a Google Maps URL with a destination
    lat/lng), rather than relying on the neighbourhood-level fallback.
    Cached per venue URL for the duration of one scrape run.
    """
    venue_url = urljoin("https://happyhourvancouver.ca/", venue_href)

    if venue_url in _venue_coord_cache:
        return _venue_coord_cache[venue_url]

    coords = None
    try:
        with httpx.Client(headers=REQUEST_HEADERS, timeout=10, follow_redirects=True) as client:
            resp = client.get(venue_url)
            resp.raise_for_status()

        match = re.search(
            r"destination=(-?\d+\.\d+)%2C(-?\d+\.\d+)", resp.text
        )
        if not match:
            # Some pages may have the URL unescaped instead of percent-encoded.
            match = re.search(
                r"destination=(-?\d+\.\d+),\s*(-?\d+\.\d+)", resp.text
            )
        if match:
            coords = (float(match.group(1)), float(match.group(2)))
    except Exception as e:
        logger.warning(f"Could not fetch venue page {venue_url}: {e}")

    _venue_coord_cache[venue_url] = coords
    return coords


def _min_price(specials: list[str]) -> float:
    prices = []
    for s in specials:
        for match in re.findall(r"\$(\d+\.?\d*)", s):
            try:
                prices.append(float(match))
            except ValueError:
                pass
    return min(prices) if prices else 0.0