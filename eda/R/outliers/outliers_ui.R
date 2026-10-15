# UI of outliers 

outliers_ui <- function(id) {
  ns <- NS(id)

  layout_sidebar(
    fillable = FALSE,

    # Sidebar
    sidebar = sidebar(
      title = "Controls",
      width = 320,

      selectInput(ns("table"), "Table",
                  choices = outliers_table_choices, selected = "games"),

      selectInput(ns("variable"), "Variable",
                  choices = outliers_var_choices("games")),

      radioButtons(ns("method"), "Detection Method",
                   choices = outliers_methods, selected = "iqr"),

      sliderInput(ns("k"), "Threshold k",
                  min = 0.5, max = 6, value = outliers_k_default[["iqr"]], step = 0.1),
      helpText("IQR: 1.5 standard \u00b7 Z-score: 3 \u00b7 MAD: 3.5"),

      hr(),

      checkboxInput(ns("log"),   "Apply log10 before detecting", value = FALSE),
      checkboxInput(ns("valid"), "Exclude values out of range", value = TRUE),
      checkboxInput(ns("zeros"), "Exclude zeros", value = FALSE),
      checkboxInput(ns("zoom"),  "Focus histogram on P1-P99", value = TRUE),

      actionButton(ns("apply"), "Aplly", icon = icon("play"),
                   class = "btn-primary w-100")
    ),

    # Content
    uiOutput(ns("notice")),
    uiOutput(ns("kpis")),

    navset_card_tab(
      id = ns("tabs"),

      # 1. Distribution
      nav_panel(
        "Distribution", icon = bs_icon("bar-chart"),
        card(
          card_header("Histogram"),
          plotlyOutput(ns("hist"), height = "320px"),
          uiOutput(ns("hist_note"))
        ),
        layout_columns(
          col_widths = c(8, 4),
          card(card_header("Boxplot"),
               plotlyOutput(ns("box"), height = "240px")),
          card(card_header("Summary statistics"),
               tableOutput(ns("stats_tbl")))
        )
      ),

      # 2. Compare methods
      nav_panel(
        "Compare methods", icon = bs_icon("diagram-3"),
        p(class = "text-muted",
          "The three methods are evaluated using their standard thresholds. ",
          "(IQR 1.5, Z-score 3, MAD 3.5), regardless of the 'k-Threshold' control."),
        layout_columns(
          col_widths = c(5, 7),
          card(card_header("Summary by method"), DTOutput(ns("compare_tbl"))),
          card(card_header("Agreement between methods"),
               plotlyOutput(ns("compare_plot"), height = "320px"))
        )
      ),

      # 3. Group
      nav_panel(
        "By group", icon = bs_icon("collection"),
        layout_columns(
          col_widths = c(4, 8),
          selectInput(ns("group"), "group by ",
                      choices = names(outliers_tables$games$groups)),
          p(class = "text-muted mt-4",
            "Each box plot uses the group's quartiles; the color indicates the % of records ",
            "that are outliers according to the global limits (dashed lines).",
            "Showing groups with at least ", outliers_min_group_n,
            " records (max. ", outliers_max_groups, ").")
        ),
        card(card_header("Distributions by group"),
             plotlyOutput(ns("group_plot"), height = "420px")),
        card(card_header("Outliers by group"), DTOutput(ns("group_tbl")))
      ),

      # 4. Table
      nav_panel(
        "Table", icon = bs_icon("table"),
        layout_columns(
          col_widths = c(6, 6),
          checkboxGroupInput(ns("sev"), "Severity",
                             choices = c("Slight", "Extreme"),
                             selected = c("Slight", "Extreme"), inline = TRUE),
          div(class = "text-end mt-4",
              downloadButton(ns("download"), "Download CSV", class = "btn-outline-primary"))
        ),
        uiOutput(ns("table_info")),
        DTOutput(ns("rows_tbl"))
      )
    )
  )
}
