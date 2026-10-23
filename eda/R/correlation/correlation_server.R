# Server logic (module: correlation_server("correlation")).
#
# Heavy work stays in PostgreSQL (counts, sampling, filtering); R receives at
# most a sample of rows and computes the statistics on it.

correlation_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    fmt <- correlation_fmt
    jump <- reactiveVal(NULL)

    current_filters <- function() {
      years <- as.integer(input$filter_years)
      list(
        free         = input$filter_free,
        years        = years,
        years_active = !identical(years, c(correlation_year_min, correlation_year_max))
      )
    }
    current_opts <- function() {
      list(valid = isTRUE(input$opt_valid), zeros = isTRUE(input$opt_zeros))
    }

    observeEvent(input$level, {
      lv   <- input$level
      nums <- correlation_var_names(lv, "num")
      updateSelectInput(session, "var_x", choices = correlation_var_choices(lv),
                        selected = nums[1])
      updateSelectInput(session, "var_y", choices = correlation_var_choices(lv),
                        selected = nums[min(2, length(nums))])
      updateSelectInput(session, "var_color",
                        choices = c(list("(ninguno)" = ""),
                                    correlation_var_choices(lv, "cat")),
                        selected = "")
      updateSelectInput(session, "matrix_vars", 
                        choices = correlation_var_choices(lv, "num"),
                        selected = head(nums, correlation_max_matrix_vars))
    }, ignoreInit = TRUE)

    # Pressing "Apply" in the explorer discards any pending jump
    observeEvent(input$apply_explorer, jump(NULL), priority = 10, ignoreInit = TRUE)

    # Open a pair in the explorer tab
    open_pair <- function(x_name, y_name) {
      updateSelectInput(session, "var_x", selected = x_name)
      updateSelectInput(session, "var_y", selected = y_name)
      bslib::nav_select("tabs", "explorer", session = session)
    }

    # Coverage banner (rows per level, last refresh, achievement coverage)
    coverage <- reactive({
      cfg <- correlation_levels[[input$level]]
      ach_sql <- if (!is.null(cfg$ach_expr)) {
        sprintf(", (COUNT(*) FILTER (WHERE %s))::float8 AS n_ach", cfg$ach_expr)
      } else ""
      res <- correlation_run(sprintf("SELECT COUNT(*)::float8 AS n_total%s FROM %s", ach_sql, cfg$view))
      refreshed <- tryCatch(
        DBI::dbGetQuery(pool, "SELECT refreshed_at FROM eda_refresh_log WHERE view_name = $1",
                        params = list(cfg$view))$refreshed_at,
        error = function(e) NULL
      )
      list(
        n_total   = res$n_total,
        n_ach     = if ("n_ach" %in% names(res)) res$n_ach else NULL,
        refreshed = refreshed
      )
    })

    output$coverage <- renderUI({
      cv <- coverage()
      info <- sprintf("%s rows at this level", fmt(cv$n_total))
      if (length(cv$refreshed) == 1 && !is.na(cv$refreshed)) {
        info <- paste0(info, " | Updated data: ",
                       format(cv$refreshed, "%Y-%m-%d %H:%M"))
      }
      warn <- NULL
      if (!is.null(cv$n_ach) && cv$n_total > 0) {
        warn <- div(
          class = "alert alert-warning py-2",
          bs_icon("exclamation-triangle"), " ",
          sprintf("User achievement variables only exist in %s out of %s rows (%.2f %%):",
                  fmt(cv$n_ach), fmt(cv$n_total), 100 * cv$n_ach / cv$n_total),
          "the rest are unknown (NULL), not zero."
        )
      }
      tagList(div(class = "alert alert-info py-2", bs_icon("database"), " ", info), warn)
    })

    # 1. BIVARIATE EXPLORER
    explorer_params <- eventReactive(list(input$apply_explorer, jump()), {
      j <- jump()
      level  <- if (is.null(j)) input$level else j$level
      x_name <- if (is.null(j)) input$var_x else j$x
      y_name <- if (is.null(j)) input$var_y else j$y
      vars   <- correlation_vars[[level]]

      validate(
        need(x_name %in% names(vars) && y_name %in% names(vars),
             "The variables do not correspond to this level. Click Apply."),
        need(x_name != y_name, "Choose two different variables.")
      )

      x <- vars[[x_name]]
      y <- vars[[y_name]]

      clr_name <- input$var_color
      color <- if (!is.null(clr_name) &&
                     nzchar(clr_name) &&
                     clr_name %in% names(vars)) vars[[clr_name]] else NULL
      if (!(x$type == "num" && y$type == "num")) color <- NULL

      list(
        level = level, x = x, y = y, color = color,
        log_x = isTRUE(input$log_x) && x$type == "num",
        log_y = isTRUE(input$log_y) && y$type == "num",
        trend = input$trend,
        mode = input$scatter_mode,
        mark_outliers = isTRUE(input$mark_outliers),
        n = as.integer(input$explorer_n),
        opts = current_opts(),
        filters = current_filters()
      )
    }, ignoreNULL = FALSE)

    explorer_data <- reactive({
      p <- explorer_params()

      # Categorical variables: restrict to their most frequent categories
      both_cat <- p$x$type == "cat" && p$y$type == "cat"
      k <- if (both_cat) 10L else correlation_max_levels
      top_cats <- function(var) {
        correlation_run(correlation_top_cats_sql(p$level, var, p$filters, k))$val
      }
      cat_filters <- list()
      if (p$x$type == "cat") cat_filters$x <- top_cats(p$x)
      if (p$y$type == "cat") cat_filters$y <- top_cats(p$y)
      validate(need(
        !(p$x$type == "cat" && length(cat_filters$x) == 0) &&
          !(p$y$type == "cat" && length(cat_filters$y) == 0),
        "The categorical variable has no data with the current filters."
      ))

      sql_opts <- list(valid = p$opts$valid, zeros = p$opts$zeros,
                       log_x = p$log_x, log_y = p$log_y)

      n_total <- correlation_run(correlation_explorer_sql(
        p$level, p$x, p$y, p$color, sql_opts, p$filters, cat_filters, p$n, count_only = TRUE
      ))$n
      validate(need(n_total >= 10,
                    "There are not enough records with both variables at this level (with the current filters)."))

      df <- withProgress(
          message = "Querying data...",
          correlation_run(correlation_explorer_sql(
          p$level, p$x, p$y, p$color, sql_opts, p$filters, cat_filters, p$n
        ))
      )

      if (p$x$type == "num" && p$y$type == "num") {
        kind <- "nn"
        if (!is.null(p$color)) df$clr <- correlation_lump(df$clr, correlation_color_levels)
        value_var <- group_var <- NULL
        log_value <- FALSE
      } else if (p$x$type == "cat" && p$y$type == "cat") {
        kind <- "cc"
        df$x <- factor(df$x)
        df$y <- factor(df$y)
        value_var <- group_var <- NULL
        log_value <- FALSE
      } else {
        # Mixed pair: normalize to value (numeric) + group (categorical)
        kind <- "nc"
        if (p$x$type == "num") {
          value_var <- p$x; group_var <- p$y; log_value <- p$log_x
          df <- data.frame(value = df$x, group = df$y, stringsAsFactors = FALSE)
        } else {
          value_var <- p$y; group_var <- p$x; log_value <- p$log_y
          df <- data.frame(value = df$y, group = df$x, stringsAsFactors = FALSE)
        }
      }

      list(kind = kind, df = df, n_total = n_total, n_sample = nrow(df),
           value_var = value_var, group_var = group_var, log_value = log_value)
    })

    explorer_stats <- reactive({
      d <- explorer_data()
      p <- explorer_params()
      switch(
        d$kind,
        nn = correlation_stats_nn(d$df$x, d$df$y, p$log_x, p$log_y),
        nc = correlation_stats_nc(d$df$value, d$df$group),
        cc = correlation_stats_cc(d$df$x, d$df$y)
      )
    })

    output$explorer_alert <- renderUI({
      p <- explorer_params()
      alerts <- list()
      if (correlation_is_structural(p$x$name, p$y$name)) {
        alerts <- c(alerts, list(div(
          class = "alert alert-warning py-2", bs_icon("exclamation-triangle"), " ",
          "These variables are related by construction (one is derived from the other): ",
          "the correlation is trivial and not a finding."
        )))
      }
      if (isTRUE(p$x$sparse) || isTRUE(p$y$sparse)) {
        alerts <- c(alerts, list(div(
          class = "alert alert-warning py-2", bs_icon("info-circle"), " ",
          "One of the variables comes from scraped achievements: it only covers users with achievement data."
        )))
      }
      if (length(alerts)) tagList(alerts)
    })

    output$explorer_summary <- renderUI({
      d  <- explorer_data()
      st <- explorer_stats()
      validate(need(!is.null(st),
                    "Could not calculate statistics (constant or insufficient data)."))

      txt <- switch(
        d$kind,
        nn = sprintf(
          "Spearman rho = %.2f (%s, %s), p = %s * Pearson r = %.2f * R^2 = %.2f * n = %s",
          st$spearman, correlation_strength(st$spearman),
          if (st$spearman >= 0) "positive" else "negative",
          correlation_fmt_p(st$spearman_p), st$pearson, st$r2, fmt(st$n)
        ),
        nc = sprintf(
          "Kruskal-Wallis H = %.1f, p = %.4f * eps^2 = %.3f (%s effect) * %d groups * n = %s",
          st$h, correlation_fmt_p(st$p), st$eps2, correlation_effect_label(st$eps2),
          st$groups, fmt(st$n)
        ),
        cc = sprintf(
          "chi^2 = %.1f (df = %.0f), p = %.4f * Cramer's V = %.2f (%s) * n = %s",
          st$chi2, st$df, correlation_fmt_p(st$p), st$v, correlation_strength(st$v), fmt(st$n)
        )
      )
      div(class = "alert alert-secondary py-2", tags$strong(txt))
    })

    output$explorer_plot <- renderPlotly({
      d <- explorer_data()
      p <- explorer_params()
      g <- switch(
        d$kind,
        nn = correlation_plot_scatter(d$df, p$x$label, p$y$label, p$log_x, p$log_y,
                                      p$mode, p$trend, p$mark_outliers),
        nc = correlation_plot_box(d$df, d$value_var$label, d$group_var$label, d$log_value),
        cc = correlation_plot_stacked(d$df, p$x$label, p$y$label)
      )
      ggplotly(g)
    })

    output$explorer_stats_tbl <- renderDT({
      d  <- explorer_data()
      st <- explorer_stats()
      validate(need(!is.null(st), "No statistics to display."))

      if (d$kind == "nn") {
        tbl <- data.frame(
          Medida = c("Spearman (rho)", "p-value (Spearman)", "Pearson (r)",
                     "p-value (Pearson)", "R^2 (linear)", "n"),
          Valor = c(sprintf("%.3f", st$spearman), correlation_fmt_p(st$spearman_p),
                    sprintf("%.3f", st$pearson), correlation_fmt_p(st$pearson_p),
                    sprintf("%.3f", st$r2), fmt(st$n)),
          stringsAsFactors = FALSE
        )
        return(datatable(tbl, rownames = FALSE, options = list(dom = "t")))
      }

      if (d$kind == "nc") {
        tbl <- d$df %>%
          group_by(group) %>%
          summarise(Records = dplyr::n(), Mean = mean(value), Median = median(value),
                    `Std. Dev.` = sd(value), .groups = "drop") %>%
          arrange(desc(Registros)) %>%
          rename(Grupo = group)
        return(
          datatable(tbl, rownames = FALSE, options = list(dom = "t", pageLength = 20, scrollX = TRUE)) %>%
            formatRound(c("Mean", "Median", "Std. Dev."), digits = 2, mark = ",") %>%
            formatRound("Records", digits = 0, mark = ",")
        )
      }

      # cc: contingency table of counts
      datatable(as.data.frame.matrix(st$table), rownames = TRUE,
                options = list(dom = "t", pageLength = 20, scrollX = TRUE))
    })

    output$explorer_note <- renderUI({
      d <- explorer_data()
      tags$p(
        class = "text-muted small",
        sprintf("Sample of %s out of %s complete records (both variables present). ",
          fmt(d$n_sample), fmt(d$n_total)),
          "Statistics are calculated on this sample."
      )
    })

    output$download_explorer <- downloadHandler(
      filename = function() paste0("bivariate_sample_", Sys.Date(), ".csv"),
      content = function(file) {
        utils::write.csv(explorer_data()$df, file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )

    # 2. CORRELATION MATRIX
    matrix_params <- eventReactive(input$apply_matrix, {
      level <- input$level
      vars  <- input$matrix_vars
      validate(
        need(length(vars) >= 2, "Select at least 2 variables."),
        need(length(vars) <= correlation_max_matrix_vars,
             sprintf("Maximum %d variables.", correlation_max_matrix_vars)),
        need(all(vars %in% names(correlation_vars[[level]])),
             "The variables do not correspond to this level. Click Apply.")
      )
      list(
        level = level, vars = vars,
        method = input$method,
        use_log = input$method == "pearson" && isTRUE(input$matrix_log),
        hide_structural = isTRUE(input$hide_structural),
        cluster = isTRUE(input$cluster),
        show_values = isTRUE(input$show_values),
        n = as.integer(input$matrix_n),
        opts = current_opts(),
        filters = current_filters()
      )
    }, ignoreNULL = FALSE)

    matrix_result <- reactive({
      p <- matrix_params()

      sql <- correlation_matrix_sql(p$level, p$vars, p$opts, p$filters, p$n)
      df <- withProgress(message = "Querying data...", correlation_run(sql))
      validate(need(nrow(df) >= correlation_min_pair_n,
                    "There are not enough rows with the current filters."))

      res <- withProgress(
        message = "Calculating correlations...",
        correlation_compute_matrix(df, p$method, p$use_log, correlation_min_pair_n)
      )
      validate(need(!is.null(res$r), "No variable has enough data to correlate."))

      r <- res$r
      n <- res$n

      if (p$cluster) {
        ord <- correlation_cluster_order(r)
        r <- r[ord, ord]
        n <- n[ord, ord]
      }
      if (p$hide_structural) {
        nm <- colnames(r)
        r[outer(nm, nm, correlation_is_structural)] <- NA_real_
      }

      list(r = r, n = n, dropped = res$dropped, n_rows = nrow(df))
    })

    output$matrix_note <- renderUI({
      res <- matrix_result()
      p   <- matrix_params()
      vars <- correlation_vars[[p$level]]

      msgs <- sprintf("Calculated on %s rows (%s%s).", fmt(res$n_rows), p$method,
                if (p$use_log) ", log10" else "")
      if (length(res$dropped)) {
        msgs <- c(msgs, sprintf("Variables omitted due to insufficient or constant data: %s.",
                                paste(res$dropped, collapse = ", ")))
      }
      if (any(vapply(p$vars, function(v) isTRUE(vars[[v]]$sparse), logical(1)))) {
        msgs <- c(msgs, "Achievement variables only cover users with achievement data; their cells use fewer rows (see n on hover).")
      }
      tags$p(class = "text-muted small mb-2", paste(msgs, collapse = " "))
    })

    output$heatmap <- renderPlotly({
      res <- matrix_result()
      p   <- matrix_params()
      correlation_plot_heatmap(
        res$r, res$n,
        click_input_id = session$ns("heatmap_click"),
        show_values = p$show_values && ncol(res$r) <= 15
      )
    })

    pairs_data <- reactive({
      res <- matrix_result()
      p   <- matrix_params()
      tbl <- correlation_pairs_table(res$r, res$n, p$hide_structural)
      tbl[abs(tbl$r) >= input$pairs_threshold, , drop = FALSE]
    })

    output$pairs_tbl <- renderDT({
      tbl <- pairs_data()
      validate(need(nrow(tbl) > 0, "No pairs with |r| above the threshold."))
      show <- data.frame(
        `Variable A` = tbl$var_a, `Variable B` = tbl$var_b,
        r = round(tbl$r, 3), n = tbl$n,
        Strength = tbl$strength, Note = tbl$note,
        check.names = FALSE, stringsAsFactors = FALSE
      )
      datatable(show, rownames = FALSE, selection = "single",
                options = list(pageLength = 15, dom = "frtip")) %>%
        formatRound("n", digits = 0, mark = ",")
    })

    # Heatmap cell click -> open the pair in the explorer
    observeEvent(input$heatmap_click, {
      click <- input$heatmap_click
      p <- matrix_params()
      req(click$x, click$y, click$x != click$y)
      if (p$level != input$level) {
        showNotification("The level has changed since the matrix was calculated. Click Apply again.",
                         type = "warning")
        return()
      }
      jump(list(level = p$level, x = click$x, y = click$y))
      open_pair(click$x, click$y)
    })

    # Pairs-table row click -> open the pair in the explorer
    observeEvent(input$pairs_tbl_rows_selected, {
      i   <- input$pairs_tbl_rows_selected
      tbl <- pairs_data()
      req(length(i) == 1, i <= nrow(tbl))
      p <- matrix_params()
      if (p$level != input$level) {
        showNotification("The level has changed since the matrix was calculated. Click Apply again.",
                         type = "warning")
        return()
      }
      jump(list(level = p$level, x = tbl$var_a[i], y = tbl$var_b[i]))
      open_pair(tbl$var_a[i], tbl$var_b[i])
    })

    output$download_matrix <- downloadHandler(
      filename = function() paste0("correlation_matrix_", matrix_params()$level, "_", Sys.Date(), ".csv"),
      content = function(file) {
        utils::write.csv(as.data.frame(matrix_result()$r), file, row.names = TRUE, fileEncoding = "UTF-8")
      }
    )
  })
}
