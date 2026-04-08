FROM rocker/r-ver:4.3.1

# ✅ Fix library path
ENV R_LIBS_USER=/usr/local/lib/R/site-library

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libuv1-dev \
    make \
    g++ \
    libhttp-parser-dev

# Install dependencies
RUN R -e "install.packages(c('later','promises','httpuv'), repos='https://cran.rstudio.com/')"

# Install main packages
RUN R -e "install.packages('plumber', repos='https://cran.rstudio.com/')"
RUN R -e "install.packages('randomForest', repos='https://cran.rstudio.com/')"
RUN R -e "install.packages('jsonlite', repos='https://cran.rstudio.com/')"

WORKDIR /app

COPY backend/plumber/plumber.R ./plumber.R
COPY outputs/model/ ./model/

EXPOSE 8000

CMD ["R", "-e", "library(plumber); pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=8000)"]