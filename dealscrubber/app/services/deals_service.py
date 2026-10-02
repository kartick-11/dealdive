import json
import logging
import os
from app.core.config import DATA_PATH

logger = logging.getLogger(__name__)


def load_deals() -> list[dict]:
    try:
        with open(DATA_PATH, "r", encoding="utf-8") as f:
            content = f.read().strip()
        if not content:
            return []
        return json.loads(content)
    except FileNotFoundError:
        logger.warning(f"deals.json not found at {DATA_PATH}. Returning empty list.")
        return []
    except json.JSONDecodeError:
        raise ValueError("Invalid JSON in deals.json")


def save_deals(deals: list[dict]) -> None:
    os.makedirs(os.path.dirname(DATA_PATH), exist_ok=True)
    with open(DATA_PATH, "w", encoding="utf-8") as f:
        json.dump(deals, f, indent=2, default=str)
    logger.info(f"Saved {len(deals)} deals to {DATA_PATH}")