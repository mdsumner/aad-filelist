## PolarRES ANT-12 MAR v3.13 (ULg / X. Fettweis)
## Served via plain Apache HTTP at ftp.climato.be
## Driving datasets: ERA5, CESM2, MPI-ESM1-2-HR
## Maintainer: <your name>


src <- bowerbird::bb_source(
  name        = "PolarRES ANT-12 MAR v3.13 (ULg)",
  id          = "polarres-ant12-mar-v3.13-ulg",
  description = paste0(
    "Regional climate model output from MAR v3.13 (ULg / X. Fettweis) at ",
    "12 km resolution over Antarctica, produced within the PolarRES project. ",
    "Multiple driving datasets: ERA5, CESM2, MPI-ESM1-2-HR."),
  doc_url     = "http://ftp.climato.be/fettweis/MARv3.13/PolarRES/Antarctic/ULg/",
  citation    = paste0(
    "Fettweis X et al. MAR v3.13 Antarctic PolarRES simulations. ",
    "Data accessed via http://ftp.climato.be/fettweis/MARv3.13/PolarRES/Antarctic/ULg/"),
  license     = "Please check with data provider (Xavier Fettweis, ULg)",
  source_url  = "http://ftp.climato.be/fettweis/MARv3.13/PolarRES/Antarctic/ULg/",
  method      = list(
    "bb_handler_rget",
    level           = 9,
    no_parent       = TRUE,
    accept_follow   = ".*",
    accept_download = "\\.nc$"
  ),
  data_group  = "Regional climate model output"
)
