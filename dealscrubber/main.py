import logging
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.api.routes import router
from app.services.scheduler import start_scheduler
from app.core.config import LOG_FILE

# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
    ],
)
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# App lifecycle: start scheduler on startup
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("DealScrubber starting up...")
    start_scheduler()          # kick off background scraping immediately
    yield
    logger.info("DealScrubber shutting down.")


app = FastAPI(
    title="DealScrubber API",
    version="1.0.0",
    description=(
        "Scrapes live deals from grocery flyers, gas stations, and restaurants "
        "in Vancouver and writes them to Firestore for the DealDive app."
    ),
    lifespan=lifespan,
)

app.include_router(router)