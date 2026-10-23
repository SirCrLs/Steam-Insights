# Coverage & bias UI

coverage_ui <- function(id) {
  ns <- NS(id)
  cd <- function(title, ...) card(card_header(title), ..., fill = FALSE)
  div(
    div(class = "alert alert-warning py-2", bs_icon("exclamation-triangle"), " ", cov_bias_note),
    uiOutput(ns("kpis")),
    navset_card_tab(
      nav_panel("Coverage",
        layout_columns(col_widths = c(6, 6), fill = FALSE,
          cd("User funnel", plotlyOutput(ns("funnel"), height = "320px")),
          cd("Achievement status of user-games", plotlyOutput(ns("status"), height = "320px"))),
        cd("Missing fields and game coverage", DTOutput(ns("missing")))),
      nav_panel("Representativeness",
        layout_columns(col_widths = c(5, 7), fill = FALSE,
          cd("Selection fingerprint", DTOutput(ns("fingerprint"))),
          cd("Users with achievement data vs the rest", DTOutput(ns("compare")),
             p(class = "text-muted small", "Effect = standardized mean difference (Cramer's V for country); P = KS / chi-squared test. Flagged when |effect| > 0.1 and P < 0.05."))),
        cd("Sample vs SteamSpy owners: representation index",
           selectInput(ns("rep_by"), "Group by", names(cov_game_groups)),
           uiOutput(ns("rep_note")), plotlyOutput(ns("rep_plot"), height = "480px"))),
      nav_panel("Reliability",
        layout_columns(col_widths = c(5, 7), fill = FALSE,
          selectInput(ns("rel_by"), "Group by", names(cov_rel_sql)),
          sliderInput(ns("min_n"), "Minimum n", min = 5, max = 200, value = 30)),
        cd("Size per group (log scale, dashed = minimum n)", plotlyOutput(ns("rel_plot"), height = "480px")),
        cd("Groups", DTOutput(ns("rel_tbl"))))
    )
  )
}
