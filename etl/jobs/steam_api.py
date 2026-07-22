from jobs import endpoints as urls
import logging
import time
import requests

logger = logging.getLogger(__name__)



def get_app_list(api_key, max_results=100):
    """ Fetches the full list of AppIDs from Steam. """
    params = {
        "key": api_key,
        "max_results": max_results,
        "include_games": True,
        "include_dlc": False,
        "include_software": False,
        "include_videos": False,
        "include_hardware": False,
    }
    response = requests.get(urls.APPLIST, params=params, timeout=15)
    response.raise_for_status()
    return response.json()["response"]["apps"]

def get_tag_list(api_key, max_results=100):
    """ Fetches the most popular tags from Steam store. """
    params = {
        "key": api_key,
        "language": "english"
    }
    response = requests.get(urls.MOSTPOPULARTAGS, params=params, timeout=15)
    response.raise_for_status()
    return response.json()["response"]["tags"]


def get_app_details(app_id):
    """ Fetches metadata for a specific game. """
    params = {"appids": app_id, "cc": "mx", "l": "english"}
    response = requests.get(urls.APPDETAILS, params=params, timeout=15)
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