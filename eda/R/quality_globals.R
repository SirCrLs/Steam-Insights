# Summary & quality module: settings, helpers and DB queries
# TRUE = cache queries for one hour (FALSE is faster for development)
CACHE_ON <- FALSE

# table name in the DB -> label shown on its card
TABLES <- c(
  games             = "Games",
  users             = "Users",
  achievements      = "Achievements",
  user_games        = "User_Games",
  user_achievements = "User_Achievements"
)

RULES_SQL <- "sql/validity_rules.sql"

# some games failed the API call, so they are excluded from the null check
GAMES_API_FAILED <- "NOT (name = 'Not in DB' AND short_description = 'API call failed')"

fmt_int <- function(x) format(as.numeric(x), big.mark = ",")

# Database queries 
get_counts <- function() {
  sql <- paste(
    sprintf("(SELECT count(*)::float FROM %s) AS %s",
            names(TABLES), names(TABLES)),
    collapse = ", "
  )
  dbGetQuery(pool, paste("SELECT", sql))
}

get_kpis <- function() {
  g <- dbGetQuery(pool, "
    SELECT round(100.0 * count(*) FILTER (WHERE short_description IS NOT NULL
                    AND short_description <> 'API call failed') / count(*), 1)::float AS enriched,
           round(100.0 * count(*) FILTER (WHERE owners_min IS NOT NULL) / count(*), 1)::float AS steamspy,
           max(fetched_at) AS last_fetch
    FROM games")
  u <- dbGetQuery(pool, "
    SELECT round(100.0 * count(*) FILTER (WHERE has_public_games) / count(*), 1)::float AS pub_games
    FROM users")
  list(enriched = g$enriched, steamspy = g$steamspy,
       last_fetch = g$last_fetch, pub_games = u$pub_games)
}

get_funnel <- function() {
  r <- dbGetQuery(pool, "
    SELECT count(*)::float AS total,
           count(*) FILTER (WHERE is_public)::float AS public_profile,
           count(*) FILTER (WHERE has_public_games)::float AS public_games,
           count(*) FILTER (WHERE achievements_fetched)::float AS ach_attempted,
           count(*) FILTER (WHERE has_public_achievements)::float AS with_ach
    FROM users")
  stages <- c("Users loaded", "Public profile", "Public games",
              "Achievements attempted", "With achievements")
  data.frame(stage = factor(stages, levels = rev(stages)), n = unlist(r[1, ]))
}

# % of NULLs for every column of one table
get_null_pct <- function(tbl) {
  cols <- dbGetQuery(pool, sprintf(
    "SELECT column_name FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = '%s'
     ORDER BY ordinal_position", tbl
  ))$column_name

  if (length(cols) == 0)
    return(data.frame(column = character(), pct_nulls = numeric()))

  select_cols <- paste(sprintf(
    'round(100.0 * count(*) FILTER (WHERE "%1$s" IS NULL) / count(*), 1) AS "%1$s"', cols
  ), collapse = ", ")

  where <- if (tbl == "games") paste("WHERE", GAMES_API_FAILED) else ""
  res <- dbGetQuery(pool, sprintf("SELECT %s FROM %s %s", select_cols, tbl, where))

  data.frame(column = names(res), pct_nulls = as.numeric(res[1, ]))
}

get_validity_rules <- function() {
  if (!file.exists(RULES_SQL)) return(NULL)
  df <- dbGetQuery(pool, paste(readLines(RULES_SQL), collapse = "\n"))
  df$failed  <- as.numeric(df$failed)
  df$checked <- as.numeric(df$checked)
  df$pct     <- round(100 * df$failed / pmax(df$checked, 1), 2)
  df$status <- ifelse(df$pct == 0, "OK", ifelse(df$pct < 1, "Warning", "Check"))
  df
}

get_api_fails <- function() {
  dbGetQuery(pool, "
    SELECT
      COUNT(*) AS total_games,
      COUNT(*) FILTER (
        WHERE short_description = 'API call failed'
      ) AS api_failed,
      ROUND(
        100.0 * COUNT(*) FILTER (
          WHERE short_description = 'API call failed'
        ) / COUNT(*),
        1
      ) AS api_failed_pct
    FROM games
  ")
}

get_requirements_errors <- function() {
  dbGetQuery(pool, "
    SELECT
      COUNT(*) FILTER (
        WHERE pc_requirements_minimum IS NOT NULL
          AND processor_minimum IS NULL
      )::float AS processor_minimum,

      COUNT(*) FILTER (
        WHERE pc_requirements_recommended IS NOT NULL
          AND processor_recommended IS NULL
      )::float AS processor_recommended,

      COUNT(*) FILTER (
        WHERE pc_requirements_minimum IS NOT NULL
          AND graphics_minimum IS NULL
      )::float AS graphics_minimum,

      COUNT(*) FILTER (
        WHERE pc_requirements_recommended IS NOT NULL
          AND graphics_recommended IS NULL
      )::float AS graphics_recommended,

      COUNT(*) FILTER (
        WHERE pc_requirements_minimum IS NOT NULL
          AND ram_minimum_gb IS NULL
      )::float AS ram_minimum_gb,

      COUNT(*) FILTER (
        WHERE pc_requirements_recommended IS NOT NULL
          AND ram_recommended_gb IS NULL
      )::float AS ram_recommended_gb,

      COUNT(*) FILTER (
        WHERE pc_requirements_minimum IS NOT NULL
          AND storage_minimum_gb IS NULL
      )::float AS storage_minimum_gb,

      COUNT(*) FILTER (
        WHERE pc_requirements_recommended IS NOT NULL
          AND storage_recommended_gb IS NULL
      )::float AS storage_recommended_gb

    FROM games
  ")
}