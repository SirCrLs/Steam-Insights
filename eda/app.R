ui <- page_navbar(
  title = "Steam Insights - EDA",
  theme = bs_theme(version = 5),
  nav_panel("Summary and quality", quality_ui("quality"))
)

server <- function(input, output, session) {
  quality_server("quality")
}

shinyApp(ui, server)