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
    output$title <- renderText(paste("% of NULL on columns -", selected_table()))

    output$nulls <- renderPlotly({
      p <- ggplot(nulls(), aes(reorder(column, pct_nulls), pct_nulls)) +
        geom_col() + coord_flip() +
        scale_y_continuous(limits = c(0, 100)) +
        labs(x = NULL, y = "% nulls") + theme_minimal()
      ggplotly(p)
    })

    # user funnel
    output$funnel <- renderPlotly({
      df <- get_funnel()
      p <- ggplot(df, aes(stage, n, text = format(n, big.mark = ","))) +
        geom_col() + coord_flip() +
        labs(x = NULL, y = "Users") + theme_minimal()
      ggplotly(p, tooltip = "text")
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
  })
}