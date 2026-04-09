FROM rocker/r-ver:4.3.1

RUN apt-get update && apt-get install -y \
    curl \
    pkg-config \
    zlib1g-dev \
    libsodium-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libuv1-dev \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

RUN install2.r --error later promises httpuv plumber randomForest jsonlite

RUN Rscript -e "library(plumber); library(randomForest); library(jsonlite); cat('All packages OK\n')"

WORKDIR /app

COPY backend/plumber/plumber.R ./plumber.R
COPY outputs/model/ ./outputs/model/

EXPOSE 8000

CMD ["Rscript", "-e", "options(warn=1); library(plumber); pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=8000)"]