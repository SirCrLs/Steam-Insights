from sync_data import sync_games, sync_users, logger
from dotenv import load_dotenv
from loader import get_connection
import os

""" VARIABLES """

MAX_PAGE = 4  # SteamSpy: each page is 1000 games
MAX_USERS = 50
# amount of games/users is goint to load at once on the DB
GAMES_BATCH_SIZE = 10 
USERS_BATCH_SIZE = 10

def main():
    load_dotenv()
    api_key = os.environ["STEAM_API_KEY"]
    conn = get_connection()

    try:
        logger.info(f"=== 1. Syncing games ===")
        sync_games(conn, api_key, MAX_PAGE, GAMES_BATCH_SIZE)

        logger.info(f"=== 2. Syncing users ===")
        sync_users(conn, api_key, MAX_USERS, USERS_BATCH_SIZE)

    except Exception as e:
        conn.rollback()
        logger.error(f"ETL failed: {e}")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()