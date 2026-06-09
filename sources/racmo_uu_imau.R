## PolarRES ANT-12 RACMO (UU-IMAU)
## Served via THREDDS fileServer at cordex.dmi.dk
## Maintainer: <your name>

src <- bowerbird::bb_source(
  name        = "PolarRES ANT-12 RACMO (UU-IMAU)",
  id          = "cordex-polarres-ant12-racmo-uu-imau",
  description = paste0(
    "Regional climate model output from RACMO (UU-IMAU) at 12 km resolution ",
    "over Antarctica, produced within the PolarRES project. ",
    "Served via THREDDS fileServer at cordex.dmi.dk."),
  doc_url     = "https://polarres.eu/",
  citation    = paste0(
    "PolarRES project / UU-IMAU. Data accessed via ",
    "https://cordex.dmi.dk/thredds/fileServer/esg_cordex/PolarRes/ANT-12/UU-IMAU/"),
  license     = "Please check with data provider (cordex.dmi.dk)",
  source_url  = "https://cordex.dmi.dk/thredds/fileServer/esg_cordex/PolarRes/ANT-12/UU-IMAU/",
  method      = list(
    "bb_handler_rget",
    level           = 8,
    no_parent       = TRUE,
    accept_follow   = "/day/",
    accept_download = "\\.nc$"
  ),
  data_group  = "Regional climate model output"
)
