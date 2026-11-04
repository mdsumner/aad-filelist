## sources/bodc_gebco.R
## GEBCO grids as the ausantarctic/gebco COGs were made: the ice surface
## elevation netCDF zip from the BODC area of CEDA
## (AustralianAntarcticDivision/gebco README: gebco_2026). 2024 and 2025 use
## the same path pattern (unchecked here). blueant's GEBCO_2024 reads the
## older bodc.ac.uk open_download zip instead. Fixed files: HEAD every run.
## Maintainer: Michael Sumner

bb_id <- "GEBCO_2024"
src <- bowerbird::bb_source(
  name = "GEBCO gridded bathymetry, ice surface elevation (BODC via CEDA)",
  id = "bodc_gebco",
  description = "GEBCO global 15 arc-second terrain model (ice surface elevation), netCDF zips for 2024 onwards, as served from the BODC area of the CEDA archive.",
  doc_url = "https://www.gebco.net/data_and_products/gridded_bathymetry_data/",
  citation = "GEBCO Compilation Group (<year>) GEBCO <year> Grid. doi as stated per release",
  source_url = sprintf("https://dap.ceda.ac.uk/bodc/gebco/global/gebco_%d/ice_surface_elevation/netcdf/GEBCO_%d.zip?download=1",
                       2024:2026, 2024:2026),
  license = "Must cite",
  method = list("bb_handler_rget", level = 0),
  collection_size = 12,
  data_group = "Topography")

engine <- list(type = "urls", urls = src$source_url[[1]])
