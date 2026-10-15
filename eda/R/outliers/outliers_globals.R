library(shiny)
library(bslib)
library(bsicons)
library(DBI)
library(pool)
library(dplyr)
library(ggplot2)
library(plotly)
library(DT)

# Constants
outliers_methods <- c(
  "IQR (Tukey)"        = "iqr",
  "Z-score"            = "z",
  "Modified Z (MAD)"   = "mad"
)
outliers_method_names <- c(iqr = "IQR", z = "Z-score", mad = "MAD")
outliers_k_default    <- c(iqr = 1.5, z = 3, mad = 3.5)

outliers_n_bins <- 40L          # histogram bars
outliers_max_rows <- 10000L     # maximum rows in the outliers table
outliers_sample_pts <- 1500L    # outlier points drawn in the boxplot
outliers_max_groups <- 15L      # maximum groups in the boxplot per group
outliers_min_group_n <- 5L      # minimum n to show a group

# General utilities
outliers_or <- function(a, b) if (is.null(a) || length(a) == 0) b else a

outliers_fmt <- function(x) {
  vapply(x, function(z) {
    if (is.null(z) || is.na(z)) "\u2014"
    else format(signif(z, 4), big.mark = ",", scientific = FALSE, trim = TRUE)
  }, character(1))
}

# Axis labels when working in log10 (shown in original scale)
outliers_log_labels <- function(b) outliers_fmt(10^b)

