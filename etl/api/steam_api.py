from api import endpoints as urls
from datetime import datetime
from typing import Optional
from pathlib import Path
import steamspypi
import logging
import time
import requests
import json
import re
import os

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

# ===
# Functions to fetch data from Steam API endpoints
# ===

def get_app_details(app_id):
    """ Fetches metadata for a specific game. (max 10 appids) """
    params = {
        "appids": app_id, 
        "cc": "us", 
        "l": "english"
        }
    #This endpoint does not require an API key so I wont call the _make_request function here
    response = requests.get(urls.APP_DETAILS, params=params, timeout=15)
    response.raise_for_status()
    return clean_app_details(response.json(), app_id)

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

def get_popular_tags(api_key: str):
    """ Fetches the most popular tags from Steam store. """
    params = {
        "language": "english"
    }
    return _make_request(urls.POPULAR_TAGS, api_key, params)

def get_games_by_current_players(api_key: str):
    """ Fetches games by current players from Steam charts. """
    return _make_request(urls.GAMES_BY_CURRENT_PLAYERS, api_key)

def get_global_achievement_percentages(app_id: int):
    """ Fetches global achievement percentages for a specific game. """
    params = {
        "gameid": app_id
    }
    #This endpoint does not require an API key so I wont call the _make_request function here
    response = requests.get(urls.GLOBAL_ACHIEVEMENT_PERC, params=params, timeout=15)
    response.raise_for_status()
    return response.json()

def get_schema_for_game(api_key: str,app_id: int):
    """ Fetches the schema for a specific game. """
    params = {
        "key": api_key,
        "appid": app_id
    }
    response = requests.get(urls.SCHEMA_GAME, params=params, timeout=15)
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

def get_synced_game_achievements(api_key, appid):
    """Synchronizes achievements from game schema and achievement percentages."""  
    achievements = get_schema_for_game(api_key, appid)["game"]["availableGameStats"]["achievements"]
    achievements_percent = get_global_achievement_percentages(appid)["achievementpercentages"]["achievements"]

    percentage_dict = {item["name"]: item["percent"] for item in achievements_percent}

    full_achievements = []

    for achievement in achievements:
        name = achievement["name"]
        porcentaje = percentage_dict.get(name, 0.0)

        all_achievements = {
            "name": name,
            "displayName": achievement.get("displayName", name),
            "description": achievement.get("description", ""),
            "percent": float(porcentaje)
        }

        full_achievements.append(all_achievements)

    return full_achievements

# ===
# User Functions
# ===

def get_owned_games(api_key: str, steam_id: int):
    """ Fetches the list of games owned by a specific user. """
    params = {
        "steamid": steam_id,
        "include_appinfo": False,
        "include_played_free_games": True,
        "appids_filter": None,
        "include_free_sub": False,
        "language": "english",
        "include_extended_appinfo": False
    }
    return _make_request(urls.U_OWNED_GAMES, api_key, params)

def get_recently_played_games(api_key: str, steam_id: int):
    """ Fetches the list of games recently played by a specific user. """
    params = {
        "steamid": steam_id,
        "count": 0,
    }
    return _make_request(urls.U_RECENTLY_PLAYED, api_key, params)

def get_steam_level(api_key: str, steam_id: int):
    """ Fetches the Steam level of a specific user. """
    params = {
        "steamid": steam_id,
    }
    return _make_request(urls.U_STEAM_LEVEL, api_key, params)

def get_top_achievements(api_key: str, steam_id: int, app_ids: list[int]):
    """Fetches the top achievements for a specific user across multiple games."""

    params = {
        "key": api_key,
        "steamid": steam_id,
        "max_achievements": 10,
    }

    for i, app_id in enumerate(app_ids):
        params[f"appids[{i}]"] = app_id

    response = requests.get(urls.U_TOP_ACHIEVEMENTS, params=params, timeout=15)
    response.raise_for_status()
    return response.json()

def get_player_summaries(api_key: str, steam_ids: list):
    """ Fetches summaries for a list of users. """
    steamids_str = ",".join(map(str, steam_ids))

    params = {
        "key": api_key,
        "steamids": steamids_str
    }

    response = requests.get(urls.U_PLAYER_SUMMARY, params=params)
    response.raise_for_status()
    return response.json()

