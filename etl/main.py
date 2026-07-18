import logging
import os
from dotenv import load_dotenv

from db import get_connection
import extract, transform, load as loader
from jobs import sync_catalog, sync_user_data

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)


def main():
    load_dotenv()
    api_key = os.environ["STEAM_API_KEY"]
    conn = get_connection()

    try:
        print("\n 1. synchronizing catalog data from steam")
        sync_catalog.run(conn, loader, transform, max_games=500)

        print("\n 2. synchronizing user data")
        sync_user_data.run(conn, extract, transform, loader, api_key)

    except Exception as e:
        conn.rollback()
        logger.error(f"ETL failed: {e}")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()