## R with the corpus packages preinstalled, for sync.yml and lint.yml: a run
## starts without installing anything (setup-r-dependencies on a slow runner
## took over an hour, 2026-11-06). r2u gives CRAN packages as Ubuntu binaries.
FROM rocker/r2u:24.04

LABEL org.opencontainers.image.source="https://github.com/mdsumner/aad-filelist" \
      org.opencontainers.image.description="R + bowerbird, nanoparquet, curl, xml2, jsonlite for the aad-filelist listing corpus"

## gh for release up/downloads, jq for the source list, git for checkout
RUN apt-get update \
 && apt-get install -y --no-install-recommends gh jq git ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

RUN Rscript -e 'install.packages(c("nanoparquet", "curl", "xml2", "jsonlite", "remotes"))' \
 && Rscript -e 'remotes::install_github("ropensci/bowerbird", upgrade = "never")' \
 && Rscript -e 'for (p in c("bowerbird", "nanoparquet", "curl", "xml2", "jsonlite")) library(p, character.only = TRUE)'
