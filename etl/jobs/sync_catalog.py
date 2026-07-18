import logging
import time
import requests

logger = logging.getLogger(__name__)

STEAM_APPLIST_URL = "https://api.steampowered.com/IStoreService/GetAppList/v1/"
STORE_APPDETAILS_URL = "https://store.steampowered.com/api/appdetails"


def get_app_list(api_key, max_results=100):
    """
    Fetches the full list of AppIDs from Steam.
    Now requires an API key (ISteamApps/GetAppList/v2 was deprecated).
    """
    params = {
        "key": api_key,
        "max_results": max_results,
        "include_games": True,
        "include_dlc": False,
        "include_software": False,
        "include_videos": False,
        "include_hardware": False,
    }
    response = requests.get(STEAM_APPLIST_URL, params=params, timeout=15)
    response.raise_for_status()
    return response.json()["response"]["apps"]


def get_app_details(app_id):
    """Fetches metadata for a specific game (price, genre, etc)."""
    params = {"appids": app_id, "cc": "mx", "l": "english"}
    response = requests.get(STORE_APPDETAILS_URL, params=params, timeout=15)
    response.raise_for_status()
    data = response.json()

    app_data = data.get(str(app_id))
    if not app_data or not app_data.get("success"):
        return None

    return app_data["data"]


def run(conn, load, transform, api_key, max_games=None):
    logger.info("Fetching full Steam app list...")
    apps = get_app_list(api_key)
    logger.info(f"{len(apps)} apps found in the Steam catalog.")

    if max_games:
        apps = apps[:max_games]

    for app in apps:
        app_id = app["appid"]
        name = app.get("name")

        if not name:
            continue

        try:
            details = get_app_details(app_id)
            if details is None:
                continue

            load.save_raw_response(conn, "appdetails", {"appids": app_id}, details)

            game_row = transform.transform_game_details(app_id, details)
            load.upsert_game(conn, game_row)

            logger.info(f"Saved: {name} (app_id={app_id})")

        except Exception as e:
            logger.warning(f"Error processing app_id={app_id} ({name}): {e}")
            continue

        time.sleep(1.5)

    conn.commit()
    logger.info("Catalog sync completed.")