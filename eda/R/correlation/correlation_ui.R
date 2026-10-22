# Bivariate explorer + correlation matrix

correlation_ui <- function(id) {
  ns <- NS(id)

  default_level <- "game"
  cat_choices   <- c(
    list("(none)" = ""),
    correlation_var_choices(default_level, "cat")
  )

  layout_sidebar(
    fillable = FALSE,

    # Sidebar
    sidebar = sidebar(
      width = 340,

      # Shared controls (both tabs)
      selectInput(ns("level"), "Analysis level",
                  choices = correlation_level_choices, selected = default_level),

      radioButtons(ns("filter_free"), "Game type",
                   choices = c("All" = "all", "Free" = "free", "Paid" = "paid"),
                   selected = "all", inline = TRUE),
      sliderInput(ns("filter_years"), "Release year",
                  min = correlation_year_min, max = correlation_year_max,
                  value = c(correlation_year_min, correlation_year_max),
                  step = 1, sep = ""),
      helpText("Type and year filters apply to levels that include game data."),

      checkboxInput(ns("opt_valid"), "Exclude values outside valid range", value = TRUE),
      checkboxInput(ns("opt_zeros"), "Exclude zeros", value = FALSE),

      hr(),

      # Explorer controls
      conditionalPanel(
        condition = "input.tabs == 'explorer'", ns = ns,

        selectInput(ns("var_x"), "X Variable",
                    choices = correlation_var_choices(default_level), selected = "price_usd"),
        selectInput(ns("var_y"), "Y Variable",
                    choices = correlation_var_choices(default_level), selected = "total_reviews"),
        selectInput(ns("var_color"), "Color by (optional, scatter only)",
                    choices = cat_choices, selected = ""),

        checkboxInput(ns("log_x"), "Log10 scale on X", value = FALSE),
        checkboxInput(ns("log_y"), "Log10 scale on Y", value = FALSE),

        radioButtons(ns("trend"), "Trend line",
                     choices = c("None" = "none", "Linear" = "linear", "Smooth" = "smooth"),
                     selected = "none", inline = TRUE),
        selectInput(ns("scatter_mode"), "Scatter plot display",
                    choices = c("Automatic" = "auto", "Points" = "points", "2D Density" = "density"),
                    selected = "auto"),
        checkboxInput(ns("mark_outliers"), "Mark outliers (IQR rule)", value = FALSE),

        selectInput(ns("explorer_n"), "Sample size",
                    choices = correlation_sample_choices, selected = 20000),

        actionButton(ns("apply_explorer"), "Apply", icon = icon("play"),
                     class = "btn-primary w-100")
      ),

      # Matrix controls
      conditionalPanel(
        condition = "input.tabs == 'matrix'", ns = ns,

        selectInput(ns("matrix_vars"), "Included variables",
                    choices = correlation_var_choices(default_level, "num"),
                    selected = head(correlation_var_names(default_level, "num"),
                                    correlation_max_matrix_vars),
                    multiple = TRUE),

        radioButtons(ns("method"), "Method",
                     choices = c("Spearman" = "spearman", "Pearson" = "pearson"),
                     selected = "spearman", inline = TRUE),
        checkboxInput(ns("matrix_log"), "Apply log10 (Pearson only)", value = FALSE),

        checkboxInput(ns("hide_structural"), "Hide structural relationships", value = TRUE),
        checkboxInput(ns("cluster"), "Order by hierarchical clustering", value = FALSE),
        checkboxInput(ns("show_values"), "Show values in cells (max. 15 variables)", value = TRUE),

        selectInput(ns("matrix_n"), "Sample size",
                    choices = correlation_sample_choices, selected = 50000),

        actionButton(ns("apply_matrix"), "Apply", icon = icon("play"),
                     class = "btn-primary w-100")
      )
    ),

    # Content
    uiOutput(ns("coverage")),

    navset_card_tab(
      id = ns("tabs"),

      # 1. Bivariate explorer
      nav_panel(
        "Bivariate Explorer", value = "explorer", icon = bs_icon("graph-up"),
        uiOutput(ns("explorer_alert")),
        uiOutput(ns("explorer_summary")),
        card(
          card_header("Plot"),
          plotlyOutput(ns("explorer_plot"), height = "460px")
        ),
        layout_columns(
          col_widths = c(8, 4),
          card(card_header("Statistics"), DTOutput(ns("explorer_stats_tbl"))),
          card(card_header("Data"),
               uiOutput(ns("explorer_note")),
               downloadButton(ns("download_explorer"), "Download Sample (CSV)",
                            class = "btn-outline-primary"))
        )
      ),

      # 2. Correlation matrix
      nav_panel(
        "Correlation Matrix", value = "matrix", icon = bs_icon("grid-3x3"),
        uiOutput(ns("matrix_note")),
        card(
          card_header("Heatmap (click a cell to open the pair in the explorer)"),
          plotlyOutput(ns("heatmap"), height = "620px")
        ),
        card(
          card_header("Variable Pairs"),
          layout_columns(
            col_widths = c(6, 6),
            sliderInput(ns("pairs_threshold"), "Minimum |r| in table",
                        min = 0, max = 1, value = 0.3, step = 0.05),
            div(class = "text-end mt-4",
                downloadButton(ns("download_matrix"), "Download Matrix (CSV)",
                             class = "btn-outline-primary"))
          ),
          DTOutput(ns("pairs_tbl"))
        )
      )
    )
  )
}