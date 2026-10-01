quality_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(
      value_box("Games", textOutput(ns("n_games"))),
      value_box("Users", textOutput(ns("n_users"))),
      value_box("Achievements", textOutput(ns("n_achievements"))),
      value_box("Relation user_games", textOutput(ns("n_ug"))),
      value_box("Relation user_achievements", textOutput(ns("n_ua")))
    ),
    card(
      card_header("% of NULL on columns (table games)"),
      plotlyOutput(ns("nulls"), height = 600)
    )
  )
}

quality_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    # activate or deactivate cache saving (False is faster for development)
    cache_on <- FALSE

    counts <- reactive({
      dbGetQuery(pool, "SELECT (SELECT count(*) FROM games) g,
                               (SELECT count(*) FROM users) u,
															 (SELECT count(*) FROM achievements) a,
                               (SELECT count(*) FROM user_games) ug,
															 (SELECT count(*) FROM user_achievements) ua")
    })

    if (cache_on) {
      counts <- counts |> bindCache(1)
    }

    output$n_games <- renderText(format(counts()$g,  big.mark = ","))
    output$n_users <- renderText(format(counts()$u,  big.mark = ","))
    output$n_achievements <- renderText(format(counts()$a,  big.mark = ","))
    output$n_ug    <- renderText(format(counts()$ug, big.mark = ","))
    output$n_ua    <- renderText(format(counts()$ua, big.mark = ","))

    nulls <- reactive({
      cols <- dbGetQuery(
        pool, "SELECT column_name FROM information_schema.columns 
					WHERE table_name = 'games' ORDER BY ordinal_position"
      )$column_name
      sql <- paste0("SELECT ", paste(sprintf(
        'round(100.0*count(*) FILTER 
				(WHERE "%1$s" IS NULL)/count(*),1) AS "%1$s"',
        cols
      ),
      collapse = ", "),
      " FROM games")
      res <- dbGetQuery(pool, sql)
      data.frame(columna = names(res), pct_nulos = as.numeric(res[1, ]))
    }) 
    
    if (cache_on) {
      nulls <- nulls |> bindCache(1)
    }

    output$nulls <- renderPlotly({
      p <- ggplot(nulls(), aes(reorder(columna, pct_nulos), pct_nulos)) +
        geom_col() + coord_flip() +
        labs(x = NULL, y = "% nulls") + theme_minimal()
      ggplotly(p)
    })
  })
}