# ============================================================
# Summary & quality module: UI
# ============================================================

QUALITY_CSS <- "
  /* Page: top 30% = cards, bottom 70% = charts (change 3fr / 7fr to resize) */
  .quality-page {
    display: grid; grid-template-rows: 3fr 7fr; gap: 12px;
    height: calc(100vh - 110px); min-height: 560px;
  }
  .quality-page > .card { min-height: 0; }

  /* Top block: two rows of cards that split the 30% evenly */
  .quality-top { display: grid; grid-template-rows: 1fr 1fr; gap: 12px; min-height: 0; }
  .quality-top > div { min-height: 0; }
  .card-row { display: grid; gap: 12px; height: 100%; }
  .card-row.five { grid-template-columns: repeat(5, 1fr); }
  .card-row.four { grid-template-columns: repeat(4, 1fr); }
  .table-box, .kpi-box { height: 100%; min-height: 0; }
  .quality-top .bslib-value-box .card-body { padding: 0.4rem 0.9rem; }

  /* Text sizes */
  .table-box .value-box-title, .kpi-box .value-box-title { font-size: 0.8rem; }
  .table-box .value-box-value { font-size: 1.4rem; }
  .kpi-box .value-box-value   { font-size: 1.2rem; }

  /* Table cards behave like buttons */
  .table-box { cursor: pointer; transition: transform .1s; }
  .table-box:hover { transform: translateY(-2px); }
  .table-box.active .bslib-value-box {
    outline: 3px solid var(--bs-primary); outline-offset: -3px;
  }
"

# A value_box that works as a button: clicking it sets input$btn_<key>
table_card <- function(ns, key, label, value, active) {
  div(
    class = paste("table-box", if (active) "active"),
    onclick = sprintf(
      "Shiny.setInputValue('%s', Date.now(), {priority: 'event'})",
      ns(paste0("btn_", key))
    ),
    value_box(label, value, height = "100%")
  )
}

kpi_card <- function(label, value) {
  div(class = "kpi-box", value_box(label, value, height = "100%"))
}

quality_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$style(HTML(QUALITY_CSS)),
    div(
      class = "quality-page",

      # top 30%: table cards (row 1) + health indicators (row 2)
      div(class = "quality-top",
          uiOutput(ns("boxes")),
          uiOutput(ns("kpis"))),

      # bottom 70%: charts
      navset_card_tab(
        id = ns("tabs"), height = "100%", full_screen = TRUE,
        nav_panel("Nulls", value = "nulls",
                  div(class = "text-muted small", textOutput(ns("title"))),
                  plotlyOutput(ns("nulls"), height = "100%")),
        nav_panel("User funnel", value = "funnel",
                  plotlyOutput(ns("funnel"), height = "100%")),
        nav_panel("Validity rules", value = "rules",
                  DT::DTOutput(ns("rules")))
      )
    )
  )
}