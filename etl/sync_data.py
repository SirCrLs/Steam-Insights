from api.steam_api import (
    get_games_by_current_players,
    steamspy_get_all_games,
    get_appdetails,
    get_synced_game_achievements,
    get_player_summary,
    get_owned_games,
    get_player_achievements,
    transform_game_stubs,
    transform_game_details,
    transform_achievements,
    transform_user,
    transform_owned_games,
    transform_user_achievements
)
import logging
import os
import load as loader

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)



def sync_games(conn, api_key, MAX_PAGE):
    """ GAMES """

    # 1. Download game list JSON
    logger.info("Fetching currently most-played games...")
    current_players_games = get_games_by_current_players(api_key)

    logger.info(f"Fetching top {MAX_PAGE * 1000} games from SteamSpy...")
    steamspy_games = steamspy_get_all_games(MAX_PAGE)

    combined = {}
    for game in steamspy_games + current_players_games:
        app_id = game["appid"]
        if app_id not in combined:
            combined[app_id] = game

    games_list = list(combined.values())
    logger.info(f"{len(games_list)} unique games after merging both sources.")

    # 2. Insert game list into the database (app_id + name)
    game_stub_rows = transform_game_stubs(games_list)
    loader.upsert_game_stubs(conn, game_stub_rows)
    conn.commit()
    logger.info(f"{len(game_stub_rows)} games inserted/updated in the database.")

    # 3. For each game already in the database, enrich with details + achievements
    app_ids = loader.get_all_app_ids(conn)
    logger.info(f"Enriching {len(app_ids)} games with appdetails and achievements...")

    for app_id in app_ids:
        try:
            # appdetails
            details = get_appdetails(app_id)
            if details:
                loader.save_raw_response(conn, "appdetails", {"appids": app_id}, details)
                game_row = transform_game_details(app_id, details)
                loader.upsert_game(conn, game_row)

            # achievement schema
            achievements = get_synced_game_achievements(api_key,app_id)
            if achievements:
                achievement_rows = transform_achievements(app_id, achievements)
                loader.upsert_achievements(conn, achievement_rows)

        except Exception as e:
            logger.warning(f"Error enriching app_id={app_id}: {e}")
            continue

    conn.commit()
    logger.info("Games sync completed.")


def sync_users(conn, api_key, SEED_FILE):
    """ USERS """

    # 1. Get seed SteamIDs from a .txt file
    if not os.path.exists(SEED_FILE):
        logger.warning(f"{SEED_FILE} not found, skipping user sync.")
        return

    with open(SEED_FILE, "r") as f:
        steam_ids = [line.strip() for line in f if line.strip()]

    logger.info(f"{len(steam_ids)} SteamIDs loaded from {SEED_FILE}.")

    valid_app_ids = loader.get_all_app_ids(conn)

    for steam_id in steam_ids:
        try:
            logger.info(f"Syncing user {steam_id}...")

            # a. Profile
            raw_summary = get_player_summary(api_key, steam_id)
            loader.save_raw_response(conn, "GetPlayerSummaries", {"steamid": steam_id}, raw_summary)

            players = raw_summary.get("response", {}).get("players", [])
            if not players:
                logger.warning(f"No profile found for {steam_id}, skipping.")
                continue

            user_row = transform_user(raw_summary)
            loader.upsert_user(conn, user_row)

            # b. Owned games (skip games not in db)
            raw_games = get_owned_games(api_key, steam_id)
            loader.save_raw_response(conn, "GetOwnedGames", {"steamid": steam_id}, raw_games)

            user_games_rows = transform_owned_games(raw_games, valid_app_ids)
            loader.upsert_user_games(conn, steam_id, user_games_rows)
            logger.info(f"{len(user_games_rows)} games kept for user {steam_id}.")

            # c. Achievements per owned game
            for game in user_games_rows:
                app_id = game["app_id"]
                try:
                    raw_ach = get_player_achievements(api_key, steam_id, app_id)
                    loader.save_raw_response(conn, "GetPlayerAchievements", {"appid": app_id}, raw_ach)

                    ach_rows = transform_user_achievements(raw_ach, steam_id, app_id)
                    loader.upsert_user_achievements(conn, ach_rows)

                except Exception as e:
                    logger.debug(f"No achievements for user={steam_id}, app_id={app_id}: {e}")
                    continue

            conn.commit()

        except Exception as e:
            conn.rollback()
            logger.error(f"Error syncing user {steam_id}: {e}")
            continue

    logger.info("Users sync completed.")

