# Bivariate explorer + correlation matrix

# Data comes from the level views created in eda/sql/002_levels.sql:
#   game          = mv_level_game
#   user          = mv_level_user
#   usergame      = mv_level_usergame_sample
#   achievement   = mv_level_achievement_sample


library(shiny)
library(bslib)
library(bsicons)
library(DBI)
library(pool)
library(dplyr)
library(ggplot2)
library(plotly)
library(DT)
library(htmlwidgets)

source("R/correlation/correlation_levels.R")

# Constants
correlation_max_levels <- 15L # max categories shown
correlation_color_levels <- 8L
correlation_max_points <- 5000L # max points drawn in a scatter plot
correlation_density_threshold <- 5000L
correlation_min_pair_n <- 30L # minimum rows in common to report a correlation
correlation_max_matrix_vars <- 30L      # max variables in the matrix
correlation_level_cap <- 200000L  # max rows fetched from small levels
correlation_sparse_cap <- 100000L  # max rows fetched with sparse data
correlation_collinearity_limit <- 0.9
correlation_year_min <- 1990L
correlation_year_max <- as.integer(format(Sys.Date(), "%Y"))

correlation_sample_choices <- c(
  "10,000" = 10000, "20,000" = 20000, "50,000" = 50000,
  "100,000" = 100000, "200,000" = 200000
)

correlation_level_choices <- c(
  "Game" = "game",
  "User" = "user",
  "User-Game" = "usergame",
  "Achievement" = "achievement"
)

# Flatten defaults: every variable gets its `name` and a SQL expression
correlation_vars <- lapply(correlation_levels, function(cfg) {
  vars <- cfg$vars
  for (nm in names(vars)) {
    vars[[nm]]$name <- nm
    if (is.null(vars[[nm]]$expr)) {
      vars[[nm]]$expr <- if (vars[[nm]]$type == "num") nm else sprintf("(%s)::text", nm)
    }
  }
  vars
})

# Variable names of a level, optionally filtered by type
correlation_var_names <- function(level, type = NULL) {
  vars <- correlation_vars[[level]]
  if (!is.null(type)) vars <- Filter(function(v) v$type == type, vars)
  names(vars)
}

# Grouped choices for selectInput (numeric / categorical)
correlation_var_choices <- function(level, types = c("num", "cat")) {
  vars <- correlation_vars[[level]]
  out <- list()
  for (tp in types) {
    sel <- Filter(function(v) v$type == tp, vars)
    if (length(sel) == 0) next
    labels <- vapply(sel, function(v) sprintf("%s", v$name), character(1))
    group_name <- if (tp == "num") "Numeric" else "Categorical"
    out[[group_name]] <- stats::setNames(names(sel), unname(labels))
  }
  out
}

# Structural pairs
# Pairs where one variable is computed from the other.
correlation_structural_pairs <- data.frame(
  a = c("positive_reviews", "negative_reviews", "positive_reviews", "negative_reviews",
        "total_reviews", "owners_min", "total_achievements", "total_achievements",
        "achievements_unlocked", "achievements_unlocked", "account_year",
        "n_achievements_defined", "avg_global_unlock_pct"),
  b = c("total_reviews", "total_reviews", "approval_rate", "approval_rate",
        "approval_rate", "owners_max", "n_achievements_defined", "total_achievements",
        "pct_completed", "avg_pct_completed", "account_age_days",
        "total_achievements", "min_global_unlock_pct"),
  stringsAsFactors = FALSE
)
correlation_pair_key <- function(a, b) paste(pmin(a, b), pmax(a, b), sep = "|")
correlation_structural_keys <- correlation_pair_key(
  correlation_structural_pairs$a, correlation_structural_pairs$b
)
correlation_is_structural <- function(a, b) {
  correlation_pair_key(a, b) %in% correlation_structural_keys
}

# General helpers
correlation_fmt <- function(x) {
  vapply(x, function(z) {
    if (is.null(z) || is.na(z)) "-" else format(round(z), big.mark = ",", scientific = FALSE, trim = TRUE)
  }, character(1))
}

correlation_fmt_p <- function(p) {
  if (is.null(p) || is.na(p)) return("n/a")
  if (p < 1e-16) return("< 1e-16")
  formatC(p, format = "g", digits = 3)
}

correlation_quote <- function(values) {
  paste0("'", gsub("'", "''", values, fixed = TRUE), "'", collapse = ", ")
}

