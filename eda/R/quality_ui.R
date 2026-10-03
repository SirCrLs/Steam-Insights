# Summary & quality module: UI
QUALITY_CSS <- "
  /* Page: cards take the top 30%, the charts take the rest */
  .quality-page {
    display: flex; flex-direction: column; gap: 12px;
    height: calc(100vh - 110px); min-height: 560px;
  }

  /* Top block (30%): two rows of cards that split it evenly */
  .quality-top {
    flex: 0 0 30%; min-height: 150px;
    display: grid; grid-template-rows: repeat(2, minmax(0, 1fr)); gap: 12px;
  }
  .quality-top > .shiny-html-output { display: flex; min-height: 0; }

  .card-row {
    flex: 1; min-height: 0; display: grid; gap: 12px;
    grid-auto-rows: minmax(0, 1fr);
  }
  .card-row.five { grid-template-columns: repeat(5, 1fr); }
  .card-row.four { grid-template-columns: repeat(4, 1fr); }

  /* Each card fills its whole grid cell (no empty space around it) */
  .table-box, .kpi-box { display: flex; min-height: 0; height: 100%; }
  .quality-top .bslib-value-box {
    flex: 1; height: 100% !important; max-height: none !important;
    min-height: 0; margin: 0;
  }

  /* Content centered inside the card, no inner scrollbar */
  .quality-top .bslib-value-box .card-body {
    display: flex; flex-direction: column; justify-content: center;
    padding: 0.3rem 1rem; overflow: hidden;
  }
  .quality-top .value-box-title,
  .quality-top .value-box-value { margin: 0; line-height: 1.15; }

  /* Text scales with the window height */
  .table-box .value-box-title, .kpi-box .value-box-title {
    font-size: clamp(0.75rem, 1.6vh, 1rem);
  }
  .table-box .value-box-value { font-size: clamp(1.2rem, 3.4vh, 2.2rem); }
  .kpi-box .value-box-value   { font-size: clamp(1.1rem, 3vh, 1.9rem); }

  /* Bottom block (70%): charts */
  .quality-main { flex: 1 1 0; min-height: 0; }

  /* Table cards behave like buttons */
  .table-box { cursor: pointer; transition: transform .1s; }
  .table-box:hover { transform: translateY(-2px); }
  .table-box.active .bslib-value-box {
    outline: 3px solid var(--bs-primary); outline-offset: -3px;
  }
"

table_card <- function(ns, key, label, value, active) {
  div(
    class = paste("table-box", if (active) "active"),
    onclick = sprintf(
      "Shiny.setInputValue('%s', Date.now(), {priority: 'event'})",
      ns(paste0("btn_", key))
    ),
    value_box(label, value)
  )
}

kpi_card <- function(label, value) {
  div(class = "kpi-box", value_box(label, value))
}

quality_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$style(HTML(QUALITY_CSS)),
    div(
      class = "quality-page",

      div(class = "quality-top",
          uiOutput(ns("boxes")),
          uiOutput(ns("kpis"))),

      div(
        class = "quality-main",
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
  )
}