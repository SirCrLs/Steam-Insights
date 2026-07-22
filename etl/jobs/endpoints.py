BASE_URL = "https://api.steampowered.com"
APPDETAILS = "https://store.steampowered.com/api/appdetails"

# IStoreService
APP_LIST = f"{BASE_URL}/IStoreService/GetAppList/v1/"
APP_INFO = f"{BASE_URL}/IStoreService/GetAppInfo/v1/"
U_DISCOVERY_QUEUE = f"{BASE_URL}/IStoreService/GetDiscoveryQueue/v1/"
U_GAMES_FOLLOWED = f"{BASE_URL}/IStoreService/GetGamesFollowed/v1/"
U_RECOMENDED_TAGS = f"{BASE_URL}/IStoreService/GetRecommendedTagsForUser/v1/"
U_STORE_PREFERENCES = f"{BASE_URL}/IStoreService/GetStorePreferences/v1/"
POPULAR_TAGS = f"{BASE_URL}/IStoreService/GetMostPopularTags/v1/"
U_GAME_INTEREST = f"{BASE_URL}/IStoreService/GetUserGameInterestState/v1/"


# ISteamChartsService
BEST_OF_YEAR_PAGES = f"{BASE_URL}/ISteamChartsService/GetBestOfYearPages/v1/"
GAMES_BY_CURRENT_PLAYERS = f"{BASE_URL}/ISteamChartsService/GetGamesByConcurrentPlayers/v1/"
MONTH_TOP_APP = f"{BASE_URL}/ISteamChartsService/GetMonthTopAppReleases/v1/"
MOST_PLAYED_GAMES = f"{BASE_URL}/ISteamChartsService/GetMostPlayedGames/v1/"
MOST_PLAYED_DECKGAMES = f"{BASE_URL}/ISteamChartsService/GetMostPlayedSteamDeckGames/v1/"
TOP_RELEASES_PAGES = f"{BASE_URL}/ISteamChartsService/GetTopReleasesPages/v1/"
YEAR_TOP_RELEASES = f"{BASE_URL}/ISteamChartsService/GetYearTopAppReleases/v1/"

# ISteamUserStats 
GLOBAL_ACHIEVEMENT_PERC = f"{BASE_URL}/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/"
GLOBAL_STATS_FOR_GAME = f"{BASE_URL}/ISteamUserStats/GetGlobalStatsForGame/v1/"
CURRENT_PLAYERS = f"{BASE_URL}/ISteamUserStats/GetNumberOfCurrentPlayers/v1/"
U_PLAYER_ACHIEVEMENTS = f"{BASE_URL}/ISteamUserStats/GetPlayerAchievements/v1/"
SCHEMA_FOR_GAME = f"{BASE_URL}/ISteamUserStats/GetSchemaForGame/v2/"
U_STATS_FOR_GAME = f"{BASE_URL}/ISteamUserStats/GetUserStatsForGame/v2/"

# IPlayerService
GAME_ACHIEVEMENTS = f"{BASE_URL}/IPlayerService/GetGameAchievements/v1/"
U_OWNED_GAMES = f"{BASE_URL}/IPlayerService/GetOwnedGames/v1/"
U_RECENTLY_PLAYED = f"{BASE_URL}/IPlayerService/GetRecentlyPlayedGames/v1/"
U_GAME_PLAYTIME = f"{BASE_URL}/IPlayerService/GetSingleGamePlaytime/v1/"
U_STEAM_LEVEL = f"{BASE_URL}/IPlayerService/GetSteamLevel/v1/"
STEAM_LEVEL_DIST = f"{BASE_URL}/IPlayerService/GetSteamLevelDistribution/v1/"

# ISteamUser
U_PLAYER_SUMMARY = f"{BASE_URL}/ISteamUser/GetPlayerSummaries/v2/"