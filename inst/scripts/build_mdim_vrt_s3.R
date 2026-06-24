## ---------------------------------------------------------------------------
## VRT backfill -> S3 bucket. For each .nc: build a multidim VRT, rewrite the
## source path to a public /vsicurl mirror, PUT the result at <file>.nc.vrt.
##
## Workers PUT their own object (S3 takes concurrent PUTs to distinct keys with
## no coordination); the main process dispatches, tallies, logs. Restartable:
## the bucket's contents are the checkpoint. Safe to cron daily -- the anti-join
## against existing keys means each run only does what's new.
## ---------------------------------------------------------------------------

library(dplyr)
library(purrr)

## --- config -----------------------------------------------------------------
root  <- "/rdsi/PUBLIC/raad/data"            # where the .nc sources live
store <- "/vsis3/aad-index/mdim-vrt"                 # <-- the bucket prefix to write to
base  <- "/vsicurl/https:/"   # <-- replaces `root`
chunk <- 50000L

## --- GDAL S3 config (Acacia/Pawsey). Secrets from the environment. ----------
## AWS_S3_ENDPOINT has no scheme; path-style (not virtual-hosted) for non-AWS S3.
s3 <- c(
  AWS_S3_ENDPOINT       = "projects.pawsey.org.au",   #  Acacia endpoint
  AWS_VIRTUAL_HOSTING   = "FALSE",
  AWS_HTTPS             = "YES",
  AWS_ACCESS_KEY_ID     = Sys.getenv("PAWSEY_AWS_ACCESS_KEY_ID"),
  AWS_SECRET_ACCESS_KEY = Sys.getenv("PAWSEY_AWS_SECRET_ACCESS_KEY")
)

## main session needs it for the resume LIST below
for (k in names(s3)) gdalraster::set_config_option(k, s3[[k]])

## --- worker (crate): build -> rewrite -> PUT, return status -----------------
## status in {"built","fail","missing"}. store/root/base baked in (no `...`).
## --- worker (crate): build -> rewrite -> PUT, return status -----------------
## status in {"built","fail","missing"}. store/root/base baked in (no `...`).
build_to_store <- purrr::in_parallel(
  function(filename, key) {
    if (!file.exists(filename)) return("missing")

    tmp <- tempfile(fileext = ".vrt")
    on.exit(unlink(tmp), add = TRUE)

    ok <- tryCatch({
      gdalraster::mdim_translate(filename, tmp, output_format = "VRT", quiet = TRUE)
      TRUE
    }, error = function(e) FALSE)
    if (!ok || !file.exists(tmp)) return("fail")

    ## Rewrite the source path to the public mirror, then upload. Work on raw
    ## bytes with useBytes = TRUE: GDAL copies source-NetCDF attribute bytes
    ## verbatim, so a VRT can contain non-UTF-8 (e.g. a Latin-1 degree sign) and
    ## a normal gsub() errors on it. root/base are ASCII, so a byte-wise swap is
    ## safe and round-trips the original bytes faithfully (what GDAL reads back).
    ## The tryCatch turns one odd file into a "fail" instead of a crash that
    ## aborts the whole pmap_chr chunk.
    tryCatch({
      txt <- gsub(root, base,
                  rawToChar(readBin(tmp, "raw", file.size(tmp))),
                  fixed = TRUE, useBytes = TRUE)
      out <- tempfile(fileext = ".vrt")
      on.exit(unlink(out), add = TRUE)
      writeBin(charToRaw(txt), out)
      gdalraster::vsi_copy_file(out, file.path(store, key))
      "built"
    }, error = function(e) "fail")
  },
  store = store, root = root, base = base
)
## --- work list: source is .nc, key is <file>.nc.vrt -------------------------
d <- arrow::read_parquet(
  "https://github.com/mdsumner/aad-filelist/releases/download/latest/raad_file_db.parquet"
) |>
  dplyr::filter(stringr::str_detect(file, "[.]nc$")) |>
  dplyr::transmute(
    key      = paste0(file, ".vrt"),         # object key:  .../file.nc.vrt
    fullname = sprintf("%s/%s", root, file)  # source read: .../file.nc
  )

## --- resume: existing keys in the bucket ARE the checkpoint ------------------
## One paginated LIST, not 690k HEADs. Keys come back relative to `store`, so
## they line up with `key`. (Confirm recursion on a small run; if your build's
## vsi_read_dir lacks `recursive`, list with arrow::S3FileSystem instead.)
existing <- tryCatch(
  gdalraster::vsi_read_dir(store, recursive = TRUE),
  error = function(e) character()      # prefix may not exist yet on first run
)
todo <- dplyr::filter(d, !key %in% existing)
message(nrow(todo), " of ", nrow(d), " remaining")
mirai::daemons(24)
## --- daemons: each one needs the S3 config (separate processes) -------------
mirai::require_daemons()
mirai::everywhere(
  { for (k in names(s3)) gdalraster::set_config_option(k, s3[[k]]) },
  s3 = s3
)

## --- logs (local; if the runner is ephemeral, write these to the bucket too) -
run_log  <- "vrt_run_log.csv"      # one row per chunk
prob_log <- "vrt_problems.csv"     # fail/missing keys (built = present in bucket)

## --- chunked, parallel, checkpoint + log per chunk --------------------------
groups <- split(seq_len(nrow(todo)), (seq_len(nrow(todo)) - 1L) %/% chunk)

for (g in groups) {
  ch <- todo[g, ]

  status <- purrr::pmap_chr(list(ch$fullname, ch$key), build_to_store)

  ts  <- Sys.time()
  tab <- table(factor(status, c("built", "fail", "missing")))

  readr::write_csv(
    tibble::tibble(ts = ts, n = length(status),
                   built = tab[["built"]], fail = tab[["fail"]],
                   missing = tab[["missing"]]),
    run_log, append = file.exists(run_log)
  )

  bad <- status != "built"
  if (any(bad)) {
    readr::write_csv(
      tibble::tibble(ts = ts, key = ch$key[bad], status = status[bad]),
      prob_log, append = file.exists(prob_log)
    )
  }

  message(sprintf("built=%d fail=%d missing=%d  remaining ~%d",
                  tab[["built"]], tab[["fail"]], tab[["missing"]],
                  nrow(todo) - g[length(g)]))
}

