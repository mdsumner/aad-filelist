## sources/bas_bedmap3.R
## Bedmap3 (BAS), the single netCDF the ausantarctic/bedmap COGs were made
## from (provenance.json: bytes 2489276447, sha256 776bfbef...). A fixed
## file, so HEAD every run: a size or etag change means a new Bedmap3.
## Not in blueant. Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "Bedmap3 gridded ice thickness, bed and surface elevation (BAS)",
  id = "bas_bedmap3",
  description = "Bedmap3 500 m grids of Antarctic ice thickness, bed and surface elevation, and their uncertainties, as one netCDF from the BAS Polar Data Centre.",
  doc_url = "https://doi.org/10.5285/2d0e4791-8e20-46a3-80e4-f5f6716025d2",
  citation = "Fremand, A.C. et al. (2025) Bedmap3 updated ice bed, surface and thickness gridded datasets for Antarctica. Scientific Data. doi:10.5285/2d0e4791-8e20-46a3-80e4-f5f6716025d2",
  source_url = "https://ramadda.data.bas.ac.uk/repository/entry/get/bedmap3.nc?entryid=synth%3A2d0e4791-8e20-46a3-80e4-f5f6716025d2%3AL2JlZG1hcDMubmM=",
  license = "CC-BY-4.0",
  method = list("bb_handler_rget", level = 0),
  collection_size = 2.5,
  data_group = "Topography")

engine <- list(type = "urls", urls = src$source_url[[1]])
