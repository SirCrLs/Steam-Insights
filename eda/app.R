ui <- page_navbar(
  title = "Steam Insights - EDA",
  theme = bs_theme(version = 5),
  tags$head(
    tags$link(rel = "icon",
              type = "image/svg+xml",
              href = "layout-dashboard.svg")
  ),

  nav_panel("Summary and quality", quality_ui("quality"))
)

server <- function(input, output, session) {
  quality_server("quality")
}

shinyApp(ui, server)