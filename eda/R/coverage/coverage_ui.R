# Coverage & bias UI

coverage_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "alert alert-warning py-2", bs_icon("exclamation-triangle"), " ", cov_bias_note),
    uiOutput(ns("kpis")),
    navset_card_tab(
      nav_panel("Coverage",
        layout_columns(col_widths = c(6, 6),
          card(card_header("User funnel"), plotlyOutput(ns("funnel"), height = "300px")),
          card(card_header("Achievement status of user-games"), plotlyOutput(ns("status"), height = "300px"))),
        card(card_header("Missing fields and game coverage"), DTOutput(ns("missing")))),
      nav_panel("Representativeness",
        layout_columns(col_widths = c(5, 7),
          card(card_header("Selection fingerprint"), DTOutput(ns("fingerprint"))),
          card(card_header("Users with achievement data vs the rest"), DTOutput(ns("compare")),
               p(class = "text-muted small", "Effect = standardized mean difference (Cramer's V for country); P = KS / chi-squared test. Flagged when |effect| > 0.1 and P < 0.05."))),
        card(card_header("Sample vs SteamSpy owners: representation index"),
             radioButtons(ns("rep_by"), NULL, c("Genre", "Release year"), inline = TRUE),
             uiOutput(ns("rep_note")), plotlyOutput(ns("rep_plot"), height = "420px"))),
      nav_panel("Reliability",
        layout_columns(col_widths = c(5, 7),
          radioButtons(ns("rel_by"), "Group by", names(cov_rel_sql), inline = TRUE),
          sliderInput(ns("min_n"), "Minimum n", min = 5, max = 200, value = 30)),
        card(card_header("Size per group (log scale, dashed = minimum n)"), plotlyOutput(ns("rel_plot"), height = "420px")),
        card(card_header("Groups"), DTOutput(ns("rel_tbl"))))
    )
  )
}
