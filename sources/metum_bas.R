## PolarRES ANT-12 MetUM (BAS)
## CORDEX-CMIP6 formatted output, served via public group workspace at
## gws-access.jasmin.ac.uk (plain directory listing)
## Layout: v20260129/ANT-12/<frequency>/<variable>/<files>.nc
## Maintainer: Michael Sumner
##
## Note: the source_url pins version_realization directory v20260129; when a
## new version is published on the workspace, update the path here (keeping
## the crawl pinned avoids listing duplicate files across versions).

src <- bowerbird::bb_source(
  name        = "PolarRES ANT-12 MetUM (BAS)",
  id          = "cordex-polarres-ant12-metum-bas",
  description = paste0(
    "Regional climate model output from the UK Met Office Unified Model ",
    "(MetUM, UM v13.0) on the CORDEX ANT-12 rotated-pole domain at 0.1 ",
    "degree (~11 km) grid spacing over Antarctica, produced by the British ",
    "Antarctic Survey within the PolarRES project. CORDEX-CMIP6 format ",
    "(ERA5-driven evaluation and other driving experiments as published). ",
    "Served via public group workspace at gws-access.jasmin.ac.uk."),
  doc_url     = "https://polarres.eu/",
  citation    = paste0(
    "PolarRES MetUM runs performed by BAS (contact: Ella Gilbert ",
    "<ellgil82@bas.ac.uk>, Andrew Orr <anmcr@bas.ac.uk>). PolarRES was ",
    "funded by the EU Horizon 2020 research and innovation programme call ",
    "H2020-LC-CLA-2018-2019-2020, under grant agreement 101003590. Data ",
    "accessed via https://gws-access.jasmin.ac.uk/public/polarres/",
    "CORDEX-output/v20260129/ANT-12/"),
  license     = "https://cordex.org/data-access/cordex-cmip6-data/cordex-cmip6-terms-of-use",
  source_url  = "https://gws-access.jasmin.ac.uk/public/polarres/CORDEX-output/v20260129/ANT-12/",
  method      = list(
    "bb_handler_rget",
    level           = 6,
    no_parent       = TRUE,
    accept_follow   = ".*",
    accept_download = "\\.nc$"
  ),
  data_group  = "Regional climate model output"
)