# Tables and variables catalog
# Conventions:
#   - Every query exposes the source with the alias `t`.
#   - `value` : SQL expression of the numeric variable.
#   - `valid` : valid range SQL condition (for "Exclude invalid values").
#   - `id`/`lbl`: columns that identify the record in the outliers table.
#   - `groups`: available groupings for the "By group" tab.
outliers_tables <- list(

  # games 
  games = list(
    label = "games",
    from = "games t", id = "t.app_id", lbl = "t.name",
    id_name = "app_id", lbl_name = "name",
    groups = list(
      "Genre" = list(
        from = "CROSS JOIN LATERAL unnest(t.genres) AS gn(genre)",
        expr = "gn.genre", by = "n"),
      "Release year" = list(
        from = "",
        expr = "EXTRACT(YEAR FROM t.release_date)::int::text", by = "grp"),
      "Free / paid" = list(
        from = "",
        expr = "CASE WHEN t.is_free THEN 'Free' WHEN NOT t.is_free THEN 'Paid' END",
        by = "n")
    ),
    vars = list(
      price_usd =
        list(label = "Price (USD)",
             value = "t.price_usd",
             valid = "t.price_usd >= 0"),
      metacritic_score =
        list(label = "Metacritic score",
             value = "t.metacritic_score",
             valid = "t.metacritic_score BETWEEN 0 AND 100"),
      total_achievements =
        list(label = "Total achievements",
             value = "t.total_achievements",
             valid = "t.total_achievements >= 0"),
      recommendations =
        list(label = "Recommendations",
             value = "t.recommendations",
             valid = "t.recommendations >= 0"),
      owners_min =
        list(label = "Owners (minimum)",
             value = "t.owners_min",
             valid = "t.owners_min >= 0"),
      owners_max =
        list(label = "Owners (maximum)",
             value = "t.owners_max",
             valid = "t.owners_max >= 0"),
      positive_reviews =
        list(label = "Positive reviews",
             value = "t.positive_reviews",
             valid = "t.positive_reviews >= 0"),
      negative_reviews =
        list(label = "Negative reviews",
             value = "t.negative_reviews",
             valid = "t.negative_reviews >= 0"),
      total_reviews = 
        list(label = "Total reviews",
             value = "t.total_reviews",
             valid = "t.total_reviews >= 0"),
      approval_rate = 
        list(label = "Approval rate (%)",
             value = "t.approval_rate",
             valid = "t.approval_rate BETWEEN 0 AND 100"),
      ram_minimum_gb =
        list(label = "Minimum RAM (GB)",
             value = "t.ram_minimum_gb",
             valid = "t.ram_minimum_gb > 0"),
      ram_recommended_gb =
        list(label = "Recommended RAM (GB)",
             value = "t.ram_recommended_gb",
             valid = "t.ram_recommended_gb > 0"),
      storage_minimum_gb =
        list(label = "Minimum storage (GB)",
             value = "t.storage_minimum_gb",
             valid = "t.storage_minimum_gb > 0"),
      storage_recommended_gb =
        list(label = "Recommended storage (GB)",
             value = "t.storage_recommended_gb",
             valid = "t.storage_recommended_gb > 0")
    )
  ),

  # users 
  users = list(
    label = "users",
    from = "users t", id = "t.steam_id", lbl = "t.persona_name",
    id_name = "steam_id", lbl_name = "persona_name",
    groups = list(
      "Country (country_code)" = list(from = "", expr = "t.country_code", by = "n")
    ),
    vars = list(
      account_age_days = list(
        label = "Account age (days)",
        value = "EXTRACT(EPOCH FROM (now() - t.account_created)) / 86400.0",
        valid = "t.account_created <= now()"),
      games_owned = list(
        label = "Library games (count)",
        value = "t.n",
        from  = "(SELECT u.steam_id, u.persona_name, u.country_code, g.n
                  FROM (SELECT steam_id, COUNT(*) AS n FROM user_games GROUP BY steam_id) g
                  JOIN users u ON u.steam_id = g.steam_id) t"),
      achievements_unlocked = list(
        label = "Unlocked achievements (count)",
        value = "t.n",
        from  = "(SELECT u.steam_id, u.persona_name, u.country_code, a.n
                  FROM (SELECT steam_id, COUNT(*) AS n FROM user_achievements GROUP BY steam_id) a
                  JOIN users u ON u.steam_id = a.steam_id) t")
    )
  ),

  # user_games
  user_games = list(
    label = "user_games",
    from = "user_games t", id = "t.steam_id", lbl = "t.app_id",
    id_name = "steam_id", lbl_name = "app_id",
    groups = list(),
    vars = list(
      playtime_forever =
        list(label = "Total playtime (min)",
             value = "t.playtime_forever",
             valid = "t.playtime_forever >= 0"),
      playtime_2weeks  =
        list(label = "Playtime, last 2 weeks (min)",
             value = "t.playtime_2weeks",
             valid = "t.playtime_2weeks BETWEEN 0 AND 20160")
    )
  ),

  # achievements
  achievements = list(
    label = "achievements",
    from = "achievements t", id = "t.app_id", lbl = "COALESCE(t.display_name, t.achievement_key)",
    id_name = "app_id", lbl_name = "achievement",
    groups = list(),
    vars = list(
      global_unlock_pct = 
        list(label = "Global unlock %", 
             value = "t.global_unlock_pct", 
             valid = "t.global_unlock_pct BETWEEN 0 AND 100")
    )
  ),

  # user_achievements
  user_achievements = list(
    label = "user_achievements",
    from = "user_achievements t", id = "t.steam_id", lbl = "t.achievement_key",
    id_name = "steam_id", lbl_name = "achievement_key",
    groups = list(),
    vars = list(
      achievements_per_user_game = list(
        label = "Achievements per user and game (count)",
        value = "t.n",
        from  = "(SELECT steam_id, app_id, COUNT(*) AS n FROM user_achievements GROUP BY steam_id, app_id) t",
        lbl   = "t.app_id", lbl_name = "app_id"),
      unlock_year = list(
        label = "Unlock year",
        value = "EXTRACT(YEAR FROM t.unlock_time)",
        valid = "t.unlock_time BETWEEN DATE '2003-09-12' AND CURRENT_DATE")
    )
  )
)

# Flattened: one entry per variable, key "table.variable"
outliers_vars <- list()
for (tn in names(outliers_tables)) {
  tb <- outliers_tables[[tn]]
  for (vn in names(tb$vars)) {
    v <- tb$vars[[vn]]
    outliers_vars[[paste0(tn, ".", vn)]] <- list(
      key      = paste0(tn, ".", vn),
      table    = tn,
      name     = vn,
      label    = v$label,
      value    = v$value,
      valid    = outliers_or(v$valid, "TRUE"),
      from     = outliers_or(v$from,  tb$from),
      id       = outliers_or(v$id,    tb$id),
      lbl      = outliers_or(v$lbl,   tb$lbl),
      id_name  = outliers_or(v$id_name,  tb$id_name),
      lbl_name = outliers_or(v$lbl_name, tb$lbl_name)
    )
  }
}

outliers_table_choices <- setNames(
  names(outliers_tables),
  vapply(outliers_tables, function(x) x$label, character(1))
)

outliers_var_choices <- function(table) {
  keys <- names(Filter(function(v) v$table == table, outliers_vars))
  setNames(keys, vapply(keys, function(k) {
    sprintf("%s", outliers_vars[[k]]$label)
  }, character(1)))
}

