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
    generate_steam_seed_ids
)
import logging
import glob
import json
import os
import loader

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

def load_games(max_page: int, output_folder: str = os.path.join("..", "data")):
    """
    Loads SteamSpy games by reading each page JSON file individually.
    """
    combined = {}
    missing_pages = []

    for page in range(max_page):
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

    game_stub_rows = transform_game_stubs(games_list)
    loader.upsert_game_stubs(conn, game_stub_rows)
    conn.commit()
    logger.info(f"{len(game_stub_rows)} games inserted/updated in the database.")
    save_checkpoint(MAX_PAGE)

    app_ids = loader.get_all_app_ids(conn)
    logger.info(f"Enriching {len(app_ids)} games with appdetails and achievements...")

    games_batch = []
    achievements_batch = []

    for i, app_id in enumerate(app_ids, start=1):
        try:
            # Details
            details = get_app_details(app_id)
            if details:
                game_row = transform_game_details(app_id, details)
                if game_row:
                    games_batch.append(game_row)

            # Scheme achievements
            achievements = get_synced_game_achievements(api_key, app_id)
            if achievements:
                achievement_rows = transform_achievements(app_id, achievements)
                if achievement_rows:
                    achievements_batch.extend(achievement_rows)

        except Exception as e:
            logger.warning(f"Error fetching data for app_id={app_id}: {e}")
            continue

        # Saving the batch
        if i % BATCH_SIZE == 0 or i == len(app_ids):
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

def sync_users(conn, api_key, MAX_USERS:int = 300, BATCH_SIZE: int = 100):
    """ USERS """
    SEED_FILE: str = os.path.join("..", "data", "seed_steam_ids.txt")

    steam_ids = generate_steam_seed_ids(api_key,MAX_USERS)

    if steam_ids == None:
        logger.error(f"SteamIDs could not be loaded from {SEED_FILE}.")
        return

    logger.info(f"{len(steam_ids)} SteamIDs loaded from {SEED_FILE}.")

    summaries = clean_summaries(api_key,steam_ids,MAX_USERS)
    logger.info(f"{len(summaries)} summaries loaded.")

    user_games_batch = []
    user_achievements_batch = []

    if summaries:
        user_rows = [transform_user(player) for player in summaries]
        loader.upsert_users_batch(conn, user_rows)
        logger.info(f"{len(user_rows)} users saved into the database.")
        conn.commit()

    for i, steam_id in enumerate(steam_ids, start=1):
        try:
            logger.info(f"Syncing user {steam_id} ({i}/{len(steam_ids)})...")

            # Owned games
            owned_response = get_owned_games(api_key, steam_id)
            raw_games = owned_response.get("response", {}).get("games", []) if owned_response else []
            
            if raw_games:
                user_games_rows = transform_owned_games(raw_games,steam_id)
                user_games_batch.extend(user_games_rows)

                game_ids = []
                for game in user_games_rows:
                    game_ids.append(game.get("appid"))

                # Achievements per owned game
                achievements = get_top_achievements(api_key, steam_id, game_ids)
                if achievements: 
                    ach_rows = transform_user_achievements(achievements, steam_id, game_ids)
                    user_achievements_batch.extend(ach_rows)

        except Exception as e:
            logger.warning(f"Error fetching API data for user {steam_id}: {e}")
            continue

        if i % BATCH_SIZE == 0 or i == len(steam_ids):
            try:
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
                user_games_batch.clear()
                user_achievements_batch.clear()

    logger.info("Users sync completed.")

