## sources/bodc_gebco.R
## GEBCO grids from BODC (blueant GEBCO_2024 pattern: one zip folder per
## release). 2025 and 2026 follow the same folder pattern by guess (TO
## CONFIRM against the AustralianAntarcticDivision/gebco preparation notes),
## as do the sub-ice and TID variants the ausantarctic/gebco COGs may use.
## Maintainer: Michael Sumner

bb_id <- "GEBCO_2024"
src <- bowerbird::bb_source(
  name = "GEBCO gridded bathymetry (BODC open download)",
  id = "bodc_gebco",
  description = "GEBCO global 15 arc-second terrain model zips, 2024 onwards, as served by BODC.",
  doc_url = "https://www.gebco.net/data_and_products/gridded_bathymetry_data/",
  citation = "GEBCO Compilation Group (<year>) GEBCO <year> Grid. doi as stated per release",
  source_url = c("https://www.bodc.ac.uk/data/open_download/gebco/gebco_2024/zip/",
                 "https://www.bodc.ac.uk/data/open_download/gebco/gebco_2025/zip/",
                 "https://www.bodc.ac.uk/data/open_download/gebco/gebco_2026/zip/"),
  license = "Must cite",
  method = list("bb_handler_rget", level = 0),
  collection_size = 20,
  data_group = "Topography")
