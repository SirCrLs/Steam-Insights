from sync_data import sync_games, sync_users, logger
from dotenv import load_dotenv
from loader import get_connection
import os

""" VARIABLES """

MAX_PAGE = 30  # SteamSpy: each page is 1000 games
MAX_USERS = 20000 # With games and achievements

FETCH_USER_ACHIEVEMENTS = False # user achievements are expensive to fetch

# amount of games/users is goint to load at once on the DB
GAMES_BATCH_SIZE = 100
USERS_BATCH_SIZE = 50

def main():
    load_dotenv()
    api_key = os.environ["STEAM_API_KEY"]
    conn = get_connection()

    try:
        logger.info(f"=== 1. Syncing games ===")
        sync_games(conn, api_key, MAX_PAGE, GAMES_BATCH_SIZE)

        logger.info(f"=== 2. Syncing users ===")
        sync_users(conn, api_key, MAX_USERS, USERS_BATCH_SIZE, FETCH_USER_ACHIEVEMENTS)

    except Exception as e:
        conn.rollback()
        logger.error(f"ETL failed: {e}")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()