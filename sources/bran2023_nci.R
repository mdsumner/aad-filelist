## sources/bran2023_nci.R
## BRAN2023 — all resolutions (daily, month, annual, static)
## NCI project gb6, THREDDS catalog
## Maintainer: <your name>

src <- bowerbird::bb_source(
  name        = "BRAN2023 (NCI gb6)",
  id          = "nci-gb6-bran2023",
  description = paste0(
    "Bluelink Reanalysis BRAN2023, all temporal resolutions ",
    "(daily, monthly, annual, static). Hosted at NCI under project gb6."),
  doc_url     = "https://research.csiro.au/bluelink/global/reanalysis/",
  citation    = "Chamberlain et al. (2021) doi:10.1029/2020JC016935",
  license     = "CC-BY-4.0",
  source_url  = sprintf(
    "https://thredds.nci.org.au/thredds/catalog/gb6/BRAN/BRAN2023/%s/catalog.html",
    c("daily", "month", "annual", "static")
  ),
  method      = list("bb_handler_thredds", level = 2, accept_download = "\\.nc$"),
  data_group  = "Ocean reanalysis"
)