def get_games_followed(steam_id: int):
    """ Fetches the list of games followed by a specific user. """
    params = {
        "steamid": steam_id,
    }
    response = requests.get(urls.U_GAMES_FOLLOWED, params=params, timeout=15)
    response.raise_for_status()
    return response.json()

def get_user_stats_for_game(api_key: str, steam_id: int, app_id: int):
    """ Fetches user stats for a specific game. """
    params = {
        "key": api_key,
        "steamid": steam_id,
        "appid": app_id
    }
    response = requests.get(urls.U_STATS_FOR_GAME, params=params, timeout=15)
    response.raise_for_status()
    return response.json()

def get_friend_list(api_key, steam_id):
    params = {
        'key': api_key,
        'steamid': str(steam_id),
        'relationship': 'friend'
    }
    
    try:
        response = requests.get(urls.U_GET_FRIEND_LIST, params=params, timeout=15)
        if response.status_code == 401:
            return []
            
        if response.status_code == 200:
            data = response.json()
            friends = data.get('friendslist', {}).get('friends', [])
            return friends
            
    except requests.exceptions.RequestException as e:
        print(f"Something went wrong with {steam_id}: {e}")
        
    return []

def generate_steam_seed_ids(api_key, starting_steam_id, max_ids=300, output_file="data/seed_steam_ids.txt"):
    """ Gathers ids until max_ids from initial Steam ID using GetFriendList. """
    collected_ids = set()
    queue = [str(starting_steam_id)]

    while queue and len(collected_ids) < max_ids:
        current_id = queue.pop(0)
        
        friends_found = get_friend_list(api_key, current_id)
        
        for friend_id in friends_found:
            if friend_id not in collected_ids:
                collected_ids.add(friend_id)
                queue.append(friend_id)

                if len(collected_ids) >= max_ids:
                    break
                    
        time.sleep(0.1)
        
    with open(output_file, "w", encoding="utf-8") as f:
        for steam_id in list(collected_ids)[:max_ids]:
            f.write(f"{steam_id}\n")
            
    print(f"Finished. storaged {len(collected_ids)} IDs on '{output_file}'.")
    return list(collected_ids)

# STEAMSPY FUNCTIONS
""" Second API for steam that allows much more request """

def steamspy_get_game_details(page : str = "0", request : str = "all"):
    """ Gets 1 page of steam (1000 games) it has 1 minute cooldown """
    data_request = dict()
    data_request['request'] = request
    data_request['page'] = page

    data = steamspypi.download(data_request)
    return data

def steamspy_get_all_games(max_page : int):
    """ Gets all games until the max_page parameter, each page is 1000 games """
    steamspypi.download_all_pages(max_page)
    move_json_to_folder()
    return 

def steamspy_download_all_pages_resumable(max_page: int, output_folder: str = os.path.join("..", "data")):
    """
    Downloads SteamSpy pages one at a time, skipping pages already saved to disk.
    """
    os.makedirs(output_folder, exist_ok=True)

    for page in range(max_page):
        output_path = os.path.join(output_folder, f"page_{page}.json")

        if os.path.exists(output_path):
            logger.info(f"Page {page} already downloaded, skipping.")
            continue

        logger.info(f"Fetching page {page} from SteamSpy...")
        try:
            data = steamspy_get_game_details(page=str(page))

            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(data, f)

            logger.info(f"Saved page {page} with {len(data)} games.")

        except Exception as e:
            logger.error(f"Failed to fetch page {page}: {e}")
            logger.info(f"Stopping. Resume later — pages 0-{page - 1} are saved.")
            raise

        if page < max_page - 1:
            logger.info("Waiting 70 seconds before next page (SteamSpy rate limit)...")
            print(f"Downloaded page {page}. sleeping 70 sec")
            time.sleep(70)

# ====
# Data cleaning and transformation functions
# ====

def clean_app_details(r : json, app_id):
    r = r[f"{app_id}"]["data"]
    r["short_description"] = remove_html_tags(r["short_description"])
    r["supported_languages"] = extract_languages(r["supported_languages"])
    r["genres"] = extract_categories(r["genres"])
    r["categories"] = extract_categories(r["categories"])
    r["metacritic"] = r["metacritic"]["score"]
    r["pc_requirements"]["minimum_specs"] = parse_requirements(r["pc_requirements"]["minimum"])
    r["pc_requirements"]["recommended_specs"] = parse_requirements(r["pc_requirements"]["recommended"])
    r["pc_requirements"]["minimum"] = remove_html_tags(r["pc_requirements"]["minimum"])
    r["pc_requirements"]["recommended"] =remove_html_tags(r["pc_requirements"]["recommended"] )
    r["release_date"]["date"] = string_to_date(r["release_date"]["date"]) 
    r["price_overview"] = extract_price_from_string(r["price_overview"]["final_formatted"])
    r["ratings"] = next(iter(r["ratings"].values()), None)
    return r 

