import logging
import threading
import time
from datetime import datetime, timezone
from app.core.config import SCRAPE_INTERVAL_HOURS
from app.core.database import batch_upsert_deals, delete_expired_deals
from app.scrapers.grocery_scraper import scrape_grocery_deals
from app.scrapers.gas_scraper import scrape_gas_deals
from app.scrapers.restaurant_scraper import scrape_restaurant_deals
from app.scrapers.black_friday_scraper import scrape_black_friday_deals
from app.scrapers.happy_hour_scraper import scrape_happy_hour_deals
from app.scrapers.retail_scraper import scrape_retail_deals
from app.scrapers.mall_scraper import scrape_mall_deals
from app.scrapers.fast_food_scraper import scrape_fast_food_deals
from app.scrapers.student_scraper import scrape_student_deals

logger = logging.getLogger(__name__)

_scheduler_thread: threading.Thread | None = None
_stop_event = threading.Event()

_last_run: dict[str, datetime | None] = {
    "grocery": None,
    "gas": None,
    "restaurant": None,
    "black_friday": None,
    "happy_hour": None,
    "retail": None,
    "mall": None,
    "fast_food": None,
    "student": None,
}


def run_all_scrapers() -> dict:
    summary = {}
    scrapers = [
        ("grocery", scrape_grocery_deals),
        ("gas", scrape_gas_deals),
        ("restaurant", scrape_restaurant_deals),
        ("black_friday", scrape_black_friday_deals),
        ("happy_hour", scrape_happy_hour_deals),
        ("retail", scrape_retail_deals),
        ("mall", scrape_mall_deals),
        ("fast_food", scrape_fast_food_deals),
        ("student", scrape_student_deals),
    ]

    for name, scraper_fn in scrapers:
        try:
            logger.info(f"Running {name} scraper...")
            deals = scraper_fn()
            count = batch_upsert_deals(deals)
            _last_run[name] = datetime.now(timezone.utc)
            summary[name] = {"status": "ok", "deals_written": count}
            logger.info(f"{name}: wrote {count} deals.")
        except Exception as e:
            logger.error(f"{name} scraper error: {e}")
            summary[name] = {"status": "error", "error": str(e)}

    try:
        deleted = delete_expired_deals()
        summary["expired_deleted"] = deleted
    except Exception as e:
        logger.warning(f"Expired deal cleanup failed: {e}")
        summary["expired_deleted"] = 0

    return summary


def run_single_scraper(name: str) -> dict:
    scrapers = {
        "grocery": scrape_grocery_deals,
        "gas": scrape_gas_deals,
        "restaurant": scrape_restaurant_deals,
        "black_friday": scrape_black_friday_deals,
        "happy_hour": scrape_happy_hour_deals,
        "retail": scrape_retail_deals,
        "mall": scrape_mall_deals,
        "fast_food": scrape_fast_food_deals,
        "student": scrape_student_deals,
    }

    if name not in scrapers:
        return {"status": "error", "error": f"Unknown scraper: {name}"}

    try:
        deals = scrapers[name]()
        count = batch_upsert_deals(deals)
        _last_run[name] = datetime.now(timezone.utc)
        return {"status": "ok", "deals_written": count}
    except Exception as e:
        logger.error(f"{name} scraper error: {e}")
        return {"status": "error", "error": str(e)}


def get_status() -> dict:
    return {
        "running": _scheduler_thread is not None and _scheduler_thread.is_alive(),
        "interval_hours": SCRAPE_INTERVAL_HOURS,
        "last_run": {
            k: v.isoformat() if v else None
            for k, v in _last_run.items()
        },
    }


def start_scheduler():
    global _scheduler_thread, _stop_event

    if _scheduler_thread and _scheduler_thread.is_alive():
        logger.info("Scheduler already running.")
        return

    _stop_event.clear()
    _scheduler_thread = threading.Thread(
        target=_scheduler_loop,
        daemon=True,
        name="DealScrubberScheduler",
    )
    _scheduler_thread.start()
    logger.info(f"Scheduler started — runs every {SCRAPE_INTERVAL_HOURS}h.")


def stop_scheduler():
    _stop_event.set()
    logger.info("Scheduler stop signal sent.")


def _scheduler_loop():
    interval_seconds = SCRAPE_INTERVAL_HOURS * 3600

    while not _stop_event.is_set():
        logger.info("Scheduler: starting scrape run...")
        try:
            summary = run_all_scrapers()
            logger.info(f"Scheduler: run complete. Summary: {summary}")
        except Exception as e:
            logger.error(f"Scheduler: unexpected error: {e}")

        logger.info(f"Scheduler: sleeping for {SCRAPE_INTERVAL_HOURS}h...")
        _stop_event.wait(timeout=interval_seconds)