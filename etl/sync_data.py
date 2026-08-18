from api.steam_api import get_user_achievements
from api.steam_api import clean_summaries
from api.steam_api import (
    steamspy_download_all_pages_resumable,
    get_app_details,
    get_synced_game_achievements,
    clean_summaries,
    get_owned_games,
    get_top_achievements,
    transform_game_stubs,
    transform_game_details,
    transform_achievements,
    transform_user,
    transform_owned_games,
    transform_user_achievements,
    save_checkpoint,
    read_checkpoint,
    generate_steam_seed_ids,
    fetch_user_achievements_concurrently,
    update_live_status
)
from sys import stdout
import logging
import glob
import json
import os
import time
import loader
import asyncio

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

def load_games(max_page: int, output_folder: str = "data"):
    """
    Loads SteamSpy games by reading each page JSON file individually.
    """
    checkpoint = read_checkpoint()
    if checkpoint >= max_page:
        logger.info(f"Checkpoint already meeted: checkpoint on page {checkpoint}")
        return None

    combined = {}
    missing_pages = []
    start_page = (checkpoint) if checkpoint > -1 else 0

    for page in range(start_page, max_page):
        matches = glob.glob(os.path.join(output_folder, f"page_{page}.json"))

        if not matches:
            missing_pages.append(page)
            continue

        try:
            with open(matches[0], "r", encoding="utf-8") as file:
                page_data = json.load(file)
        except (FileNotFoundError, json.JSONDecodeError) as file_error:
            logger.error(f"Could not read page {page} ({matches[0]}): {file_error}")
            missing_pages.append(page)
            continue

        for app_id, game in page_data.items():
            if app_id not in combined:
                combined[app_id] = game

        logger.info(f"Loaded page {page} from {matches[0]} ({len(page_data)} games).")

    if missing_pages:
        logger.info(f"Missing pages {missing_pages}, fetching from SteamSpy...")
        try:
            steamspy_download_all_pages_resumable(max_page, output_folder)
        except Exception as api_error:
            logger.error(f"Live API fetch failed: {api_error}")
            return None

        # Re-attempt loading only the pages that were missing
        for page in missing_pages:
            matches = glob.glob(os.path.join(output_folder, f"page_{page}.json"))
            if not matches:
                logger.error(f"Page {page} still missing after download attempt.")
                continue
            with open(matches[0], "r", encoding="utf-8") as file:
                page_data = json.load(file)
            for app_id, game in page_data.items():
                if app_id not in combined:
                    combined[app_id] = game

    games_list = list(combined.values())
    logger.info(f"{len(games_list)} games loaded from SteamSpy.")
    return games_list  

def load_user_games_and_achievements(conn, api_key, steam_id):
    """Loads and transform user games and achievements"""
    logger.info(f"Syncing user {steam_id}...")

    # b. Owned games 
    games = get_owned_games(api_key, steam_id).get("response").get("games")

    user_games_rows = transform_owned_games(games, steam_id)
    loader.upsert_user_games(conn, steam_id, user_games_rows)
    logger.info(f"{len(user_games_rows)} games kept for user {steam_id}.")

    # c. Achievements per owned game
    for game in user_games_rows:
        app_id = game["app_id"]
        try:
            raw_ach = get_top_achievements(api_key, steam_id, app_id)
            loader.save_raw_response(conn, "GetPlayerAchievements", {"appid": app_id}, raw_ach)

            ach_rows = transform_user_achievements(raw_ach, steam_id, app_id)
            loader.upsert_user_achievements(conn, ach_rows)

        except Exception as e:
            logger.debug(f"No achievements for user={steam_id}, app_id={app_id}: {e}")
            continue

    conn.commit()

def sync_games(conn, api_key, MAX_PAGE : int, BATCH_SIZE: int = 100):
    """ GAMES """

    logger.info("Fetching games...")
    games_list = load_games(MAX_PAGE)

    if games_list:
        game_stub_rows = transform_game_stubs(games_list)
        loader.upsert_game_stubs(conn, game_stub_rows)
        conn.commit()
        logger.info(f"{len(game_stub_rows)} games inserted/updated in the database.")
        save_checkpoint(MAX_PAGE)

    app_ids = loader.get_all_app_ids_null(conn)
    max_games = len(app_ids)
    if max_games == 0:
        logger.info(f"No games left to update: ")
        return
    logger.info(f"Enriching {max_games} games with appdetails and achievements...")

    games_batch = []
    achievements_batch = []

    for i, app_id in enumerate(app_ids, start=1):
        try:
            update_live_status(i, max_games, app_id, "games")
            # Details
            details = get_app_details(app_id)
            game_row = transform_game_details(app_id, details)
            games_batch.append(game_row)

            # Scheme achievements
            achievements = get_synced_game_achievements(api_key, app_id)
            if achievements:
                achievement_rows = transform_achievements(app_id, achievements)
                if achievement_rows:
                    achievements_batch.extend(achievement_rows)
            
        except Exception as e:
            print("\r\033[K", end="")
            logger.warning(f"Error fetching data for app_id={app_id}: {e}")
            continue

        time.sleep(2)
        
        # Saving the batch
        if i % BATCH_SIZE == 0 or i == len(app_ids):
            print("\r\033[K", end="")
            try:
                if games_batch:
                    loader.upsert_games_batch(conn, games_batch)
                    
                if achievements_batch:
                    loader.upsert_achievements_batch(conn, achievements_batch)

                conn.commit()
                logger.info(f"Batch saved: {i}/{len(app_ids)} games processed.")

                # Limpiamos las listas para el siguiente lote
                games_batch.clear()
                achievements_batch.clear()

            except Exception as e:
                conn.rollback()
                logger.error(f"Error saving batch at index {i}: {e}")
                games_batch.clear()
                achievements_batch.clear()

    logger.info("Games sync completed.")

