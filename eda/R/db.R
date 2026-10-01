library(shiny)
library(bslib)
library(DBI)
library(RPostgres)
library(pool)
library(dplyr) 
library(ggplot2) 
library(plotly)

pool <- dbPool(
  RPostgres::Postgres(),
  host     = Sys.getenv("DB_HOST"),
  port     = as.integer(Sys.getenv("DB_PORT", "5432")),
  dbname   = Sys.getenv("DB_NAME"),
  user     = Sys.getenv("POSTGRES_USER"),
  password = Sys.getenv("POSTGRES_PASSWORD")
)
onStop(function() poolClose(pool))