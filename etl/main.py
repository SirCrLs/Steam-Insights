from sync_data import sync_games, sync_users, logger
from dotenv import load_dotenv
from db import get_connection
import os

""" VARIABLES """

MAX_PAGE = 1  # SteamSpy: each page is 1000 games
MAX_USERS = 100
BATCH_SIZE = 100

def main():
    load_dotenv()
    api_key = os.environ["STEAM_API_KEY"]
    conn = get_connection()

    try:
        logger.info(f"=== 1. Syncing games ===")
        sync_games(conn, api_key, MAX_PAGE, BATCH_SIZE)

        logger.info(f"=== 2. Syncing users ===")
        sync_users(conn, api_key, MAX_USERS, BATCH_SIZE)

    except Exception as e:
        conn.rollback()
        logger.error(f"ETL failed: {e}")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()