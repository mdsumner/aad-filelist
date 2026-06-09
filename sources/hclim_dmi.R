## PolarRES ANT-12 HCLIM (HCLIMcom-DMI)
## Served via THREDDS fileServer at cordex.dmi.dk
## Maintainer: <your name>


src <- bowerbird::bb_source(
  name        = "PolarRES ANT-12 HCLIM (HCLIMcom-DMI)",
  id          = "cordex-polarres-ant12-hclim-dmi",
  description = paste0(
    "Regional climate model output from HCLIM (HCLIMcom-DMI) at 12 km ",
    "resolution over Antarctica, produced within the PolarRES project. ",
    "Served via THREDDS fileServer at cordex.dmi.dk."),
  doc_url     = "https://polarres.eu/",
  citation    = paste0(
    "PolarRES project / HCLIMcom-DMI. Data accessed via ",
    "https://cordex.dmi.dk/thredds/fileServer/esg_cordex/PolarRes/ANT-12/HCLIMcom-DMI/"),
  license     = "Please check with data provider (cordex.dmi.dk)",
  source_url  = "https://cordex.dmi.dk/thredds/fileServer/esg_cordex/PolarRes/ANT-12/HCLIMcom-DMI/",
  method      = list(
    "bb_handler_rget",
    level           = 10,
    no_parent       = TRUE,
##    accept_follow   = "/day/",
    accept_download = "\\.nc$"
  ),
  data_group  = "Regional climate model output"
)
