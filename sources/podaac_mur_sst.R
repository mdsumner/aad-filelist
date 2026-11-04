## sources/podaac_mur_sst.R
## GHRSST MUR v4.1 L4 daily netCDF at PO.DAAC (the files the
## ausantarctic/ghrsst-mur-v2 COGs are made from). blueant GHRSST-MUR-SST_v4.1
## crawls the CMR virtual directory with bb_handler_earthdata, which refuses
## to run without an Earthdata user and password even for a dry run. The CMR
## granule search is public, so the corpus lists through it instead: no
## secret needed. Downloading (or HEAD on the protected URL) still needs
## Earthdata, so size and the change signal come from the CMR metadata.
## Maintainer: Michael Sumner

bb_id <- "GHRSST-MUR-SST_v4.1"
src <- bowerbird::bb_source(
  name = "GHRSST Level 4 MUR Global Foundation SST v4.1 (PO.DAAC, via CMR)",
  id = "podaac_mur_sst_v41",
  description = "GHRSST L4 MUR global 0.01 degree daily foundation SST analysis, netCDF, from PO.DAAC (Earthdata Cloud).",
  doc_url = "https://podaac.jpl.nasa.gov/dataset/MUR-JPL-L4-GLOB-v4.1",
  citation = "JPL MUR MEaSUREs Project (2015) GHRSST Level 4 MUR Global Foundation Sea Surface Temperature Analysis (v4.1). PO.DAAC. doi:10.5067/GHGMR-4FJ04",
  source_url = "https://cmr.earthdata.nasa.gov/virtual-directory/collections/C1996881146-POCLOUD/temporal",
  license = "Please cite",
  method = list("bb_handler_earthdata", level = 5,
                accept_follow = "/virtual-directory/collections/C1996881146-POCLOUD/temporal/",
                allow_unrestricted_auth = TRUE),
  user = "", password = "", warn_empty_auth = FALSE,
  collection_size = 2000,
  data_group = "Sea surface temperature")

engine <- list(type = "cmr", concept_id = "C1996881146-POCLOUD",
               url_match = "^https://archive\\.podaac\\.earthdata\\.nasa\\.gov/.*\\.nc$")