def extract_categories(r : json):
    descriptions_array = [item['description'] for item in r if 'description' in item]
    return descriptions_array

def remove_html_tags(html_text):
    spaced_text = re.sub(r'<[^>]+>|\*', ' ', html_text)
    clean_text = re.sub(r'\s+', ' ', spaced_text)
    return clean_text.strip()

def extract_price_from_string(str_price):
    match = re.search(r'\d+(?:[.,]\d+)*', str_price)
    
    if match:
        num_str = match.group()
        if ',' in num_str and '.' in num_str:
            num_str = num_str.replace(',', '')
        elif ',' in num_str and '.' not in num_str:
            num_str = num_str.replace(',', '.')
            
        return float(num_str)
    
    return 0.0 

def extract_languages(text_input):
    clean_text = text_input.split('<br>')[0]
    clean_text = re.sub(r'<[^>]+>', '', clean_text)
    clean_text = clean_text.replace('*', '') 
    languages_list = []
    for lang in clean_text.split(','):
        lang = lang.strip()
        if lang:
            if '-' in lang:
                lang = lang.split('-')[0].strip()
            languages_list.append(lang)
            
    return languages_list

def parse_requirements(raw_html):
    """ extract processor, graphics, memory and storage """
    if not raw_html:
        return {
            "processor": None,
            "graphics": None,
            "memory_gb": None,
            "storage_gb": None,
        }

    li_pattern = r'<li>(?:<strong>(.*?):?</strong>)?\s*(.*?)</li>'
    matches = re.findall(li_pattern, raw_html, re.IGNORECASE | re.DOTALL)

    fields = {}
    for label, value in matches:
        if not label:
            continue
        clean_label = re.sub(r'[*\s]+$', '', label.strip()).lower()
        clean_value = re.sub(r'<[^>]+>', '', value).strip()
        fields[clean_label] = clean_value

    memory_gb = None
    if "memory" in fields:
        m = re.search(r'([\d.]+)\s*GB', fields["memory"], re.IGNORECASE)
        if m:
            memory_gb = float(m.group(1))

    storage_gb = None
    if "storage" in fields:
        m = re.search(r'([\d.]+)\s*GB', fields["storage"], re.IGNORECASE)
        if m:
            storage_gb = float(m.group(1))

    return {
        "processor": fields.get("processor"),
        "graphics": fields.get("graphics"),
        "memory_gb": memory_gb,
        "storage_gb": storage_gb,
    }


def string_to_date(fecha_str: str):
    try:
        return datetime.strptime(fecha_str, "%b %d, %Y").date()
    except ValueError as e:
        print(f"Error: '{fecha_str}' is not valid. Should be 'MM DD, AAAA'")
        return None

def download_json(data, filename="data.json"):
    try:
        with open(filename, "w", encoding="utf-8") as file:
            json.dump(data, file, indent=4, ensure_ascii=False)
        print(f"Successfully saved to {filename}")
    except Exception as e:
        print(f"An error occurred: {e}")

def move_json_to_folder():
    import os
    import glob
    import shutil

    destination_folder = "data"
    
    if not os.path.exists(destination_folder):
        os.makedirs(destination_folder)
        
    json_files = glob.glob("*.json")
    
    if not json_files:
        print("No Json files to move")
        return

    for source_file in json_files:
        destination_file = os.path.join(destination_folder, os.path.basename(source_file))
        shutil.move(source_file, destination_file)

def read_various_jsons(directory_path: str = "data", output_file_name: str = "data/merged_output.json"):
    """Reads all JSON files in a directory and merges them into one unique dictionary object."""
    combined_data = {}
    dir_path = Path(directory_path)
    json_files = dir_path.glob("*.json")
    
    for file_path in json_files:
        try:
            with open(file_path, "r", encoding="utf-8") as file:
                data = json.load(file)
                
                if isinstance(data, dict):
                    combined_data.update(data)
                else:
                    print(f"Skipping {file_path.name}: File content is not a JSON object/dictionary.")
                    
        except (json.JSONDecodeError, FileNotFoundError) as error:
            print(f"Skipping {file_path.name} due to error: {error}")
            continue
            
    download_json(combined_data, output_file_name)
    return combined_data

