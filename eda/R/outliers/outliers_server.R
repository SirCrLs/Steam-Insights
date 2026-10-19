# Logic of outliers
# Heavy calculations (quartiles, MAD, counts, histogram) are done in SQL;
# only aggregates and, at most, rows flagged as outliers reach R.

outliers_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    fmt <- outliers_fmt

    # Controls sync
    observeEvent(input$table, {
      updateSelectInput(session, "variable",
                        choices = outliers_var_choices(input$table))
      grupos <- names(outliers_tables[[input$table]]$groups)
      updateSelectInput(
        session, "group",
        choices = if (length(grupos)) grupos
                  else c("(without groups for this table)" = "")
      )
    })

    observeEvent(input$method, {
      updateSliderInput(session, "k", value = outliers_k_default[[input$method]])
    }, ignoreInit = TRUE)

    # parameters
    params <- eventReactive(input$apply, {
      var <- outliers_vars[[input$variable]]
      req(var, var$table == input$table)
      list(
        var    = var,
        method = input$method,
        k      = input$k,
        log    = isTRUE(input$log),
        valid  = isTRUE(input$valid),
        zeros  = isTRUE(input$zeros),
        zoom   = isTRUE(input$zoom)
      )
    }, ignoreNULL = FALSE)

    base_sql <- reactive({
      p <- params()
      outliers_base_sql(p$var, p)
    })

    back <- function(x, p) if (p$log) 10^x else x
    axis_title <- function(p) {
      if (p$log) paste0(p$var$label, " (escala log)") else p$var$label
    }

    # Stats and limits
    stats <- reactive({
      sql <- base_sql()
      st <- withProgress(message = "Calculating statistics...",
                         outliers_run(outliers_stats_sql(sql)))
      validate(need(nrow(st) == 1 && !is.na(st$n) && st$n > 0,
                    "No data with these filters."))
      as.list(st)
    })

    limits <- reactive({
      p <- params()
      outliers_limits(stats(), p$method, p$k)
    })

    counts <- reactive({
      outliers_run(outliers_counts_sql(base_sql(), limits()))
    })

    # notices n KPIs
    output$notice <- renderUI({
      lim <- limits()
      if (!lim$ok) {
        div(class = "alert alert-warning",
            bs_icon("info-circle"), " ", lim$reason)
      }
    })

    output$kpis <- renderUI({
      p <- params(); st <- stats(); lim <- limits(); ct <- counts()
      n_out <- ct$n_low + ct$n_high

      layout_column_wrap(
        width = 1/4, heights_equal = "row", fill = FALSE,
        value_box("Analyzed records", fmt(st$n),
                  showcase = bs_icon("database"), theme = "primary"),
        value_box("Outliers", fmt(n_out),
                  tags$p(sprintf("%s lower \u00b7 %s top",
                            fmt(ct$n_low), fmt(ct$n_high))),
                  showcase = bs_icon("exclamation-triangle"), theme = "danger"),
        value_box("% of outliers",
                  sprintf("%.2f %%", 100 * n_out / st$n),
                  tags$p(sprintf("Extremes: %s", fmt(ct$n_ext))),
                  showcase = bs_icon("percent"), theme = "warning"),
        value_box("Limits",
                  if (lim$ok) paste(fmt(back(lim$lo, p)), "\u2192", fmt(back(lim$hi, p))) else "\u2014",
                  tags$p(sprintf("%s \u00b7 k = %s", outliers_method_names[[p$method]], p$k)),
                  showcase = bs_icon("rulers"), theme = "secondary")
      )
    })

    # 1. DISTRIBUTION
    hist_data <- reactive({
      p <- params() 
      st <- stats()
      nb <- outliers_n_bins

      rng <- if (p$zoom) c(st$p01, st$p99) else c(st$vmin, st$vmax)
      if (rng[1] >= rng[2]) rng <- c(st$vmin, st$vmax)
      if (rng[1] >= rng[2]) rng <- rng + c(-0.5, 0.5)

      h <- outliers_run(outliers_hist_sql(base_sql(), rng[1], rng[2], nb))
      list(h = h, rng = rng, w = (rng[2] - rng[1]) / nb)
    })

    output$hist <- renderPlotly({
      p <- params()
      st <- stats() 
      lim <- limits()
      hd <- hist_data()

      df <- hd$h %>%
        mutate(
          x_lo   = hd$rng[1] + (b - 1) * hd$w,
          x_hi   = hd$rng[1] + b * hd$w,
          center = (x_lo + x_hi) / 2,
          zone   = if (lim$ok) ifelse(center < lim$lo | center > lim$hi, "Outlier", "Normal")
                   else "Normal",
          text  = sprintf("%s \u2013 %s<br>Records: %s",
                           fmt(back(x_lo, p)), fmt(back(x_hi, p)), fmt(n))
        )

      g <- ggplot(df, aes(x = center, y = n, fill = zone, text = text)) +
        geom_col(width = hd$w * 0.95) +
        scale_fill_manual(values = c(Normal = "#4C78A8", Outlier = "#E45756")) +
        labs(x = axis_title(p), y = "Records", fill = NULL) +
        theme_minimal()

      if (lim$ok) {
        g <- g + geom_vline(xintercept = c(lim$lo, lim$hi),
                            linetype = "dashed", colour = "#444444")
      }
      if (p$log) g <- g + scale_x_continuous(labels = outliers_log_labels)

      ggplotly(g, tooltip = "text")
    })

    output$hist_note <- renderUI({
      st <- stats(); hd <- hist_data(); p <- params()
      outside <- st$n - sum(hd$h$n)
      if (outside > 0.5) {
        tags$p(class = "text-muted small mb-0",
          sprintf("%s values out of sight.",
                  fmt(outside), if (p$zoom) " (P1\u2013P99)" else ""))
      }
    })

    out_sample <- reactive({
      lim <- limits()
      if (!lim$ok) return(numeric(0))
      outliers_run(outliers_sample_sql(base_sql(), lim, outliers_sample_pts))$v
    })

    output$box <- renderPlotly({
      p <- params(); st <- stats(); ct <- counts(); pts <- out_sample()
      wmin <- if (is.na(ct$wmin)) st$vmin else ct$wmin
      wmax <- if (is.na(ct$wmax)) st$vmax else ct$wmax

      bx <- data.frame(x = 1, ymin = wmin, lower = st$q1, middle = st$med,
                       upper = st$q3, ymax = wmax)

      g <- ggplot() +
        geom_boxplot(data = bx,
                     aes(x = x, ymin = ymin, lower = lower, middle = middle,
                         upper = upper, ymax = ymax),
                     stat = "identity", fill = "#9ecae1", colour = "#3b6a8f", width = 0.5)

      if (length(pts)) {
        g <- g + geom_jitter(data = data.frame(x = 1, y = pts), aes(x = x, y = y),
                             width = 0.15, height = 0, colour = "#E45756",
                             alpha = 0.5, size = 1)
      }

      g <- g + coord_flip() +
        scale_x_continuous(breaks = NULL) +
        labs(x = NULL, y = axis_title(p)) +
        theme_minimal()
      if (p$log) g <- g + scale_y_continuous(labels = outliers_log_labels)

      ggplotly(g)
    })

    output$stats_tbl <- renderTable({
      p <- params(); st <- stats()
      bk <- function(x) back(x, p)
      data.frame(
        `Statistical` = c("Minimum", "P25", "Median",
                            if (p$log) "Geom. Mean" else "Mean",
                            "P75", "Maximum",
                            if (p$log) "Stand. Dev. (log10)" else "Standard deviation",
                            if (p$log) "Asymmetry (log10)" else "asymmetry"),
        Valor = c(fmt(bk(st$vmin)), fmt(bk(st$q1)), fmt(bk(st$med)),
                  fmt(bk(st$mean)), fmt(bk(st$q3)), fmt(bk(st$vmax)),
                  fmt(st$sd), fmt(st$skew)),
        check.names = FALSE
      )
    }, striped = TRUE, spacing = "xs")

    # 2. COMPARE METHODS
    compare_data <- reactive({
      st <- stats()
      lims <- lapply(setNames(names(outliers_k_default), names(outliers_k_default)),
                     function(m) outliers_limits(st, m, outliers_k_default[[m]]))
      d <- withProgress(message = "Comparing methods...",
                        outliers_run(outliers_compare_sql(base_sql(), lims)))
      list(d = d, lims = lims, n = st$n, p = params())
    })

    output$compare_tbl <- renderDT({
      cd <- compare_data()
      filas <- lapply(names(outliers_k_default), function(m) {
        lim <- cd$lims[[m]]
        n_out <- sum(cd$d$n[cd$d[[m]]])
        data.frame(
          `Method`     = outliers_method_names[[m]],
          Threshold        = outliers_k_default[[m]],
          `Lower Limit` = if (lim$ok) fmt(back(lim$lo, cd$p)) else "n/a",
          `Upper Limit` = if (lim$ok) fmt(back(lim$hi, cd$p)) else "n/a",
          Outliers      = n_out,
          `%`           = round(100 * n_out / cd$n, 2),
          check.names = FALSE
        )
      })
      datatable(do.call(rbind, filas), rownames = FALSE,
                options = list(dom = "t", ordering = FALSE)) %>%
        formatRound("Outliers", digits = 0, mark = ",")
    })

    output$compare_plot <- renderPlotly({
      cd <- compare_data()
      d <- cd$d[cd$d$iqr | cd$d$z | cd$d$mad, , drop = FALSE]
      validate(need(nrow(d) > 0, "No method detects an outlier with this data."))

      d$combo <- apply(d[, c("iqr", "z", "mad")], 1, function(r) {
        paste(c("IQR", "Z", "MAD")[as.logical(r)], collapse = " + ")
      })

      g <- ggplot(d, aes(x = reorder(combo, n), y = n,
                         text = sprintf("%s<br>Records: %s", combo, fmt(n)))) +
        geom_col(fill = "#4C78A8") +
        coord_flip() +
        labs(x = NULL, y = "Records") +
        theme_minimal()
      ggplotly(g, tooltip = "text")
    })

    # 3. GROUP
    group_data <- reactive({
      p <- params()
      lim <- limits()
      gname <- outliers_or(input$group, "")
      validate(need(nzchar(gname), "This table has no defined groups."))
      grp <- outliers_tables[[p$var$table]]$groups[[gname]]
      validate(need(!is.null(grp), "Select a group and click Accept."))

      base <- outliers_base_sql(p$var, p, group = grp)
      d <- withProgress(message = "Calculating groups...",
                        outliers_run(outliers_group_sql(base, lim, grp)))
      validate(need(nrow(d) > 0,
                    sprintf("No group has at least %d records", outliers_min_group_n)))

      iqr_g <- d$q3 - d$q1
      d$wlo <- pmax(d$vmin, d$q1 - 1.5 * iqr_g)
      d$whi <- pmin(d$vmax, d$q3 + 1.5 * iqr_g)
      d$pct <- 100 * d$n_out / d$n

      d <- if (identical(grp$by, "grp")) d[order(d$grp), ] else d[order(-d$n), ]
      d$grp <- factor(d$grp, levels = if (identical(grp$by, "grp")) d$grp else rev(d$grp))
      list(d = d, gname = gname)
    })

    # This graph had to be made manually because it had a weird bug where
    # it wouldnt show anything on screen
    output$group_plot <- renderPlotly({
      p <- params()
      lim <- limits()
      gd <- group_data()
      d <- gd$d
      d$group_num <- as.numeric(d$grp)

      d$hover <- sprintf(
        "%s<br>n = %s<br>Outliers: %s (%.1f%%)",
        d$grp,
        fmt(d$n),
        fmt(d$n_out),
        d$pct
      )

      g <- ggplot(d) +
        geom_rect(
          aes(
            xmin = group_num - 0.3,
            xmax = group_num + 0.3,
            ymin = q1,
            ymax = q3,
            fill = pct,
            text = hover
          ),
          colour = "#3b6a8f"
        ) +
        geom_segment(
          aes(
            x = group_num,
            xend = group_num,
            y = wlo,
            yend = q1
          ),
          colour = "#3b6a8f"
        ) +
        geom_segment(
          aes(
            x = group_num,
            xend = group_num,
            y = q3,
            yend = whi
          ),
          colour = "#3b6a8f"
        ) +
        geom_segment(
          aes(
            x = group_num - 0.15,
            xend = group_num + 0.15,
            y = wlo,
            yend = wlo
          ),
          colour = "#3b6a8f"
        ) +
        geom_segment(
          aes(
            x = group_num - 0.15,
            xend = group_num + 0.15,
            y = whi,
            yend = whi
          ),
          colour = "#3b6a8f"
        ) +
        geom_segment(
          aes(
            x = group_num - 0.3,
            xend = group_num + 0.3,
            y = med,
            yend = med
          ),
          colour = "#E45756",
          linewidth = 1
        ) +
        scale_fill_gradient(
          low = "#9ecae1",
          high = "#E45756",
          name = "% outliers"
        ) +

        scale_x_continuous(
          breaks = seq_along(levels(d$grp)),
          labels = levels(d$grp)
        ) +

        labs(
          x = gd$gname,
          y = axis_title(p)
        ) +

        theme_minimal()

      if (lim$ok) {
        g <- g +
          geom_hline(
            yintercept = c(lim$lo, lim$hi),
            linetype = "dashed",
            colour = "#444444"
          )
      }

      if (p$log) {
        g <- g +
          scale_y_continuous(
            labels = outliers_log_labels
          )
      }

      g <- g + coord_flip()
      ggplotly(g, tooltip = "text")
    })

    output$group_tbl <- renderDT({
      d <- group_data()$d
      table <- data.frame(
        Group = as.character(d$grp), Records = d$n,
        Outliers = d$n_out, `% outliers` = round(d$pct, 2),
        check.names = FALSE
      )
      datatable(table[order(-table$Outliers), ], rownames = FALSE,
                options = list(pageLength = 10, dom = "tip")) %>%
        formatRound(c("Records", "Outliers"), digits = 0, mark = ",")
    })

    # 4. TABLE
    rows <- reactive({
      p <- params()
      lim <- limits()
      empty <- data.frame(ID = character(), Detail = character(), Value = numeric(),
                          `Direction` = character(), Severity = character(),
                          `Distance (scale)` = numeric(), check.names = FALSE)
      if (!lim$ok) return(empty)

      d <- withProgress(message = "Getting outliers...",
                        outliers_run(outliers_rows_sql(base_sql(), lim, outliers_max_rows)))
      if (nrow(d) == 0) return(empty)

      data.frame(
        ID        = d$id,
        Detail   = d$lbl,
        Value     = d$value,
        `Direction` = ifelse(d$low, "lower", "upper"),
        Severity = ifelse(d$dist > p$k * lim$scale, "Extreme", "Slight"),
        `Distance (scale)` = d$dist / lim$scale,
        check.names = FALSE
      )
    })

    rows_filtered <- reactive({
      req(input$sev)
      d <- rows()
      d[d$Severity %in% input$sev, , drop = FALSE]
    })

    output$table_info <- renderUI({
      p <- params()
      ct <- counts()
      total <- ct$n_low + ct$n_high
      msg <- sprintf("ID = %s \u00b7 Detail = %s. Distance = how much moves away from the limit.",
                     p$var$id_name, p$var$lbl_name)
      if (total > outliers_max_rows) {
        msg <- paste0(msg, sprintf(" Shows the most extremes %s.",
                                   fmt(outliers_max_rows), fmt(total)))
      }
      tags$p(class = "text-muted small", msg)
    })

    output$rows_tbl <- renderDT({
      d <- rows_filtered() 
      dt <- datatable(d, rownames = FALSE, filter = "top",
                      options = list(pageLength = 10, dom = "frtip"))
      if (nrow(d) > 0) {
        dt <- dt %>% formatRound(c("Value", "Distance (scale)"), digits = 2, mark = ",")
      }

      dt
    })

    output$download <- downloadHandler(
      filename = function() paste0("outliers_", params()$var$key, "_", Sys.Date(), ".csv"),
      content  = function(file) {
        utils::write.csv(rows_filtered(), file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  })
}
