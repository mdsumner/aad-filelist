## sources/ibcso_annual.R
## IBCSO annual release page on ibcso.org (blueant IBCSO_annual). The 2024
## annual is gone upstream (the raad copy is the only one); this watches the
## page so the next release, and the withdrawal of 2025, show as events.
## Method args as blueant 0.13.5 (bf06882) has them.
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
  method = list("bb_handler_rget", level = 1, accept_download = "tif$", no_parent_download = FALSE),
  collection_size = 0.5,
  data_group = "Topography")
