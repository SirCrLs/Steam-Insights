from sync_data import sync_games, sync_users, logger
from dotenv import load_dotenv
from db import get_connection
import os

""" VARIABLES """

MAX_PAGE = 3  # SteamSpy: each page is 1000 games
SEED_FILE = "seed_steam_ids.txt"

def main():
    load_dotenv()
    api_key = os.environ["STEAM_API_KEY"]
    conn = get_connection()

    try:
        print("\n=== 1. Syncing games catalog ===")
        sync_games(conn, api_key, MAX_PAGE)

        print("\n=== 2. Syncing users ===")
        sync_users(conn, api_key, SEED_FILE)

    except Exception as e:
        conn.rollback()
        logger.error(f"ETL failed: {e}")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()