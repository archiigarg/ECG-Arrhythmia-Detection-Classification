FROM rocker/r-ver:4.3.1

RUN R -e "install.packages(c('plumber','randomForest'))"

WORKDIR /app

COPY . /app

EXPOSE 8000

CMD ["R", "-e", "plumber::plumb('backend/plumber/plumber.R')$run(host='0.0.0.0', port=8000)"]