# Summary & quality module: server
quality_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    hour_key <- function() format(Sys.time(), "%Y-%m-%d %H")

    selected_table <- reactiveVal("games")

    for (key in names(TABLES)) {
      local({
        k <- key
        observeEvent(input[[paste0("btn_", k)]], {
          selected_table(k)
          nav_select("tabs", "nulls")
        })
      })
    }

    counts <- reactive(get_counts())
    kpis   <- reactive(get_kpis())
    nulls  <- reactive({
      req(selected_table() %in% names(TABLES))
      get_null_pct(selected_table())
    })

    if (CACHE_ON) {
      counts <- counts |> bindCache(hour_key())
      kpis   <- kpis   |> bindCache(hour_key())
      nulls  <- nulls  |> bindCache(selected_table(), hour_key())
    }

    # tables
    output$boxes <- renderUI({
      cnt <- counts()
      cards <- lapply(names(TABLES), function(key) {
        table_card(ns, key, TABLES[[key]], fmt_int(cnt[[key]]),
                   active = selected_table() == key)
      })
      div(class = "card-row five", cards)
    })

    # kpis
    output$kpis <- renderUI({
      k <- kpis()
      div(class = "card-row four",
        kpi_card("Games enriched",          paste0(k$enriched, "%")),
        kpi_card("Games with SteamSpy",     paste0(k$steamspy, "%")),
        kpi_card("Users with public games", paste0(k$pub_games, "%")),
        kpi_card("Last games load",         format(k$last_fetch, "%Y-%m-%d"))
      )
    })

    # nulls
    output$nulls <- renderPlotly({
      df <- nulls()
      df$column <- reorder(df$column, df$pct_nulls)

      p <- ggplot(df,aes(x = column, y = pct_nulls,
        text = paste0(
          "Column: ", column,
          "<br>NULLs: ", pct_nulls, "%"
        )
      )) + geom_col() + coord_flip() +
        scale_y_continuous(limits = c(0, 100)) +
        labs(x = NULL, y = "% nulls") +
        theme_minimal()

      ggplotly(p, tooltip = "text")
    })

    # user funnel
    output$funnel <- renderPlotly({
      df <- get_funnel()
      p <- ggplot(df, aes(stage, n, text = format(n, big.mark = ","))) +
        geom_col() + coord_flip() +
        labs(x = NULL, y = "Users") + theme_minimal()
      ggplotly(p, tooltip = "text")
    })

    # relationship density as KPI cards inside Plotly (2 rows x 3 columns)
    output$relationship_density <- renderPlotly({
      df <- get_relationship_density()

      if (is.null(df) || nrow(df) == 0) {
        return(NULL)
      }

      num_rows <- 2
      num_cols <- 3

      p <- plot_ly()

      for (i in 1:nrow(df)) {
        m_title <- df$metric[i]
        m_value <- df$value[i]
        r_idx <- (i - 1) %/% num_cols
        c_idx <- (i - 1) %% num_cols
        suffix_val <- if (grepl("%", m_title)) "%" else ""

        p <- p |> add_trace(
          type = "indicator",
          mode = "number+title",
          value = m_value,
          number = list(
            font = list(size = 26, color = "#2c3e50"),
            suffix = suffix_val
          ),
          title = list(
            text = paste0("<b>", m_title, "</b>"),
            font = list(size = 12, color = "#7f8c8d")
          ),
          domain = list(
            row = r_idx,
            column = c_idx
          )
        )
      }

      p |> layout(
        grid = list(rows = num_rows, columns = num_cols, pattern = "independent"),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)",
        margin = list(t = 20, b = 20, l = 20, r = 20)
      )
    })

    # validity rules
    output$rules <- DT::renderDT({
      df <- get_validity_rules()
      validate(need(!is.null(df), paste("Missing file:", RULES_SQL)))
      DT::datatable(df, rownames = FALSE, options = list(pageLength = 15, dom = "tp")) |>
        DT::formatStyle("status",
          backgroundColor = DT::styleEqual(c("OK", "Warning", "Check"),
                                           c("#d1e7dd", "#fff3cd", "#f8d7da")))
    })

    # API failures
    output$api_fails <- renderPlotly({
      df <- get_api_fails()

      plot_df <- data.frame(
        stage = c("Total games", "API call failed"),
        n = c(df$total_games, df$api_failed),
        pct = c(NA, df$api_failed_pct)
      )

      p <- ggplot(plot_df, aes(stage, n, text = ifelse(
        is.na(pct), paste0(format(n, big.mark = ","), " games"),
        paste0( format(n, big.mark = ","), " games<br>", pct, "% of total")
      )
      )
      ) +
        geom_col() + coord_flip() +
        labs(
          x = NULL,
          y = "Games"
        ) +
        theme_minimal()

      ggplotly(p, tooltip = "text")
    })

    # Extraction error for pc requirements
    output$requirements_errors <- renderPlotly({
      df <- get_requirements_errors()

      if (is.null(df) || nrow(df) == 0) {
        return(NULL)
      }

      df$field <- reorder(df$field, df$errors)

      p <- ggplot(
        df,
        aes(
          x = field,
          y = errors,
          text = paste0(
            "Errors: ", format(errors, big.mark = ","), 
            " of ", format(total, big.mark = ","),
            "<br>Failure rate: ", pct_error, "%"
          )
        )
      ) +
        geom_col() +
        coord_flip() +
        labs(
          x = NULL,
          y = "Extraction errors"
        ) +
        theme_minimal()

      ggplotly(p, tooltip = "text")
    })

  })
}