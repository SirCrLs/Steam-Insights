FROM rocker/shiny:latest

RUN R -e "install.packages(c('shiny','ggplot2','plotly','DBI','RPostgres','pool'))"

COPY . /srv/shiny-server/


EXPOSE 3838

CMD ["/usr/bin/shiny-server"]