source("R/db.R")
# Outliers and distributions
source("R/outliers/outliers_globals.R")
source("R/outliers/outliers_ui.R")
source("R/outliers/outliers_server.R")
# Summary and quality
source("R/quality/quality_globals.R")
source("R/quality/quality_ui.R")
source("R/quality/quality_server.R")

ui <- page_navbar(
  title = "Steam Insights - EDA",
  theme = bs_theme(version = 5),
  tags$head(
    tags$link(rel = "icon",
              type = "image/svg+xml",
              href = "layout-dashboard.svg")
  ),

  nav_panel("Summary and quality", quality_ui("quality")),
  nav_panel("Outliers & Distributions", outliers_ui("outliers"))
)

server <- function(input, output, session) {
  quality_server("quality")
  outliers_server("outliers")
}

shinyApp(ui, server)