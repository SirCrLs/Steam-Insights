quality_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$style(HTML("
      .table-box { cursor: pointer; transition: transform .1s; }
      .table-box:hover { transform: translateY(-2px); }
      .table-box.active .bslib-value-box {
        outline: 3px solid var(--bs-primary);
        outline-offset: -3px;
      }
    ")),
    uiOutput(ns("boxes")),
    card(
      card_header(textOutput(ns("title"))),
      plotlyOutput(ns("nulls"), height = 750)
    )
  )
}

quality_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # activate or deactivate cache saving (False is faster for development)
    cache_on <- FALSE

    tables <- c("games", "users", "achievements", "user_games", "user_achievements")
    selected_table <- reactiveVal("games")

    observeEvent(input$btn_games,        selected_table("games"))
    observeEvent(input$btn_users,        selected_table("users"))
    observeEvent(input$btn_achievements, selected_table("achievements"))
    observeEvent(input$btn_ug,           selected_table("user_games"))
    observeEvent(input$btn_ua,           selected_table("user_achievements"))

    counts <- reactive({
      dbGetQuery(pool, "SELECT (SELECT count(*) FROM games) g,
                               (SELECT count(*) FROM users) u,
                               (SELECT count(*) FROM achievements) a,
                               (SELECT count(*) FROM user_games) ug,
                               (SELECT count(*) FROM user_achievements) ua")
    })

    if (cache_on) {
      counts <- counts |> bindCache(format(Sys.time(), "%Y-%m-%d %H"))
    }

    # Each value_box is a clickable button
    table_box <- function(btn_id, title, value, tbl) {
      div(
        class = paste("table-box", if (selected_table() == tbl) "active"),
        onclick = sprintf(
          "Shiny.setInputValue('%s', Date.now(), {priority: 'event'})",
          ns(btn_id)
        ),
        value_box(title, value, height = "85px")
      )
    }

    output$boxes <- renderUI({
      cnt <- counts()
      fmt <- function(x) format(x, big.mark = ",")
      layout_columns(
        fill = FALSE,
        table_box("btn_games", "Games", fmt(cnt$g),  "games"),
        table_box("btn_users", "Users", fmt(cnt$u),  "users"),
        table_box("btn_achievements", "Achievements",fmt(cnt$a),"achievements"),
        table_box("btn_ug", "User_Games", fmt(cnt$ug), "user_games"),
        table_box("btn_ua", "User_Achievements",fmt(cnt$ua),"user_achievements")
      )
    })

    output$title <- renderText(
      paste("% of NULL on columns -", selected_table())
    )

    nulls <- reactive({
      tbl <- selected_table()
      req(tbl %in% tables) 

      cols_query <- sprintf(
        "SELECT column_name FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = '%s'
         ORDER BY ordinal_position",
        tbl
      )
      cols <- dbGetQuery(pool, cols_query)$column_name

      if (length(cols) == 0)
        return(data.frame(column = character(), pct_nulls = numeric()))

      sql_cols <- paste(sprintf(
        'round(100.0*count(*) FILTER
        (WHERE "%1$s" IS NULL)/count(*),1) AS "%1$s"',
        cols
      ), collapse = ", ")

      # some games failed api call so i filter it here
      where_clause <- if (tbl == "games") {
        " WHERE NOT (name = 'Not in DB'
        AND short_description = 'API call failed')"
      } else {
        ""
      }

      sql <- sprintf("SELECT %s FROM %s%s", sql_cols, tbl, where_clause)

      res <- dbGetQuery(pool, sql)
      data.frame(column = names(res), pct_nulls = as.numeric(res[1, ]))
    })

    if (cache_on) {
      nulls <- nulls |> bindCache(selected_table(), format(Sys.time(), "%Y-%m-%d %H"))
    }

    output$nulls <- renderPlotly({
      p <- ggplot(nulls(), aes(reorder(column, pct_nulls), pct_nulls)) +
        geom_col() + coord_flip() +
        scale_y_continuous(limits = c(0, 100)) +
        labs(x = NULL, y = "% nulls") + theme_minimal()
      ggplotly(p)
    })
  })
}