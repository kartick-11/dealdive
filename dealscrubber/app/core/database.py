import logging
from typing import Optional
import firebase_admin
from firebase_admin import credentials, firestore
from app.core.config import FIREBASE_CREDENTIALS

logger = logging.getLogger(__name__)

_db: Optional[firestore.Client] = None


def get_db() -> firestore.Client:
    global _db
    if _db is None:
        _db = _init_firebase()
    return _db


def _init_firebase() -> firestore.Client:
    if not firebase_admin._apps:
        try:
            cred = credentials.Certificate(FIREBASE_CREDENTIALS)
            firebase_admin.initialize_app(cred)
            logger.info("Firebase initialised.")
        except Exception as e:
            logger.error(f"Failed to initialise Firebase: {e}")
            raise
    return firestore.client()


def batch_upsert_deals(deals: list[dict]) -> int:
    if not deals:
        return 0

    db = get_db()
    total = 0
    chunk_size = 499

    for i in range(0, len(deals), chunk_size):
        chunk = deals[i : i + chunk_size]
        batch = db.batch()
        for deal in chunk:
            doc_id = deal.get("source_id") or deal.get("title", "unknown").replace(" ", "_")
            ref = db.collection("deals").document(doc_id)
            batch.set(ref, deal, merge=True)
        batch.commit()
        total += len(chunk)
        logger.info(f"Batch committed {len(chunk)} deals.")

    return total


def delete_expired_deals() -> int:
    from datetime import datetime, timezone

    db = get_db()
    now = datetime.now(timezone.utc)
    expired = (
        db.collection("deals")
        .where("expires_at", "<", now)
        .stream()
    )

    batch = db.batch()
    count = 0
    for doc in expired:
        batch.delete(doc.reference)
        count += 1
        if count % 499 == 0:
            batch.commit()
            batch = db.batch()

    if count % 499 != 0:
        batch.commit()

    logger.info(f"Deleted {count} expired deals.")
    return count