# ===
# Transform functions
# ===

def transform_game_stubs(games_list):
    """ minimal rows (app_id + name) from the combined """
    rows = []
    for game in games_list:
        app_id = game.get("appid")
        name = game.get("name")
        if not app_id or not name:
            continue
        rows.append({"app_id": app_id, "name": name})
    return rows

def transform_game_details(app_id, data):
    """ maps the appdetails response to the full games schema. """
    if not data:
        return None

    specs_min = data.get("pc_requirements").get("minimum_specs")
    specs_rec = data.get("pc_requirements").get("recommended_specs")
    platforms = data.get("platforms")
    release_date = data.get("release_date").get("date")

    # Return
    return {
        "app_id": int(app_id),
        "name": data.get("name"),
        "short_description": data.get("short_description"),
        "genres": data.get("genres"),                                    # TEXT[]
        "categories": data.get("categories"),                            # TEXT[]
        "supported_languages": data.get("supported_languages"),
        "header_image": data.get("header_image"),
        "pc_requirements_minimum": data.get("pc_requirements").get("minimum"),
        "pc_requirements_recommended": data.get("pc_requirements").get("recommended"),
        
        # Index [0] = minimum, [1] = recommended
        "processor": [specs_min.get("processor"), specs_rec.get("processor")], 
        "graphics": [specs_min.get("graphics"), specs_rec.get("graphics")],                     
        "ram_requirement": [specs_min.get("memory_gb"), specs_rec.get("memory_gb")],      
        "storage_requirement": [specs_min.get("storage_gb"), specs_rec.get("storage_gb")], 
        
        "developers": data.get("developers"),
        "is_on_windows": platforms.get("windows", False),
        "is_on_mac": platforms.get("mac", False),
        "is_on_linux": platforms.get("linux", False),
        "metacritic_score": data.get("metacritic", {}), # SMALLINT
        "release_date": release_date,
        "price_usd": data.get("price_overview", 0),
        "is_free": data.get("is_free", False),
        "rating": data.get("ratings").get("rating", None), 
        "total_achievements": data.get("achievements", {}).get("total", 0),
        "fetched_at": datetime.now()
    }

def transform_achievements(app_id, schema_response):
    """ maps GetSchemaForGame response to achievements rows """

    rows = []
    for ach in schema_response:
        rows.append({
            "app_id": app_id,
            "achievement_key": ach.get("name"),
            "display_name": ach.get("displayName"),
            "achievement_desc": ach.get("description"),
            "global_unlock_pct": ach.get("percent"),
        })
    return rows


def transform_user(raw_summary):
    """ maps GetPlayerSummaries to a users row. """
    players = raw_summary.get("response", {}).get("players", [])
    if not players:
        raise ValueError("No player data in GetPlayerSummaries response.")

    player = players[0]

    return {
        "steam_id": int(player["steamid"]),
        "persona_name": player.get("personaname"),
        "profile_url": player.get("profileurl"),
        "country_code": player.get("loccountrycode"),
        "account_created": player.get("timecreated"),  
        "is_public": player.get("communityvisibilitystate") == 3,
    }


def transform_owned_games(raw_games, valid_app_ids):
    """ maps GetOwnedGames to user_games rows """
    games = raw_games.get("response", {}).get("games", [])
    rows = []
    skipped = 0

    for game in games:
        app_id = game["appid"]
        if app_id not in valid_app_ids:
            skipped += 1
            continue

        rows.append({
            "app_id": app_id,
            "playtime_forever_minutes": game.get("playtime_forever", 0),
            "playtime_2weeks_minutes": game.get("playtime_2weeks", 0),
        })

    return rows, skipped


def transform_user_achievements(raw_achievements, steam_id, app_id):
    """ maps GetPlayerAchievements to user_achievements rows. """
    playerstats = raw_achievements.get("playerstats", {})
    if not playerstats.get("success"):
        return []

    achievements = playerstats.get("achievements", [])
    rows = []

    for ach in achievements:
        rows.append({
            "steam_id": steam_id,
            "app_id": app_id,
            "achievement_key": ach.get("apiname"),
            "unlocked": bool(ach.get("achieved")),
            "unlock_time": ach.get("unlocktime") or None, 
        })

    return rows