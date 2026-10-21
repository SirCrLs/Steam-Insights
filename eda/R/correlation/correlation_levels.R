# Variable catalog
correlation_num_var <- function(label, valid = NULL, sparse = FALSE) {
  list(type = "num", label = label, valid = valid, sparse = sparse, expr = NULL)
}
correlation_cat_var <- function(label, expr = NULL) {
  list(type = "cat", label = label, valid = NULL, sparse = FALSE, expr = expr)
}

# Game attributes shared by the game, usergame and achievement levels
correlation_game_attr_num <- list(
  price_usd = correlation_num_var(
    "Price (USD)", "price_usd >= 0"
  ),
  approval_rate = correlation_num_var(
    "Approval Rate (%)", "approval_rate BETWEEN 0 AND 100"
  ),
  total_reviews = correlation_num_var(
    "Total Reviews", "total_reviews >= 0"
  ),
  positive_reviews = correlation_num_var(
    "Positive Reviews", "positive_reviews >= 0"
  ),
  metacritic_score = correlation_num_var(
    "Metacritic score", "metacritic_score BETWEEN 0 AND 100"
  ),
  release_year = correlation_num_var(
    "release year", "release_year BETWEEN 1970 AND 2100"
  )
)
correlation_game_attr_cat <- list(
  primary_genre = correlation_cat_var("Main Genre"),
  is_free = correlation_cat_var("Free (true/false)"),
  release_year_cat  = correlation_cat_var(
    "Release year (categ.)", "release_year::text"
  )
)

