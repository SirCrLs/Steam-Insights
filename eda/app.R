library(shiny)
library(DBI)
library(RPostgres)

ui <- fluidPage(
  h3("Test EDA"),
  verbatimTextOutput("env"),
  verbatimTextOutput("db")
)

server <- function(input, output, session) {
  output$env <- renderText({
    paste0(
      "DB_HOST=", Sys.getenv("DB_HOST"), "\n",
      "DB_PORT=", Sys.getenv("DB_PORT"), "\n",
      "DB_NAME=", Sys.getenv("DB_NAME"), "\n",
      "POSTGRES_USER=", Sys.getenv("POSTGRES_USER")
    )
  })

  output$db <- renderText({
    tryCatch({
      con <- dbConnect(
        RPostgres::Postgres(),
        host     = Sys.getenv("DB_HOST"),
        port     = as.integer(Sys.getenv("DB_PORT", "5432")),
        dbname   = Sys.getenv("DB_NAME"),
        user     = Sys.getenv("POSTGRES_USER"),
        password = Sys.getenv("POSTGRES_PASSWORD")
      )
      on.exit(dbDisconnect(con))
      paste("Conection OK. Tables:", paste(dbListTables(con), collapse = ", "))
    }, error = function(e) paste("ERROR:", conditionMessage(e)))
  })
}

shinyApp(ui, server)