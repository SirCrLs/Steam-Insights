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

# This call is very convoluted but ill try and explain it
# It retrieves PC Requirements Extraction Errors and Failure Rates
#
# Queries the database to calculate total counts and percentage error rates
# for hardware fields (processor, graphics, RAM, storage) where
# raw PC requirements text exists but the parsed field returned NULL.
#
# It returns a table that has 4 columns (field, errors, total, pct_errors)
#   field:      each column of the original table (processor, graphics, etc.)
#   errors:     total errors
#   total:      total count that succeded
#   pct_errors: errors percentage against the total count
get_requirements_errors <- function() {
  dbGetQuery(pool, "
    WITH counts AS (
      SELECT
        COUNT(*) FILTER 
        (WHERE pc_requirements_minimum IS NOT NULL)::numeric AS min_total,
        COUNT(*) FILTER 
        (WHERE pc_requirements_recommended IS NOT NULL)::numeric AS rec_total,
        
        COUNT(*) FILTER 
        (WHERE pc_requirements_minimum IS NOT NULL 
        AND processor_minimum IS NULL)::numeric AS processor_minimum_err,
        COUNT(*) FILTER 
        (WHERE pc_requirements_recommended IS NOT NULL 
        AND processor_recommended IS NULL)::numeric AS processor_recommended_err,
        
        COUNT(*) FILTER 
        (WHERE pc_requirements_minimum IS NOT NULL 
        AND graphics_minimum IS NULL)::numeric AS graphics_minimum_err,
        COUNT(*) FILTER 
        (WHERE pc_requirements_recommended IS NOT NULL 
        AND graphics_recommended IS NULL)::numeric AS graphics_recommended_err,
        
        COUNT(*) FILTER 
        (WHERE pc_requirements_minimum IS NOT NULL 
        AND ram_minimum_gb IS NULL)::numeric AS ram_minimum_gb_err,
        COUNT(*) FILTER 
        (WHERE pc_requirements_recommended IS NOT NULL 
        AND ram_recommended_gb IS NULL)::numeric AS ram_recommended_gb_err,
        
        COUNT(*) FILTER 
        (WHERE pc_requirements_minimum IS NOT NULL 
        AND storage_minimum_gb IS NULL)::numeric AS storage_minimum_gb_err,
        COUNT(*) FILTER 
        (WHERE pc_requirements_recommended IS NOT NULL 
        AND storage_recommended_gb IS NULL)::numeric AS storage_recommended_gb_err
      FROM games
    )
    SELECT 
      field, 
      errors::float AS errors, 
      total::float AS total, 
      ROUND(CAST(100.0 * errors / NULLIF(total, 0) AS numeric), 1)
      ::float AS pct_error
    FROM counts,
    LATERAL (
      VALUES
        ('processor_minimum', processor_minimum_err, min_total),
        ('processor_recommended', processor_recommended_err, rec_total),
        ('graphics_minimum', graphics_minimum_err, min_total),
        ('graphics_recommended', graphics_recommended_err, rec_total),
        ('ram_minimum_gb', ram_minimum_gb_err, min_total),
        ('ram_recommended_gb', ram_recommended_gb_err, rec_total),
        ('storage_minimum_gb', storage_minimum_gb_err, min_total),
        ('storage_recommended_gb', storage_recommended_gb_err, rec_total)
    ) AS t(field, errors, total)
  ")
}