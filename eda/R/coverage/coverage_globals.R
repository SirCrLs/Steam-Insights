# Coverage & bias: constants, helpers and pure computations.
# Reads mv_level_user, mv_level_game, user_games and eda_refresh_log.

library(shiny)
library(bslib)
library(bsicons)
library(DBI)
library(pool)
library(dplyr)
library(ggplot2)
library(plotly)
library(DT)

cov_bias_note <- paste(
  "Users were collected with a friends-of-friends crawl (snowball sample): shares and averages may be biased,",
  "while relationships between variables are more robust but not immune.",
  "Margins of error assume independent observations, so they are optimistic.")

cov_user_vars <- c("games_owned", "total_playtime", "avg_playtime", "pct_games_played", "account_age_days")
cov_cols <- c(all = "#4C78A8", ok = "#4C78A8", low = "#F2B134", insufficient = "#E45756",
              over = "#E45756", under = "#F2B134", check = "#E45756")

# Game-level groupings: SQL expressions over mv_level_game, shared by the reliability tab and the
# representation index. Band cut-offs live in these CASE expressions.
cov_owners <- "(owners_min + owners_max) / 2.0"
cov_game_groups <- c(
  "Genre" = "primary_genre",
  "Release year" = "release_year::text",
  "Owners tier" = sprintf("CASE WHEN owners_max IS NULL THEN NULL WHEN %1$s < 20000 THEN '<20k'
    WHEN %1$s < 200000 THEN '20k-200k' WHEN %1$s < 2000000 THEN '200k-2M' ELSE '2M+' END", cov_owners),
  "Free vs paid" = "CASE WHEN is_free THEN 'Free' WHEN NOT is_free THEN 'Paid' END",
  "Price band" = "CASE WHEN is_free OR price_usd = 0 THEN 'Free' WHEN price_usd IS NULL THEN NULL
    WHEN price_usd < 5 THEN '<$5' WHEN price_usd < 15 THEN '$5-15' WHEN price_usd < 30 THEN '$15-30' ELSE '$30+' END",
  "Platform support" = "CASE WHEN is_on_windows IS NULL THEN NULL
    WHEN is_on_windows AND is_on_mac AND is_on_linux THEN 'All three' WHEN is_on_windows AND is_on_mac THEN 'Windows + Mac'
    WHEN is_on_windows AND is_on_linux THEN 'Windows + Linux' WHEN is_on_windows THEN 'Windows only' ELSE 'No Windows' END",
  "Age rating" = "rating",
  "Metacritic band" = "CASE WHEN metacritic_score IS NULL OR metacritic_score = 0 THEN 'No score'
    WHEN metacritic_score < 50 THEN 'Below 50' WHEN metacritic_score < 75 THEN '50-74' ELSE '75+' END")

# Reliability tab: one query per grouping, all returning grp, unit, n, user_games
cov_rel_sql <- c(
  "Country" = "SELECT country_code AS grp, 'users' AS unit, COUNT(*)::float8 AS n, SUM(games_owned)::float8 AS user_games
               FROM mv_level_user WHERE country_code IS NOT NULL GROUP BY 1",
  "Library size" = "SELECT CASE WHEN games_owned < 10 THEN '1-9' WHEN games_owned < 50 THEN '10-49'
                    WHEN games_owned < 200 THEN '50-199' ELSE '200+' END AS grp, 'users' AS unit,
                    COUNT(*)::float8 AS n, SUM(games_owned)::float8 AS user_games
                    FROM mv_level_user WHERE games_owned > 0 GROUP BY 1",
  sapply(cov_game_groups, function(e) sprintf(
    "SELECT (%s) AS grp, 'games' AS unit, COUNT(*)::float8 AS n, SUM(n_users)::float8 AS user_games
     FROM mv_level_game WHERE (%s) IS NOT NULL GROUP BY 1", e, e)))

cov_q <- function(sql) tryCatch(
  DBI::dbGetQuery(pool, sql),
  error = function(e) validate(need(FALSE, paste("Query error:", substr(conditionMessage(e), 1, 200)))))

cov_pct <- function(x) sprintf("%.1f%%", 100 * x)
cov_num <- function(x) format(x, big.mark = ",", trim = TRUE, scientific = FALSE)

# Nested funnel: each step also requires all previous ones
cov_funnel <- function(u) {
  steps <- list("All users" = rep(TRUE, nrow(u)), "Public profile" = u$is_public %in% TRUE,
                "Public games" = u$has_public_games %in% TRUE, "Has games" = (u$games_owned > 0) %in% TRUE,
                "Has achievement data" = u$has_ach_data %in% TRUE)
  data.frame(label = names(steps), value = sapply(Reduce(`&`, steps, accumulate = TRUE), sum))
}

# Users with achievement data vs the rest: standardized mean difference + KS test per variable,
# plus country mix (Cramer's V). Flagged when |effect| > 0.1 and P < 0.05.
cov_compare <- function(u) {
  g <- u$has_ach_data %in% TRUE
  out <- do.call(rbind, lapply(cov_user_vars, function(v) {
    a <- na.omit(u[g, v]); b <- na.omit(u[!g, v])
    data.frame(Variable = v, "Ach. users" = mean(a), Others = mean(b), check.names = FALSE,
               Effect = (mean(a) - mean(b)) / sqrt((var(a) + var(b)) / 2),
               P = suppressWarnings(ks.test(a, b)$p.value))
  }))
  top <- names(sort(table(u$country_code), decreasing = TRUE))[1:10]
  ct <- table(ifelse(u$country_code %in% top, u$country_code, "Other"), g)
  chi <- suppressWarnings(chisq.test(ct, simulate.p.value = TRUE, B = 2000))
  out <- rbind(out, data.frame(Variable = "country (Cramer's V)", "Ach. users" = NA, Others = NA, check.names = FALSE,
                               Effect = sqrt(unname(chi$statistic) / (sum(ct) * (min(dim(ct)) - 1))), P = chi$p.value))
  out$Flag <- ifelse(abs(out$Effect) > 0.1 & out$P < 0.05, "check", "ok")
  out
}

# Representation index = share of the user sample / share of SteamSpy owners (1 = proportional)
cov_index <- function(d, col, top = 25, min_games = 30) {
  d %>% filter(!is.na(.data[[col]]), owners > 0) %>%
    group_by(label = as.character(.data[[col]])) %>%
    summarise(games = n(), s = sum(n_users), o = sum(owners), .groups = "drop") %>%
    filter(games >= min_games) %>%
    mutate(value = pmax((s / sum(s)) / (o / sum(o)), 0.01),
           flag = ifelse(value > 2, "over", ifelse(value < 0.5, "under", "ok"))) %>%
    slice_max(o, n = top)
}

# Margin of error for a proportion (p = 0.5), in percentage points, and a reliability flag
cov_reliability <- function(d, min_n) {
  d$moe <- 98 / sqrt(d$n)
  d$flag <- ifelse(d$n >= min_n, "ok", ifelse(d$n >= min_n / 3, "low", "insufficient"))
  d[order(-d$n), ]
}

# Generic horizontal bar chart. d: label, value, optional flag. ref: dashed reference lines.
cov_bar <- function(d, sort = TRUE, log = FALSE, ref = NULL) {
  if (is.null(d$flag)) d$flag <- "all"
  d$label <- if (sort) reorder(d$label, d$value) else factor(d$label, levels = rev(d$label))
  g <- ggplot(d, aes(label, value, fill = flag)) +
    geom_col(show.legend = length(unique(d$flag)) > 1) +
    geom_text(aes(label = cov_num(round(value, 2))), hjust = -0.1, size = 3) +
    coord_flip() + scale_fill_manual(values = cov_cols) + labs(x = NULL, y = NULL, fill = NULL) + theme_minimal() +
    (if (log) scale_y_log10(expand = expansion(mult = c(0, 0.25))) else scale_y_continuous(expand = expansion(mult = c(0, 0.25))))
  if (!is.null(ref)) g <- g + geom_hline(yintercept = ref, linetype = "dashed")
  g
}