# Query execution
outliers_run <- function(sql) {
  tryCatch(
    DBI::dbGetQuery(pool, sql),
    error = function(e) {
      msg <- substr(conditionMessage(e), 1, 300)
      shiny::validate(shiny::need(FALSE, paste("Query error:", msg)))
    }
  )
}

# SQL construction
outliers_sql_num <- function(x) {
  sprintf("(%s)::float8", format(x, digits = 15, scientific = FALSE, trim = TRUE))
}

# Condition "is outlier" / "is inside" on column v
outliers_sql_out <- function(lim, col = "v") {
  if (!isTRUE(lim$ok)) return("FALSE")
  sprintf("(%s < %s OR %s > %s)", col, outliers_sql_num(lim$lo), col, outliers_sql_num(lim$hi))
}
outliers_sql_in <- function(lim, col = "v") {
  if (!isTRUE(lim$ok)) return("TRUE")
  sprintf("(%s >= %s AND %s <= %s)", col, outliers_sql_num(lim$lo), col, outliers_sql_num(lim$hi))
}

# CTE `base`: one row per analyzable record.
#   id, lbl : record identification
#   raw     : original value
#   v       : analyzed value (original or log10)
#   grp     : (optional) group
# `opts` is a list with: valid, zeros, log
outliers_base_sql <- function(var, opts, group = NULL) {
  conds <- sprintf("(%s) IS NOT NULL", var$value)
  if (isTRUE(opts$valid)) conds <- c(conds, sprintf("(%s)", var$valid))
  if (isTRUE(opts$zeros)) conds <- c(conds, sprintf("(%s) <> 0", var$value))
  if (isTRUE(opts$log))   conds <- c(conds, sprintf("(%s) > 0", var$value))

  raw <- sprintf("(%s)::float8", var$value)
  v   <- if (isTRUE(opts$log)) sprintf("log(%s)", raw) else raw

  extra_from <- if (!is.null(group)) group$from else ""
  grp_col    <- if (!is.null(group)) sprintf(", (%s) AS grp", group$expr) else ""

  sprintf(
    "base AS (SELECT (%s)::text AS id, (%s)::text AS lbl, %s AS raw, %s AS v%s FROM %s %s WHERE %s)",
    var$id, var$lbl, raw, v, grp_col, var$from, extra_from, paste(conds, collapse = " AND ")
  )
}

# Global statistics
outliers_stats_sql <- function(base) {
  sprintf("
WITH %s,
s AS (
  SELECT COUNT(*)::float8 AS n, MIN(v) AS vmin, MAX(v) AS vmax,
         AVG(v) AS mean, STDDEV_SAMP(v) AS sd,
         percentile_cont(0.01) WITHIN GROUP (ORDER BY v) AS p01,
         percentile_cont(0.25) WITHIN GROUP (ORDER BY v) AS q1,
         percentile_cont(0.50) WITHIN GROUP (ORDER BY v) AS med,
         percentile_cont(0.75) WITHIN GROUP (ORDER BY v) AS q3,
         percentile_cont(0.99) WITHIN GROUP (ORDER BY v) AS p99
  FROM base
)
SELECT s.*,
  (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY ABS(b.v - s.med)) FROM base b) AS mad,
  (SELECT AVG(POWER(b.v - s.mean, 3)) FROM base b) / NULLIF(POWER(s.sd, 3), 0)       AS skew
FROM s", base)
}

# Limits by method
# Returns lo/hi (outlier limits), ext_lo/ext_hi ("extreme" limits) and scale.
# Extreme = beyond the limit by other scale
outliers_limits <- function(st, method, k) {
  c_lo <- c_hi <- scale <- NA_real_
  if (method == "iqr") { c_lo <- st$q1;   c_hi <- st$q3;   scale <- st$q3 - st$q1 }
  if (method == "z")   { c_lo <- st$mean; c_hi <- st$mean; scale <- st$sd }
  if (method == "mad") { c_lo <- st$med;  c_hi <- st$med;  scale <- st$mad / 0.6745 }

  ok <- length(scale) == 1 && !is.na(scale) && scale > 0
  reason <- if (ok) NULL else switch(
    method,
    iqr = "The IQR is 0 (more than half of the data have the same value), 
      so the IQR method cannot separate outliers. Enable 
      \u00abExclude zeros\u00bb or try another method.",

    z   = "The standard deviation is 0 or cannot be calculated with this data.",

    mad = "The MAD is 0 (more than half of the data equal the median), 
      so the modified Z is not applicable. Enable 
      \u00abExclude zeros\u00bb or try IQR."
  )

  list(
    ok = ok, method = method, k = k, reason = reason,
    scale  = if (ok) scale else NA_real_,
    lo     = if (ok) c_lo - k * scale else NA_real_,
    hi     = if (ok) c_hi + k * scale else NA_real_,
    ext_lo = if (ok) c_lo - 2 * k * scale else NA_real_,
    ext_hi = if (ok) c_hi + 2 * k * scale else NA_real_
  )
}

