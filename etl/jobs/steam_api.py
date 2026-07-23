from jobs import endpoints as urls
import logging
import time
import requests
import json

logger = logging.getLogger(__name__)


def _make_request(url: str, api_key: str = None, input_params: Optional[dict] = None):
    """Internal function to perform HTTP GET requests."""
    if api_key is not None:
        params = {"key": api_key}
    else:
        params = {}

    # if endpoint requires input_json
    if input_params is not None:
        params["input_json"] = json.dumps(input_params)

    try:
        response = requests.get(url, params=params, timeout=15)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error on {url}: {e}")
        return {}

# Functions to fetch data from Steam API endpoints

def get_app_details(app_id):
    """ Fetches metadata for a specific game. """
    params = {
        "appids": app_id, 
        "cc": "mx", 
        "l": "english"
        }
    #This endpoint does not require an API key so I wont call the _make_request function here
    response = requests.get(urls.APP_DETAILS, params=params, timeout=15)
    response.raise_for_status()
    return response.json()

def get_app_list(api_key: str, max_results: int = 200):
    """ Fetches the full list of AppIDs from Steam. """
    params = {
        "max_results": max_results,
        "include_games": True,
        "include_dlc": False,
        "include_software": False,
        "include_videos": False,
        "include_hardware": False,
    }

    return _make_request(urls.APP_LIST, api_key, params)


def get_tag_list(api_key: str):
    """ Fetches the most popular tags from Steam store. """
    params = {
        "language": "english"
    }
    return _make_request(urls.POPULAR_TAGS, api_key, params)

def get_games_by_current_players(api_key: str):
    """ Fetches games by current players from Steam charts. """
    return _make_request(urls.GAMES_BY_CURRENT_PLAYERS, api_key)


def get_most_played_games(api_key: str):
    """ Fetches the most played games from Steam charts. """
    return _make_request(urls.MOST_PLAYED_GAMES, api_key)

def get_global_achievement_percentages(app_id: int):
    """ Fetches global achievement percentages for a specific game. """
    params = {
        "gameid": app_id
    }
    #This endpoint does not require an API key so I wont call the _make_request function here
    response = requests.get(urls.GLOBAL_ACHIEVEMENT_PERC, params=params, timeout=15)
    response.raise_for_status()
    return response.json()

def get_number_of_current_players(app_id: int):
    """ Fetches the number of current players for a specific game. """
    params = {
        "appid": app_id
    }
    #This endpoint does not require an API key so I wont call the _make_request function here
    response = requests.get(urls.CURRENT_PLAYERS, params=params, timeout=15)
    response.raise_for_status()
    return response.json()

def get_steam_level_distribution(api_key: str, level: int):
    """ Fetches the distribution of Steam levels among users. """
    params = {
        "player_level": level}
    return _make_request(urls.STEAM_LEVEL_DIST, api_key, params)


# User Functions

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