def fetch_and_transform_all_achievements(api_key, steam_id, game_ids):
    try:
        user_achievements_batch = asyncio.run(fetch_user_achievements_concurrently(api_key, steam_id, game_ids))
        return user_achievements_batch
    except Exception as e:
        logger.error(f"Error fetching achievements concurrently for user {steam_id}: {e}")
        return []

def verify_users(conn, api_key, max_users: int, seed_file: str):
    # Gets users where games_fetched = FALSE
    with conn.cursor() as cur:
        cur.execute("""
            SELECT steam_id FROM users WHERE games_fetched IS NULL LIMIT %s;
        """, (max_users,))
        db_steam_ids = [row[0] for row in cur.fetchall()]

    logger.info(f"{len(db_steam_ids)} users fetched from DB.")
    steam_ids = list(db_steam_ids)

    # this if db_steam_ids is not enough to reach mas_users
    if len(steam_ids) < max_users:
        needed = max_users - len(steam_ids)
        logger.info(f"Fetching {needed} users from .txt")

        with conn.cursor() as cur:
            cur.execute("SELECT steam_id FROM users;")
            existing_db_ids = set(row[0] for row in cur.fetchall())

        seed_ids = generate_steam_seed_ids(api_key, max_users, seed_file)

        if seed_ids is None:
            logger.error(f"SteamIDs could not be loaded from {seed_file}.")
        else:
            current_set = set(steam_ids)
            new_ids = [sid for sid in seed_ids if sid not in existing_db_ids and sid not in current_set]
            
            steam_ids.extend(new_ids[:needed])

    return steam_ids

def sync_users(conn, api_key, MAX_USERS:int = 300, BATCH_SIZE: int = 100):
    """ USERS """
    SEED_FILE: str = os.path.join("data/seed_steam_ids.txt")

    steam_ids = verify_users(conn, api_key, MAX_USERS, SEED_FILE)

    if not steam_ids:
        logger.warning("No SteamIDs to process.")
        return

    logger.info(f"{len(steam_ids)} SteamIDs loaded to sync.")

    summaries = clean_summaries(api_key, steam_ids, MAX_USERS)
    logger.info(f"{len(summaries)} summaries loaded.")

    user_games_batch = []
    user_achievements_batch = []
    users_status_batch = []

    if summaries:
        user_rows = [transform_user(player) for player in summaries]
        loader.upsert_users_batch(conn, user_rows)
        logger.info(f"{len(user_rows)} users saved into the database.")
        conn.commit()

    for i, steam_id in enumerate(steam_ids, start=1):

        if i % BATCH_SIZE == 0 or i == len(steam_ids):
            print("\r\033[K", end="")
            try:
                if users_status_batch:
                    loader.update_users_status_batch(conn, users_status_batch)

                if user_games_batch:
                    loader.upsert_user_games_batch(conn, user_games_batch)

                if user_achievements_batch:
                    loader.upsert_user_achievements_batch(conn, user_achievements_batch)

                conn.commit()
                logger.info(f"Batch saved successfully at index {i}/{len(steam_ids)}.")

            except Exception as e:
                conn.rollback()
                logger.error(f"Error saving batch at index {i}: {e}. Attempting individual fallback...")
            finally:
                users_status_batch.clear()
                user_games_batch.clear()
                user_achievements_batch.clear()

        time.sleep(1)

        has_public_games = False
        has_public_achievements = False

        try:
            update_live_status(i, len(steam_ids), steam_id, "users")

            owned_response = get_owned_games(api_key, steam_id)
            games_data = owned_response.get("response", {})

            if "games" not in games_data:
                time.sleep(1)
                print("\r\033[K", end="")
                logger.warning(f"User {i}: {steam_id} has no public games or games section is private...")
                
                users_status_batch.append({
                    "steam_id": steam_id,
                    "has_public_games": False,
                    "has_public_achievements": False,
                    "games_fetched": True 
                })
                continue

            raw_games = games_data.get("games", [])
            has_public_games = True

            if raw_games:
                user_games_rows = transform_owned_games(raw_games, steam_id)
                user_games_batch.extend(user_games_rows)

                game_ids = [
                    game.get("app_id") for game in user_games_rows 
                    if game.get("playtime_forever", 0) != 0
                ]

                # Achievements per owned game
                user_achievements = fetch_and_transform_all_achievements(api_key, steam_id, game_ids)
                
                if user_achievements:
                    has_public_achievements = True
                    user_achievements_batch.extend(user_achievements)

            users_status_batch.append({
                "steam_id": steam_id,
                "has_public_games": has_public_games,
                "has_public_achievements": has_public_achievements,
                "games_fetched": True
            })

        except Exception as e:
            print("\r\033[K", end="")
            logger.warning(f"Error fetching API data for user {steam_id}: {e}")
            continue

    logger.info("Users sync completed.")