correlation_run <- function(sql, params = NULL) {
  tryCatch(
    if (is.null(params)) DBI::dbGetQuery(pool, sql) else DBI::dbGetQuery(pool, sql, params = params),
    error = function(e) {
      msg <- substr(conditionMessage(e), 1, 300)
      shiny::validate(shiny::need(FALSE, paste("Error on query:", msg)))
    }
  )
}

# Strength labels for r and Cramer's V
correlation_strength <- function(x) {
  x <- abs(x)
  if (is.na(x)) "n/a"
  else if (x < 0.1) "negligible"
  else if (x < 0.3) "weak"
  else if (x < 0.5) "moderate"
  else if (x < 0.7) "strong"
  else "very strong"
}

# Epsilon-squared (Kruskal-Wallis effect size)
correlation_effect_label <- function(eps2) {
  if (is.na(eps2)) "n/a"
  else if (eps2 < 0.01) "negligible"
  else if (eps2 < 0.08) "small"
  else if (eps2 < 0.26) "medium"
  else "large"
}

# Keep the top-k most frequent values and lump the rest into Others
correlation_lump <- function(x, k) {
  x <- ifelse(is.na(x), "No data", x)
  top <- names(sort(table(x), decreasing = TRUE))
  top <- top[seq_len(min(k, length(top)))]
  ifelse(x %in% top, x, "Others")
}

# Tukey fences flag (used by "mark outliers")
correlation_iqr_flag <- function(v) {
  q <- stats::quantile(v, c(0.25, 0.75), na.rm = TRUE, names = FALSE)
  iqr <- q[2] - q[1]
  if (!is.finite(iqr) || iqr <= 0) return(rep(FALSE, length(v)))
  !is.na(v) & (v < q[1] - 1.5 * iqr | v > q[2] + 1.5 * iqr)
}

# SQL builders

# Numeric variable -> SQL expression. Out-of-range / zero / non-positive values
correlation_value_sql <- function(var, valid = TRUE, zeros = FALSE, positive = FALSE) {
  if (var$type == "cat") return(var$expr)
  e <- sprintf("(%s)::float8", var$expr)
  conds <- character()
  if (isTRUE(valid) && !is.null(var$valid)) conds <- c(conds, sprintf("(%s)", var$valid))
  if (isTRUE(zeros))    conds <- c(conds, sprintf("%s <> 0", e))
  if (isTRUE(positive)) conds <- c(conds, sprintf("%s > 0", e))
  if (length(conds)) sprintf("CASE WHEN %s THEN %s END", paste(conds, collapse = " AND "), e) else e
}

# Row filters from the sidebar (only for levels that carry game columns)
correlation_filter_conds <- function(cfg, filters) {
  conds <- character()
  if (!isTRUE(cfg$has_game_cols) || is.null(filters)) return(conds)
  if (identical(filters$free, "free")) conds <- c(conds, "is_free IS TRUE")
  if (identical(filters$free, "paid")) conds <- c(conds, "is_free IS FALSE")
  if (isTRUE(filters$years_active)) {
    conds <- c(conds, sprintf("release_year BETWEEN %d AND %d",
                              as.integer(filters$years[1]), as.integer(filters$years[2])))
  }
  conds
}

correlation_where <- function(conds) {
  if (length(conds)) paste("WHERE", paste(conds, collapse = " AND ")) else ""
}

# Most frequent categories of a categorical variable
correlation_top_cats_sql <- function(level, var, filters, k) {
  cfg <- correlation_levels[[level]]
  sprintf(
    "SELECT val, COUNT(*)::float8 AS n
     FROM (SELECT %s AS val FROM %s %s) s
     WHERE val IS NOT NULL
     GROUP BY val ORDER BY n DESC LIMIT %d",
    var$expr, cfg$view, correlation_where(correlation_filter_conds(cfg, filters)), as.integer(k)
  )
}

