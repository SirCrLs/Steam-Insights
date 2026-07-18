import logging
import os
import re

logger = logging.getLogger(__name__)


def prompt_steam_id():
    """
    Asks for SteamID64 to the user. Also accepts profile link.
    """
    raw_input_value = input(
        "Enter your SteamID64 or profile link: "
    ).strip()

    match = re.search(r"(\d{17})", raw_input_value)
    if match:
        return match.group(1)

    raise ValueError(
        "The SteamID could not be interpreted. It must be a 17-digit number."
        "(you can find it at steamcommunity.com/profiles/<your_id>)."
    )


def run(conn, extract, transform, load, api_key):
    steam_id = prompt_steam_id()
    logger.info(f"Synchronizing data for SteamID {steam_id}...")

    # --- Perfil ---
    raw_summary = extract.get_player_summary(api_key, steam_id)
    load.save_raw_response(conn, "GetPlayerSummaries", {"steamid": steam_id}, raw_summary)

    players = raw_summary.get("response", {}).get("players", [])
    if not players:
        raise ValueError("Profile not found. Verify that the SteamID is correct.")

    is_public = players[0].get("communityvisibilitystate") == 3
    if not is_public:
        logger.warning(
            "The profile is private. Only limited data can be obtained. "
        )

    user_row = transform.transform_user(raw_summary)
    load.upsert_user(conn, user_row)

    # --- Juegos poseídos ---
    raw_games = extract.get_owned_games(api_key, steam_id)
    load.save_raw_response(conn, "GetOwnedGames", {"steamid": steam_id}, raw_games)

    games_rows, user_games_rows = transform.transform_owned_games(raw_games)
    load.upsert_user_games(conn, steam_id, user_games_rows)

    logger.info(f"{len(user_games_rows)} Synced games.")

    # --- Logros por juego ---
    for game in user_games_rows:
        app_id = game["app_id"]
        try:
            raw_ach = extract.get_player_achievements(api_key, steam_id, app_id)
            load.save_raw_response(conn, "GetPlayerAchievements", {"appid": app_id}, raw_ach)

            achievements_rows = transform.transform_user_achievements(raw_ach, steam_id, app_id)
            load.upsert_user_achievements(conn, achievements_rows)

        except Exception as e:
            logger.debug(f"No achievements available for app_id={app_id}: {e}")
            continue

    conn.commit()
    logger.info("User data synchronization complete.")