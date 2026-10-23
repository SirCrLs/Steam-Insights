# Coverage & bias server
# Small level views are read once; every statistic is computed in R on those tables.

coverage_server <- function(id) moduleServer(id, function(input, output, session) {

  dt <- function(d, ...) datatable(d, rownames = FALSE, options = list(dom = "t", pageLength = 25, scrollX = TRUE), ...)

  users <- reactive(cov_q("SELECT is_public, has_public_games, games_owned, total_playtime, avg_playtime,
                           pct_games_played, account_age_days, account_year, country_code, has_ach_data FROM mv_level_user"))
  games <- reactive({
    d <- cov_q("SELECT primary_genre, release_year, n_users, n_users_ach_data, (owners_min + owners_max) / 2.0 AS owners FROM mv_level_game")
    d[c("n_users", "n_users_ach_data")] <- lapply(d[c("n_users", "n_users_ach_data")], function(x) ifelse(is.na(x), 0, x))
    d
  })
  status <- reactive(cov_q("SELECT COALESCE(achievements_status, 'unknown') AS label, COUNT(*)::float8 AS value FROM user_games GROUP BY 1"))
  refreshed <- reactive(tryCatch(max(DBI::dbGetQuery(pool, "SELECT refreshed_at FROM eda_refresh_log")$refreshed_at),
                                 error = function(e) NA, warning = function(w) NA))

  # ---- KPI strip ----
  output$kpis <- renderUI({
    u <- users()
    g <- games()
    r <- refreshed()
    vb <- function(title, value, icon) value_box(title, value, showcase = bs_icon(icon))
    layout_column_wrap(width = 1 / 6, fill = FALSE,
      vb("Users", cov_num(nrow(u)), "people"),
      vb("Public profile", cov_pct(mean(u$is_public %in% TRUE)), "unlock"),
      vb("With games", cov_pct(mean((u$games_owned > 0) %in% TRUE)), "controller"),
      vb("With achievement data", cov_pct(mean(u$has_ach_data %in% TRUE)), "trophy"),
      vb("Games with users", cov_pct(mean(g$n_users > 0)), "bar-chart"),
      vb("Last refresh", if (is.na(r)) "n/a" else format(r, "%Y-%m-%d"), "clock"))
  })

  # ---- Coverage tab ----
  output$funnel <- renderPlotly(ggplotly(cov_bar(cov_funnel(users()), sort = FALSE)))
  output$status <- renderPlotly(ggplotly(cov_bar(status())))
  output$missing <- renderDT({
    u <- users()
    g <- games()
    dt(data.frame(
      Metric = c("Users without country_code", "Games without primary genre",
                 "Games with at least one user in the sample", "Games with achievement data from users"),
      Percent = 100 * c(mean(is.na(u$country_code)), mean(is.na(g$primary_genre)),
                        mean(g$n_users > 0), mean(g$n_users_ach_data > 0))
    )) %>% formatRound("Percent", 1)
  })

  # ---- Representativeness tab ----
  output$fingerprint <- renderDT({
    u <- users(); sh <- sort(prop.table(table(u$country_code)), decreasing = TRUE)
    dt(data.frame(
      Metric = c("Top-1 country share", "Top-5 countries share", "Effective number of countries",
                 "Public profiles", "Public games", "Median account year"),
      Value = c(cov_pct(sh[[1]]), cov_pct(sum(head(sh, 5))), sprintf("%.1f", 1 / sum(sh^2)),
                cov_pct(mean(u$is_public %in% TRUE)), cov_pct(mean(u$has_public_games %in% TRUE)),
                as.character(median(u$account_year, na.rm = TRUE)))))
  })

  output$compare <- renderDT({
    u <- users(); g <- u$has_ach_data %in% TRUE
    validate(need(sum(g) >= 30 && sum(!g) >= 30, "Not enough users with achievement data to compare."))
    dt(cov_compare(u)) %>% formatRound(c("Ach. users", "Others", "Effect"), 2) %>% formatSignif("P", 3)
  })

  rep_data <- reactive({
    d <- games(); d <- d[!is.na(d$owners) & d$owners > 0, ]
    genre <- input$rep_by == "Genre"
    list(rho = cor(d$n_users, d$owners, method = "spearman"),
         idx = cov_index(d, if (genre) "primary_genre" else "release_year", top = if (genre) 15 else 100))
  })
  output$rep_note <- renderUI(tags$p(class = "text-muted small", sprintf(
    "Spearman correlation between users in the sample and SteamSpy owners (per game): %.2f. Index = share of sample / share of owners; values outside 0.5-2 are flagged.",
    rep_data()$rho)))
  output$rep_plot <- renderPlotly(ggplotly(cov_bar(rep_data()$idx, log = TRUE, ref = c(0.5, 1, 2))))

  # ---- Reliability tab ----
  rel <- reactive(cov_reliability(cov_q(cov_rel_sql[[input$rel_by]]), input$min_n))
  output$rel_plot <- renderPlotly({
    d <- head(rel(), 25)
    ggplotly(cov_bar(data.frame(label = d$grp, value = d$n, flag = d$flag), log = TRUE, ref = input$min_n))
  })
  output$rel_tbl <- renderDT({
    d <- rel()
    dt(data.frame(Group = d$grp, Unit = d$unit, N = d$n, "User-games" = d$user_games,
                  "MoE (+/- pp)" = round(d$moe, 1), Flag = d$flag, check.names = FALSE)) %>%
      formatRound(c("N", "User-games"), 0, mark = ",")
  })
})