# Counts with current limits + whisker extremes (non-outliers)
outliers_counts_sql <- function(base, lim) {
  if (!lim$ok) {
    return(sprintf("WITH %s SELECT 0::float8 AS n_low, 0::float8 AS n_high, 0::float8 AS n_ext,
                    MIN(v) AS wmin, MAX(v) AS wmax FROM base", base))
  }
  sprintf("
WITH %s
SELECT (COUNT(*) FILTER (WHERE v < %s))::float8 AS n_low,
       (COUNT(*) FILTER (WHERE v > %s))::float8 AS n_high,
       (COUNT(*) FILTER (WHERE v < %s OR v > %s))::float8 AS n_ext,
       MIN(v) FILTER (WHERE %s) AS wmin,
       MAX(v) FILTER (WHERE %s) AS wmax
FROM base",
    base,
    outliers_sql_num(lim$lo), outliers_sql_num(lim$hi),
    outliers_sql_num(lim$ext_lo), outliers_sql_num(lim$ext_hi),
    outliers_sql_in(lim), outliers_sql_in(lim))
}

outliers_hist_sql <- function(base, lo, hi, nb) {
  sprintf("
WITH %s
SELECT LEAST(width_bucket(v, %s, %s, %d), %d) AS b, COUNT(*)::float8 AS n
FROM base
WHERE v >= %s AND v <= %s
GROUP BY 1 ORDER BY 1",
    base, outliers_sql_num(lo), outliers_sql_num(hi), nb, nb,
    outliers_sql_num(lo), outliers_sql_num(hi))
}

outliers_sample_sql <- function(base, lim, n) {
  sprintf("WITH %s SELECT v FROM base WHERE %s ORDER BY random() LIMIT %d",
          base, outliers_sql_out(lim), as.integer(n))
}

outliers_rows_sql <- function(base, lim, cap) {
  sprintf("
WITH %s
SELECT id, lbl, raw AS value, v, (v < %s) AS low,
       (CASE WHEN v < %s THEN %s - v ELSE v - %s END) AS dist
FROM base
WHERE %s
ORDER BY dist DESC
LIMIT %d",
    base,
    outliers_sql_num(lim$lo),
    outliers_sql_num(lim$lo), outliers_sql_num(lim$lo), outliers_sql_num(lim$hi),
    outliers_sql_out(lim), as.integer(cap))
}

# All three methods at once: how many records fall into each combination
outliers_compare_sql <- function(base, lims) {
  sprintf("
WITH %s
SELECT %s AS iqr, %s AS z, %s AS mad, COUNT(*)::float8 AS n
FROM base
GROUP BY 1, 2, 3",
    base,
    outliers_sql_out(lims$iqr), outliers_sql_out(lims$z), outliers_sql_out(lims$mad))
}

# Quartiles by group + how many outliers are in each
outliers_group_sql <- function(base, lim, group) {
  order_sql <- if (identical(group$by, "grp")) "grp DESC" else "n DESC"
  sprintf("
WITH %s
SELECT grp, COUNT(*)::float8 AS n, MIN(v) AS vmin,
       percentile_cont(0.25) WITHIN GROUP (ORDER BY v) AS q1,
       percentile_cont(0.50) WITHIN GROUP (ORDER BY v) AS med,
       percentile_cont(0.75) WITHIN GROUP (ORDER BY v) AS q3,
       MAX(v) AS vmax,
       (COUNT(*) FILTER (WHERE %s))::float8 AS n_out
FROM base
WHERE grp IS NOT NULL
GROUP BY grp
HAVING COUNT(*) >= %d
ORDER BY %s
LIMIT %d",
    base, outliers_sql_out(lim), outliers_min_group_n, order_sql, outliers_max_groups)
}