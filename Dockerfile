FROM rocker/r-ver:4.3.1

# Fix library path
ENV R_LIBS_SITE=/usr/local/lib/R/site-library

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libuv1-dev \
    make \
    g++ \
    libhttp-parser-dev \
    && rm -rf /var/lib/apt/lists/*

# Install required R packages into correct path
RUN R -e "install.packages(c('later','promises','httpuv','plumber','randomForest','jsonlite'), repos='https://cran.rstudio.com/', lib='/usr/local/lib/R/site-library')"

WORKDIR /app

COPY backend/plumber/plumber.R ./plumber.R
COPY outputs/model/ ./model/

EXPOSE 8000

CMD ["Rscript", "-e", "library(plumber); pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=8000)"]