Sys.setenv(HDF5_USE_FILE_LOCKING = "FALSE")

library(blocklist)
#vrt_remote <- "/vsicurl/https://projects.pawsey.org.au/aad-derived/oisst_mdim.vrt"
#gdalraster::gdal_run("vsi copy", c("--source", vrt_remote, "--destination", tf <- tempfile(fileext = ".vrt")))
#text <- readr::read_file(tf); text <- gsub("/vsicurl/https://", "/rdsi/PUBLIC/raad/data", text)
#readr::write_file(text, vrt_local <- tempfile(fileext = ".vrt"))
## set:
#source("inst/scheme/step-1-define-set.R")

src <- tibble::tibble(
  access = paste0("/rdsi/PUBLIC/raad/data/", set$file),  # local: read bytes / chunk index here
  public = paste0("https://",        set$file)) # remote: what the refs point at
info <- blocklist::virtualize_mosaic(out_local, "oisst_remote.zarr", sources = src)