# Bivariate explorer
correlation_explorer_sql <- function(level, x, y, color, opts, filters,
                                     cat_filters, n, count_only = FALSE) {
  cfg <- correlation_levels[[level]]

  inner_cols <- c(
    sprintf("%s AS x", correlation_value_sql(
      x, opts$valid, opts$zeros, opts$log_x
    )),
    sprintf("%s AS y", correlation_value_sql(
      y, opts$valid, opts$zeros, opts$log_y
    ))
  )
  if (!is.null(color))  inner_cols <- c(inner_cols, sprintf("%s AS clr", color$expr))
  if (cfg$has_rnd)      inner_cols <- c(inner_cols, "rnd")
  if (cfg$has_uniform)  inner_cols <- c(inner_cols, "in_uniform")

  inner <- sprintf("SELECT %s FROM %s %s", paste(inner_cols, collapse = ", "), cfg$view,
                   correlation_where(correlation_filter_conds(cfg, filters)))

  outer_conds <- c("x IS NOT NULL", "y IS NOT NULL")
  if (!is.null(cat_filters$x)) outer_conds <- c(outer_conds, sprintf("x IN (%s)", correlation_quote(cat_filters$x)))
  if (!is.null(cat_filters$y)) outer_conds <- c(outer_conds, sprintf("y IN (%s)", correlation_quote(cat_filters$y)))

  # Without achievement variables the uniform sample flag keeps the sample unbiased
  uses_sparse <- isTRUE(x$sparse) || isTRUE(y$sparse) || isTRUE(color$sparse)
  if (cfg$has_uniform && !uses_sparse) outer_conds <- c(outer_conds, "in_uniform")

  where <- paste("WHERE", paste(outer_conds, collapse = " AND "))
  if (count_only) return(sprintf("SELECT COUNT(*)::float8 AS n FROM (%s) s %s", inner, where))

  select_cols <- paste(c("x", "y", if (!is.null(color)) "clr"), collapse = ", ")
  order_sql <- if (cfg$has_rnd) "ORDER BY rnd" else "ORDER BY random()"
  sprintf("SELECT %s FROM (%s) s %s %s LIMIT %d", select_cols, inner, where, order_sql, as.integer(n))
}

# Correlation matrix: one column per numeric variable.
correlation_matrix_sql <- function(level, var_names, opts, filters, n) {
  cfg  <- correlation_levels[[level]]
  vars <- correlation_vars[[level]]

  select_cols <- paste(vapply(var_names, function(v) {
    sprintf("%s AS %s", correlation_value_sql(vars[[v]], opts$valid, opts$zeros, FALSE), v)
  }, character(1)), collapse = ", ")

  base_conds <- correlation_filter_conds(cfg, filters)
  build <- function(extra_conds, tail = "") {
    sprintf("SELECT %s FROM %s %s %s", select_cols, cfg$view,
            correlation_where(c(base_conds, extra_conds)), tail)
  }

  if (!cfg$has_rnd) return(build(character(), sprintf("LIMIT %d", correlation_level_cap)))

  sparse <- var_names[vapply(var_names, function(v) isTRUE(vars[[v]]$sparse), logical(1))]
  uniform_cond <- if (cfg$has_uniform) "in_uniform" else character()

  if (length(sparse) == 0) {
    return(build(uniform_cond, sprintf("ORDER BY rnd LIMIT %d", as.integer(n))))
  }

  has_sparse <- paste(sprintf("%s IS NOT NULL", vapply(sparse, function(v) vars[[v]]$expr, character(1))),
                      collapse = " OR ")
  part_a <- build(sprintf("(%s)", has_sparse), sprintf("LIMIT %d", correlation_sparse_cap))
  part_b <- build(c(sprintf("NOT (%s)", has_sparse), uniform_cond),
                  sprintf("ORDER BY rnd LIMIT %d", as.integer(n)))
  sprintf("(%s) UNION ALL (%s)", part_a, part_b)
}

# Statistics

# Numeric x numeric
correlation_stats_nn <- function(x, y, log_x, log_y) {
  xs <- if (log_x) log10(x) else x
  ys <- if (log_y) log10(y) else y
  ok <- is.finite(xs) & is.finite(ys)
  n <- sum(ok)
  if (n < 3 || stats::sd(xs[ok]) == 0 || stats::sd(ys[ok]) == 0) return(NULL)

  sp <- tryCatch(suppressWarnings(
    stats::cor.test(xs[ok], ys[ok], method = "spearman", exact = FALSE)
  ), error = function(e) NULL)
  pe <- tryCatch(suppressWarnings(
    stats::cor.test(xs[ok], ys[ok], method = "pearson")
  ), error = function(e) NULL)
  if (is.null(sp) || is.null(pe)) return(NULL)

  list(
    n = n,
    spearman = unname(sp$estimate), spearman_p = sp$p.value,
    pearson  = unname(pe$estimate), pearson_p  = pe$p.value,
    r2 = unname(pe$estimate)^2
  )
}

