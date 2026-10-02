import logging
from fastapi import APIRouter, HTTPException, BackgroundTasks
from app.services.scheduler import (
    run_all_scrapers,
    run_single_scraper,
    get_status,
    start_scheduler,
)
from app.services.deals_service import load_deals

logger = logging.getLogger(__name__)
router = APIRouter()

VALID_SCRAPERS = {"grocery", "gas", "restaurant"}


@router.get("/health")
def health():
    return {"status": "ok"}


@router.get("/status")
def status():
    return get_status()


@router.post("/scrape")
def trigger_full_scrape(background_tasks: BackgroundTasks):
    background_tasks.add_task(_run_and_log, "all")
    return {"message": "Full scrape started in background."}


@router.post("/scrape/{scraper_name}")
def trigger_single_scrape(scraper_name: str, background_tasks: BackgroundTasks):
    if scraper_name not in VALID_SCRAPERS:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown scraper '{scraper_name}'. Valid options: {sorted(VALID_SCRAPERS)}",
        )
    background_tasks.add_task(_run_and_log, scraper_name)
    return {"message": f"'{scraper_name}' scrape started in background."}


@router.get("/deals")
def get_deals():
    try:
        deals = load_deals()
        return {"count": len(deals), "deals": deals}
    except ValueError as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/scheduler/start")
def scheduler_start():
    start_scheduler()
    return {"message": "Scheduler started."}


def _run_and_log(scraper: str):
    try:
        if scraper == "all":
            summary = run_all_scrapers()
        else:
            summary = run_single_scraper(scraper)
        logger.info(f"Background scrape '{scraper}' complete: {summary}")
    except Exception as e:
        logger.error(f"Background scrape '{scraper}' failed: {e}")