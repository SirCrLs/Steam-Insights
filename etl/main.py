from sync_data import sync_games, sync_users, logger
from dotenv import load_dotenv
from loader import get_connection
import os
import time

""" VARIABLES """

MAX_PAGE = 55  # SteamSpy: each page is 1000 games
MAX_USERS = 30000 # With games and achievements

FETCH_USER_ACHIEVEMENTS = False # user achievements are expensive to fetch

# amount of games/users is goint to load at once on the DB
GAMES_BATCH_SIZE = 100
USERS_BATCH_SIZE = 50

# Refresh the materialized views used by the EDA dashboard once the load ends
REFRESH_EDA_VIEWS = True


def refresh_eda_views(conn):
    """Runs eda_refresh_levels() (defined in eda/sql/002_levels.sql).

    Non-fatal: the data is already loaded, so a failed refresh
    is logged but does not mark the whole ETL as failed.
    """
    start = time.perf_counter()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT eda_refresh_levels();")
        conn.commit()
        logger.info(f"EDA views refreshed in {time.perf_counter() - start:.1f}s")
    except Exception as e:
        conn.rollback()
        logger.error(
            f"EDA views refresh failed: {e}. "
            "Was eda/sql/002_levels.sql executed? "
            "You can retry manually with: SELECT eda_refresh_levels();"
        )


def main():
    load_dotenv()
    api_key = os.environ["STEAM_API_KEY"]
    conn = get_connection()

    try:

        logger.info(f"=== 1. Syncing users ===")
        sync_users(conn, api_key, MAX_USERS, USERS_BATCH_SIZE, FETCH_USER_ACHIEVEMENTS)

        logger.info(f"=== 2. Syncing games ===")
        sync_games(conn, api_key, MAX_PAGE, GAMES_BATCH_SIZE)

        if REFRESH_EDA_VIEWS:
            logger.info(f"=== 3. Refreshing EDA views ===")
            refresh_eda_views(conn)

    except Exception as e:
        conn.rollback()
        logger.error(f"ETL failed: {e}")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()