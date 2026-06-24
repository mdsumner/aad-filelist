## ===========================================================================
## STEP 1 -- from raadfiles' protocol-less file list to a defined, deduped,
## date-ordered set. Done by hand here (no oisst_daily_files wrapper) so every
## move is visible: get the rootless `file` column, cull to the set with a
## pattern stack, date-stamp, then dedup with the preference made explicit.
##
## OUT: data.frame(date, file) where
##   file  = protocol-less key   (www.ncei.noaa.gov/.../oisst-...nc)
##   date  = one row per day, the preferred file when a day has duplicates
## `file` is the ONLY thing carried forward -- root and /vsicurl base get
## prepended later, per render. Nothing here touches the .nc.vrt store.
## ===========================================================================

library(dplyr)

## --- the whole tree, rootless -----------------------------------------------
## get_raad_file_names() returns a tibble with a `file` column (protocol-less).
## d <- raadfiles::get_raad_file_names()
## For exposition without the AAD mount, the same frame comes from the manifest:
d <- arrow::read_parquet(
  "https://github.com/mdsumner/aad-filelist/releases/download/latest/raad_file_db.parquet"
)
stopifnot("file" %in% names(d))
message(sprintf("tree: %d files", nrow(d)))

## --- cull to the set: successive pattern filters on `file` -------------------
## (this is what .find_files_generic does -- a loop that ANDs each pattern)
pattern <- c(
  "\\.nc$",                                   # NetCDF only
  "avhrr",                                    # cheap pre-narrow
  "sea-surface-temperature-optimum-interpolation/v2\\.1/access/avhrr/"  # the product
)
files <- d
for (p in pattern) files <- dplyr::filter(files, stringr::str_detect(file, p))
stopifnot(nrow(files) > 0)
message(sprintf("set:  %d files matched", nrow(files)))

## --- date-stamp from the filename (8-digit yyyymmdd in the basename) ---------
files <- files |>
  dplyr::mutate(
    date        = as.POSIXct(as.Date(stringr::str_extract(basename(file), "[0-9]{8}"),
                                     "%Y%m%d"), tz = "UTC"),
    preliminary = stringr::str_detect(file, "_preliminary")   # the dup axis for OISST
  )

## undated rows would all collapse to a single NA under distinct(date) -- make
## that drop deliberate and visible rather than silent
n_undated <- sum(is.na(files$date))
if (n_undated > 0) message(sprintf("dropping %d undated file(s)", n_undated))
files <- dplyr::filter(files, !is.na(date))

## --- dedup: arrange the PREFERENCE first, THEN distinct keeps the first ------
## final (preliminary == FALSE) sorts ahead of preliminary, so the final wins.
set <- files |>
  dplyr::arrange(date, preliminary) |>
  dplyr::distinct(date, .keep_all = TRUE) |>
  dplyr::select(date, file)

message(sprintf("days: %d unique dates (removed %d duplicate-day file(s))",
                nrow(set), nrow(files) - nrow(set)))
print(utils::head(set))
print(utils::tail(set))

## `set$file` is the join key / mosaic input source. Renders (later steps):
##   local  <- paste0("/rdsi/PUBLIC/raad/data/", set$file)
##   remote <- paste0("/vsicurl/https://",       set$file)
