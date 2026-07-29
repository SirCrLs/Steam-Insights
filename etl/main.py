from jobs.steam_api import *

""" VARIABLES """

max_page = 3 # each page is 1000 games 

""" GAMES """

# 1. Download game list JSON 
#    a. Call get_games_by_current_players()
#    b. Call steamspy_get_all_games(max_page)

# 2. Insert game list into the database (app_id + name)

# 3. For each game already in the database (SELECT app_id FROM games):
#    a. Fetch appdetails(app_id)
#    b. Fetch get_synced_game_achievements(app_id) 


""" USERS """

# 1. Get seed SteamIDs
#    - Prompt SteamIDs from a .txt

# 2. For each SteamID in the seed list:
#    a. Fetch GetPlayerSummaries(steam_id)
#    b. Fetch GetOwnedGames(steam_id) (skip games that are not on db)
#    c. Fetch GetPlayerAchievements(steam_id, app_id)