# Numeric x categorical (Kruskal-Wallis + epsilon-squared)
correlation_stats_nc <- function(value, group) {
  ok <- is.finite(value) & !is.na(group)
  value <- value[ok]
  group <- droplevels(factor(group[ok]))
  if (nlevels(group) < 2 || length(value) < 3) return(NULL)
  kt <- tryCatch(stats::kruskal.test(value ~ group), error = function(e) NULL)
  if (is.null(kt)) return(NULL)
  h <- unname(kt$statistic)
  n <- length(value)
  list(n = n, groups = nlevels(group), h = h, p = kt$p.value,
       eps2 = h * (n + 1) / (n^2 - 1))
}

# Categorical x categorical (chi-squared + Cramer's V)
correlation_stats_cc <- function(x, y) {
  tab <- table(x, y)
  if (nrow(tab) < 2 || ncol(tab) < 2) return(NULL)
  ct <- tryCatch(suppressWarnings(stats::chisq.test(tab)), error = function(e) NULL)
  if (is.null(ct)) return(NULL)
  n <- sum(tab)
  list(n = n, chi2 = unname(ct$statistic), df = unname(ct$parameter), p = ct$p.value,
       v = sqrt(unname(ct$statistic) / (n * min(nrow(tab) - 1, ncol(tab) - 1))),
       table = tab)
}

# Matrix helpers

# df: numeric columns. Returns r, pairwise n and the columns that were dropped.
correlation_compute_matrix <- function(df, method, use_log, min_n) {
  m <- as.matrix(df)
  storage.mode(m) <- "double"
  if (use_log) {
    m <- apply(m, 2, function(v) ifelse(!is.na(v) & v > 0, log10(v), NA_real_))
  }
  usable <- apply(m, 2, function(v) {
    v <- v[!is.na(v)]
    length(v) >= min_n && length(unique(v)) > 1
  })
  dropped <- colnames(m)[!usable]
  m <- m[, usable, drop = FALSE]
  if (ncol(m) < 2) return(list(r = NULL, n = NULL, dropped = dropped))

  r <- suppressWarnings(stats::cor(m, use = "pairwise.complete.obs", method = method))
  n <- crossprod(1 * !is.na(m))
  r[n < min_n] <- NA_real_
  diag(r) <- 1
  list(r = r, n = n, dropped = dropped)
}

# Hierarchical clustering order (distance = 1 - |r|)
correlation_cluster_order <- function(r) {
  d <- r
  d[is.na(d)] <- 0
  stats::hclust(stats::as.dist(1 - abs(d)), method = "average")$order
}

# Upper-triangle pairs with strength labels and notes
correlation_pairs_table <- function(r, n, hide_structural) {
  idx <- which(upper.tri(r), arr.ind = TRUE)
  out <- data.frame(
    var_a = rownames(r)[idx[, 1]],
    var_b = colnames(r)[idx[, 2]],
    r = r[idx],
    n = n[idx],
    stringsAsFactors = FALSE
  )
  out <- out[!is.na(out$r), , drop = FALSE]
  if (nrow(out) == 0) return(out)

  structural <- correlation_is_structural(out$var_a, out$var_b)
  if (hide_structural) {
    out <- out[!structural, , drop = FALSE]
    structural <- structural[!structural]
  }
  if (nrow(out) == 0) return(out)

  out$strength <- vapply(out$r, correlation_strength, character(1))
  out$note <- ifelse(
    structural, "Structural relationship (derived)",
    ifelse(abs(out$r) >= correlation_collinearity_limit, "Possible multicollinearity", "")
  )
  out[order(-abs(out$r)), , drop = FALSE]
}

# Plot helpers

