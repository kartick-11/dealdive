"""
One-time cleanup script: deletes every document in the Firestore 'deals'
collection so the next backend restart repopulates everything fresh, with
no orphaned documents left over from earlier scraper versions today.

Run this ONCE from the dealscrubber folder, with the backend NOT running
(so nothing is writing while you delete):

    python clear_deals.py

After it finishes, start the backend normally:

    uvicorn main:app --reload
"""

import firebase_admin
from firebase_admin import credentials, firestore
from app.core.config import FIREBASE_CREDENTIALS

BATCH_SIZE = 400  # stay under Firestore's 500-write batch limit


def main():
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CREDENTIALS)
        firebase_admin.initialize_app(cred)

    db = firestore.client()
    deals_ref = db.collection("deals")

    total_deleted = 0

    while True:
        docs = list(deals_ref.limit(BATCH_SIZE).stream())
        if not docs:
            break

        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
        batch.commit()

        total_deleted += len(docs)
        print(f"Deleted {total_deleted} documents so far...")

    print(f"Done. Deleted {total_deleted} documents total from 'deals'.")
    print("Now run: uvicorn main:app --reload")


if __name__ == "__main__":
    main()
