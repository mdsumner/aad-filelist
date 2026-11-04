## sources/pangaea_ibcso_v2.R
## IBCSO v2 files on PANGAEA (blueant 10.1594/PANGAEA.937574, its file list
## verbatim; note PANGAEA spells the chart IBSCO_v2_digital_chart.pdf).
## Fixed files: HEAD every run. Maintainer: Michael Sumner

bb_id <- "10.1594/PANGAEA.937574"
src <- bowerbird::bb_source(
  name = "International Bathymetric Chart of the Southern Ocean Version 2 (PANGAEA)",
  id = "pangaea_937574_ibcso_v2",
  description = "IBCSO v2 500 m bed and ice surface elevation, type and source identifier grids, and the digital chart, south of 50 S.",
  doc_url = "https://doi.org/10.1594/PANGAEA.937574",
  citation = "Dorschel, B. et al. (2022) The International Bathymetric Chart of the Southern Ocean Version 2. Scientific Data 9, 275. doi:10.1038/s41597-022-01366-7",
  source_url = c("https://download.pangaea.de/dataset/937574/files/IBCSO_v2_ice-surface.tif",
                 "https://download.pangaea.de/dataset/937574/files/IBCSO_v2_bed.tif",
                 "https://download.pangaea.de/dataset/937574/files/IBCSO_v2_TID.tif",
                 "https://download.pangaea.de/dataset/937574/files/IBCSO_v2_RID.tif",
                 "https://download.pangaea.de/dataset/937574/files/IBSCO_v2_digital_chart.pdf"),
  license = "CC-BY-4.0",
  method = list("bb_handler_rget", level = 0),
  collection_size = 1,
  data_group = "Topography")

engine <- list(type = "urls", urls = src$source_url[[1]])