# Numeric x numeric: points (small n) or 2D density (large n), optional trend
correlation_plot_scatter <- function(df, x_label, y_label, log_x, log_y,
                                     mode, trend, mark_outliers) {
  df <- df[is.finite(df$x) & is.finite(df$y), , drop = FALSE]
  use_density <- mode == "density" ||
    (mode == "auto" && nrow(df) > correlation_density_threshold)
  has_color <- "clr" %in% names(df)

  g <- ggplot(df, aes(x = x, y = y))

  if (use_density) {
    g <- g + geom_bin2d(bins = 60) +
      scale_fill_viridis_c(name = "Observations")
  } else {
    pts <- if (nrow(df) > correlation_max_points) dplyr::slice_sample(df, n = correlation_max_points) else df
    g <- if (has_color) {
      g + geom_point(data = pts, aes(colour = clr), alpha = 0.5, size = 1) + labs(colour = NULL)
    } else {
      g + geom_point(data = pts, alpha = 0.4, size = 1, colour = "#4C78A8")
    }
  }

  if (mark_outliers) {
    xs <- if (log_x) log10(df$x) else df$x
    ys <- if (log_y) log10(df$y) else df$y
    flagged <- df[correlation_iqr_flag(xs) | correlation_iqr_flag(ys), , drop = FALSE]
    if (nrow(flagged) > 2000) flagged <- dplyr::slice_sample(flagged, n = 2000)
    if (nrow(flagged) > 0) {
      g <- g + geom_point(data = flagged, colour = "#E45756", size = 1.4, alpha = 0.8)
    }
  }

  if (trend == "lineal") {
    g <- g + geom_smooth(method = "lm", formula = y ~ x, se = FALSE, colour = "#222222", linewidth = 0.8)
  } else if (trend == "smooth") {
    g <- if (nrow(df) >= 1000) {
      g + geom_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), se = FALSE,
                      colour = "#222222", linewidth = 0.8)
    } else {
      g + geom_smooth(method = "loess", formula = y ~ x, se = FALSE,
                      colour = "#222222", linewidth = 0.8)
    }
  }

  g <- g + labs(x = x_label, y = y_label) + theme_minimal()
  if (log_x) g <- g + scale_x_log10()
  if (log_y) g <- g + scale_y_log10()
  g
}

# Numeric x categorical: one box per category (ordered by median)
correlation_plot_box <- function(df, value_label, group_label, log_value) {
  df$group <- stats::reorder(factor(df$group), df$value, FUN = stats::median)
  g <- ggplot(df, aes(x = group, y = value)) +
    geom_boxplot(fill = "#9ecae1", colour = "#3b6a8f", outlier.size = 0.8, outlier.alpha = 0.3) +
    coord_flip() +
    labs(x = group_label, y = value_label) +
    theme_minimal()
  if (log_value) g <- g + scale_y_log10()
  g
}

# Categorical x categorical: 100% stacked bars
correlation_plot_stacked <- function(df, x_label, y_label) {
  ggplot(df, aes(x = x, fill = y)) +
    geom_bar(position = "fill") +
    coord_flip() +
    scale_y_continuous(labels = function(v) paste0(round(100 * v), "%")) +
    labs(x = x_label, y = "Proportion", fill = y_label) +
    theme_minimal()
}

# Correlation heatmap. Clicking a cell sets the Shiny input `click_input_id`
# to list(x = <variable>, y = <variable>).
correlation_plot_heatmap <- function(r, n, click_input_id, show_values) {
  vars <- colnames(r)
  grid <- expand.grid(i = seq_along(vars), j = seq_along(vars))
  idx  <- cbind(grid$i, grid$j)

  hover <- matrix(
    sprintf("%s vs %s<br>r = %s<br>n = %s",
            vars[grid$i], vars[grid$j],
            ifelse(is.na(r[idx]), "n/a", sprintf("%.3f", r[idx])),
            format(n[idx], big.mark = ",", trim = TRUE)),
    nrow = length(vars)
  )

  p <- plotly::plot_ly(
    x = vars, y = vars, z = r, type = "heatmap",
    zmin = -1, zmax = 1, colors = c("#2166AC", "#F7F7F7", "#B2182B"),
    text = hover, hoverinfo = "text"
  ) %>%
    plotly::layout(
      xaxis = list(title = "", tickangle = -45, categoryorder = "array", categoryarray = vars),
      yaxis = list(title = "", autorange = "reversed", categoryorder = "array", categoryarray = vars)
    )

  if (show_values) {
    cells <- which(!is.na(r[idx]))
    ann <- lapply(cells, function(k) {
      val <- r[grid$i[k], grid$j[k]]
      list(x = vars[grid$j[k]], y = vars[grid$i[k]], text = sprintf("%.2f", val),
           showarrow = FALSE,
           font = list(size = 10, color = if (abs(val) > 0.6) "white" else "black"))
    })
    p <- plotly::layout(p, annotations = ann)
  }

  js <- sprintf(
    "function(el) {
       el.on('plotly_click', function(d) {
         if (!d || !d.points || !d.points.length) return;
         var pt = d.points[0];
         Shiny.setInputValue('%s', {x: pt.x, y: pt.y}, {priority: 'event'});
       });
     }", click_input_id)
  htmlwidgets::onRender(p, js)
}
