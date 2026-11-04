## sources/pangaea_ibcso_v1.R
## IBCSO v1 (2013) on PANGAEA hs.pangaea.de (blueant 10.1594/PANGAEA.805734
## and the chart 805735, file lists verbatim). Superseded upstream, so a
## salvage watch: a remove or change here matters. Maintainer: Michael Sumner

bb_id <- "10.1594/PANGAEA.805734"
src <- bowerbird::bb_source(
  name = "International Bathymetric Chart of the Southern Ocean Version 1 (PANGAEA)",
  id = "pangaea_805734_ibcso_v1",
  description = "IBCSO v1.0 500 m bed and ice surface grids, source identifiers, background image and digital chart.",
  doc_url = "https://doi.org/10.1594/PANGAEA.805734",
  citation = "Arndt, J.E. et al. (2013) The International Bathymetric Chart of the Southern Ocean (IBCSO) Version 1.0. Geophysical Research Letters 40, 3111-3117. doi:10.1002/grl.50413",
  source_url = c("http://hs.pangaea.de/Maps/bathy/IBCSO_v1/IBCSO_v1_bed_PS71_500m_grd.zip",
                 "http://hs.pangaea.de/Maps/bathy/IBCSO_v1/IBCSO_v1_is_PS71_500m_grd.zip",
                 "http://hs.pangaea.de/Maps/bathy/IBCSO_v1/IBCSO_v1_sid_PS71_500m_grd.zip",
                 "http://hs.pangaea.de/Maps/bathy/IBCSO_v1/IBCSO_v1_is_PS71_500m_tif.zip",
                 "http://hs.pangaea.de/Maps/bathy/IBCSO_v1/IBCSO_background_hq.zip",
                 "http://hs.pangaea.de/Maps/bathy/IBCSO_v1/IBCSO_v1_digital_chart_pdfA.pdf"),
  license = "CC-BY-3.0",
  method = list("bb_handler_rget", level = 0),
  collection_size = 4.2,
  data_group = "Topography")

engine <- list(type = "urls", urls = src$source_url[[1]])