correlation_levels <- list(

  # game
  game = list(
    label = "Game", view = "mv_level_game",
    has_rnd = FALSE, has_uniform = FALSE, has_game_cols = TRUE,
    ach_expr = "avg_pct_completed IS NOT NULL",
    vars = c(
      correlation_game_attr_num[c("price_usd", "metacritic_score",
                                  "release_year", "positive_reviews",
                                  "total_reviews", "approval_rate")],
      list(
        total_achievements = correlation_num_var(
          "Total Achievements", "total_achievements >= 0"
        ),
        recommendations = correlation_num_var(
          "Recommendations", "recommendations >= 0"
        ),
        owners_min = correlation_num_var(
          "Owners (minimum)", "owners_min >= 0"
        ),
        owners_max = correlation_num_var(
          "Owners (maximum)", "owners_max >= 0"
        ),
        negative_reviews = correlation_num_var(
          "Negative Reviews", "negative_reviews >= 0"
        ),
        ram_minimum_gb = correlation_num_var(
          "RAM minimum (GB)", "ram_minimum_gb > 0"
        ),
        ram_recommended_gb = correlation_num_var(
          "RAM recommended (GB)", "ram_recommended_gb > 0"
        ),
        storage_minimum_gb = correlation_num_var(
          "Storage minimum (GB)", "storage_minimum_gb > 0"
        ),
        storage_recommended_gb = correlation_num_var(
          "Storage recommended (GB)", "storage_recommended_gb > 0"
        ),
        n_genres = correlation_num_var("Number of Genres"),
        n_categories = correlation_num_var("Number of categories"),
        n_languages = correlation_num_var("Number of languages"),
        n_achievements_defined = correlation_num_var("Defined Achievements"),
        avg_global_unlock_pct = correlation_num_var(
          "% global unlock (average)", "avg_global_unlock_pct BETWEEN 0 AND 100"
        ),
        min_global_unlock_pct = correlation_num_var(
          "% global unlock (minimum)", "min_global_unlock_pct BETWEEN 0 AND 100"
        ),
        pct_rare_achievements = correlation_num_var(
          "% Rare Achievements (<5%)"
        ),
        n_users = correlation_num_var("Users on the sample"),
        avg_playtime_forever = correlation_num_var(
          "Average playtime (min)", "avg_playtime_forever >= 0"
        ),
        median_playtime_forever = correlation_num_var(
          "Median playtime (min)", "median_playtime_forever >= 0"
        ),
        pct_users_played = correlation_num_var("% of users that played"),
        avg_playtime_2weeks = correlation_num_var(
          "Average playtime on last 2 weeks (min)", "avg_playtime_2weeks >= 0"
        ),
        n_users_ach_data = correlation_num_var(
          "Users with achievements", sparse = TRUE
        ),
        avg_pct_completed = correlation_num_var(
          "% Average completition", sparse = TRUE
        ),
        is_on_windows = correlation_cat_var("On Windows"),
        is_on_mac = correlation_cat_var("On Mac"),
        is_on_linux = correlation_cat_var("On Linux"),
        rating = correlation_cat_var("Rating")
      ),
      correlation_game_attr_cat
    )
  ),

  # user
  user = list(
    label = "User", view = "mv_level_user",
    has_rnd = FALSE, has_uniform = FALSE, has_game_cols = FALSE,
    ach_expr = "has_ach_data",
    vars = list(
      account_age_days = correlation_num_var(
        "Account age (days)", "account_age_days >= 0"
      ),
      account_year = correlation_num_var(
        "Account year", "account_year BETWEEN 2003 AND 2100"
      ),
      games_owned = correlation_num_var(
        "Games owned", "games_owned >= 0"
      ),
      total_playtime = correlation_num_var(
        "Total Playtime (min)", "total_playtime >= 0"
      ),
      avg_playtime = correlation_num_var(
        "Average Playtime (min)", "avg_playtime >= 0"
      ),
      pct_games_played = correlation_num_var("% of played games"),
      total_playtime_2weeks = correlation_num_var(
        "Total Playtime 2 weeks (min)", "total_playtime_2weeks >= 0"
      ),
      achievements_unlocked = correlation_num_var(
        "Achievements unlocked", sparse = TRUE
      ),
      avg_pct_completed = correlation_num_var(
        "% average completition", sparse = TRUE
      ),
      country_code = correlation_cat_var("Country code"),
      is_public = correlation_cat_var("Public profile"),
      has_public_games = correlation_cat_var("Public games"),
      has_public_achievements = correlation_cat_var("Public achievements"),
      has_ach_data = correlation_cat_var("Has achievement data"),
      account_year_cat = correlation_cat_var(
        "Account year (categ.)", "account_year::text"
      )
    )
  ),

  # usergame
  usergame = list(
    label = "User-Game", view = "mv_level_usergame_sample",
    has_rnd = TRUE, has_uniform = TRUE, has_game_cols = TRUE,
    ach_expr = "has_ach_data",
    vars = c(
      list(
        playtime_forever = correlation_num_var(
          "Total Playtime (min)", "playtime_forever >= 0"
        ),
        playtime_2weeks = correlation_num_var(
          "Playtime 2 weeks (min)", "playtime_2weeks BETWEEN 0 AND 20160"
        ),
        achievements_unlocked = correlation_num_var(
          "Unlocked Achievements", sparse = TRUE
        ),
        pct_completed = correlation_num_var(
          "% completed", "pct_completed BETWEEN 0 AND 100", sparse = TRUE
        ),
        total_achievements = correlation_num_var(
          "Total achievements", "total_achievements >= 0"
        ),
        account_year = correlation_num_var(
          "Year of account creation", "account_year BETWEEN 2003 AND 2100"
        )
      ),
      correlation_game_attr_num,
      list(
        country_code = correlation_cat_var("User's Country"),
        has_ach_data = correlation_cat_var("has achievements data")
      ),
      correlation_game_attr_cat
    )
  ),

  # achievement
  achievement = list(
    label = "Achievement", view = "mv_level_achievement_sample",
    has_rnd = TRUE, has_uniform = FALSE, has_game_cols = TRUE,
    ach_expr = NULL,
    vars = c(
      list(
        global_unlock_pct = correlation_num_var(
          "% global unlock", "global_unlock_pct BETWEEN 0 AND 100"
        ),
        name_length = correlation_num_var("Name's lenght"),
        desc_length = correlation_num_var("Description's lenght"),
        n_achievements_defined = correlation_num_var("Achievements of the game")
      ),
      correlation_game_attr_num,
      list(rarity_tier = correlation_cat_var("Rarity level")),
      correlation_game_attr_cat
    )
  )
)