## sources/ibcso_annual.R
## IBCSO annual release page on ibcso.org (blueant IBCSO_annual). The 2024
## annual is gone upstream (the raad copy is the only one); this watches the
## page so the next release, and the withdrawal of 2025, show as events.
## The crawl settings are a first guess (TO CONFIRM: blueant's method args).
## Maintainer: Michael Sumner

bb_id <- "IBCSO_annual"
src <- bowerbird::bb_source(
  name = "IBCSO annual release (ibcso.org)",
  id = "ibcso_annual",
  description = "The current IBCSO annual release grids as linked from ibcso.org. Unversioned URLs: each release replaces the last.",
  doc_url = "https://ibcso.org/ibcso-2025-annual-release/",
  citation = "Dorschel, B. et al. (2022) The International Bathymetric Chart of the Southern Ocean Version 2. Scientific Data 9, 275. doi:10.1038/s41597-022-01366-7",
  source_url = "https://ibcso.org/ibcso-2025-annual-release/",
  license = "CC-BY-4.0",
  method = list("bb_handler_rget", level = 1,
                accept_follow = "_ANNUAL",
                accept_download = "_ANNUAL/.*\\.(tif|nc|zip|pdf)$"),
  collection_size = 1,
  data_group = "Topography")
