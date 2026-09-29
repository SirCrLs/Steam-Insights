FROM rocker/shiny:4.5.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('shiny','ggplot2','plotly','DBI','RPostgres','pool','dplyr','DT','bslib'), Ncpus = 4)"

COPY --chown=shiny:shiny . /srv/shiny-server/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3838

ENTRYPOINT ["/entrypoint.sh"]