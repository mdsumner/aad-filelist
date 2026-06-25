Sys.setenv(HDF5_USE_FILE_LOCKING = "FALSE")

library(blocklist)

src <- tibble::tibble(
  access = paste0("/rdsi/PUBLIC/raad/data/", set$file),  # local: read bytes / chunk index here
  public = paste0("https://",        set$file)) # remote: what the refs point at
info <- blocklist::virtualize_mosaic(out_local, "oisst_remote.zarr", sources = src)
