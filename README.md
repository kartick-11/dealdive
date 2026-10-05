# DealDive

DealDive is a Flutter app that aggregates real, local deals around Metro Vancouver — groceries, gas, restaurants, happy hour, retail, electronics, fast food, student discounts, and Black Friday mall offers — pulled in automatically by a Python scraping service and shown on a live feed and map.

## How it's built

- **App** (`dealdive_clean_new/`) — Flutter, Firebase Auth, Cloud Firestore, Google Maps SDK
- **Backend** (`dealscrubber/`) — Python/FastAPI scraping service ("DealScrubber"), running on a 6-hour scrape cycle
- **Data** — Firestore, written by a set of category-specific scrapers that pull from public sources (RedFlagDeals forums, Flipp's public flyer API, happyhourvancouver.ca, mall tenant directories, and a few curated/verified discount lists)

## Features

- Live deal feed with category chips, city filter, and search
- Grocery supermarket filter (Save-On-Foods, Safeway, No Frills, Walmart, T&T, Costco and more), Happy Hour day filter, and Black Friday mall filter
- Map view with deal pins, "my location" and zoom controls
- Save deals to your account and view them later
- Light and dark themes with a one-tap toggle, including a dark map style
- Pull-to-refresh, loading skeletons, and friendly empty states

## Categories

| Category | Source |
| --- | --- |
| Grocery | Flipp public flyer API, by store and by product term |
| Gas | Canadians for Affordable Energy citywide price forecast (not per-station measured pricing) |
| Restaurant | Curated real Vancouver spots + Scout Magazine RSS |
| Happy Hour | happyhourvancouver.ca, scraped daily per venue |
| Retail / Electronics | Flipp public flyer API, by category and by merchant |
| Black Friday | McArthurGlen Vancouver, Tsawwassen Mills, Metropolis at Metrotown tenant lists |
| Mall Directory | Mall tenant listings (no real price, kept separate from priced Retail deals) |
| Fast Food | RedFlagDeals Food & Drink and Hot Deals forums |
| Student | Verified UBC and BCIT discount programs |

## Running it locally

**App:**
```
cd dealdive_clean_new
flutter pub get
flutter run
```

**Backend:**
```
cd dealscrubber
pip install -r requirements.txt
uvicorn main:app --reload
```

The backend needs a Firebase service-account key at `dealscrubber/firebase_credentials.json` (not included in this repo — see `.gitignore`).

## A note on data

Every deal shown is pulled from a real, named source — nothing is generated or filled in as a placeholder. A category showing fewer deals than others usually means the real sources for that category are genuinely thin that day, not that something is broken.

## Known limitations

- Some sources (certain mall tenants, a few fast-food chains) only expose real pricing through JavaScript-rendered pages, which the current scrapers can't reach yet.
- A handful of Retail/Electronics merchants fall back to an approximate city-center map location rather than their exact store address.
- The backend currently needs to be running continuously to keep data fresh; it isn't yet deployed to always-on hosting.
