## ---------------------------------------------------------------------------
## VRT backfill: read each .nc, write <file>.nc.vrt into a key/value store.
##
## Workers write their own object directly (object stores take concurrent PUTs
## to distinct keys with no coordination), so the main process only dispatches,
## tallies, and logs. Restartable: the store's contents are the checkpoint.
##
## Store is a plain directory now; point `store` at /vsis3/<bucket> later and
## the only thing that changes is the dir.create() line (see note at the PUT).
## ---------------------------------------------------------------------------

library(dplyr)
library(purrr)

## --- config -----------------------------------------------------------------
root  <- "/rdsi/PUBLIC/raad/data"   # where the .nc sources live
store <- "vrt_store"                # local dir now; "/vsis3/<bucket>" later
chunk <- 50000L
dir.create(store, showWarnings = FALSE)

## --- worker (crate): build one VRT straight into the store, return status ---
## status in {"built","fail","missing"}. Package calls must be namespaced.
## `store` is declared into the crate's environment here (in_parallel()'s own
## named-arg mechanism). Crates are isolated, so constants must be baked in at
## creation time, NOT passed as `...` from the map call.
build_to_store <- purrr::in_parallel(
  function(filename, key) {
    if (!file.exists(filename)) return("missing")
    
    dst <- file.path(store, key)
    ## LOCAL-ONLY: keys contain slashes, which are real directories on a
    ## filesystem but just key characters on S3. Delete this line when `store`
    ## is a /vsis3 path.
    dir.create(dirname(dst), recursive = TRUE, showWarnings = FALSE)
    
    ok <- tryCatch({
      ## documented-stable form; use output_format = "VRT" if your build has it.
      ## If the mdim VRT driver refuses a /vsis3 destination, write to a local
      ## tempfile() here and PUT it afterwards instead.
      gdalraster::mdim_translate(filename, dst, output_format = "VRT",
                                 quiet = TRUE)
      TRUE
    }, error = function(e) FALSE)
    
    if (ok) "built" else "fail"
  },
  store = store    # declared into the crate; available inside the function
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

## --- resume: existing keys ARE the checkpoint -------------------------------
## Local: list the tree. On S3: swap for a single paginated LIST of the bucket
## (~690 requests), not 690k HEADs.
existing <- list.files(store, recursive = TRUE)
todo <- dplyr::filter(d, !key %in% existing)
message(nrow(todo), " of ", nrow(d), " remaining")

## --- run + problem logs -----------------------------------------------------
run_log  <- "vrt_run_log.csv"      # one row per chunk
prob_log <- "vrt_problems.csv"     # only fail/missing keys (built = present in store)

## --- chunked, parallel, checkpoint + log per chunk --------------------------
mirai::require_daemons()            # errors loudly if daemons aren't set
groups <- split(seq_len(nrow(todo)), (seq_len(nrow(todo)) - 1L) %/% chunk)

for (g in groups) {
  ch <- todo[g, ]
  
  status <- purrr::pmap_chr(
    list(ch$fullname, ch$key),
    build_to_store
  )
  
  ts  <- Sys.time()
  tab <- table(factor(status, c("built", "fail", "missing")))
  
  ## per-chunk summary
  readr::write_csv(
    tibble::tibble(ts = ts, n = length(status),
                   built = tab[["built"]], fail = tab[["fail"]],
                   missing = tab[["missing"]]),
    run_log, append = file.exists(run_log)
  )
  
  ## durable problems manifest (skip the built ones)
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

## ---------------------------------------------------------------------------
## Consume later: VRTs hold the original /rdsi path, so retarget on read to
## whatever mirror you want (one store works for any mirror). Mind the host:
##   base <- "/vsicurl/https://<host>/raad/data"
##   tx   <- readLines(file.path(store, key))            # or read the S3 object
##   gsub(root, base, tx, fixed = TRUE)
##
## Retry only failures from earlier runs:
##   fails <- readr::read_csv(prob_log) |>
##     dplyr::filter(status == "fail") |> dplyr::pull(key)
##   # then run the loop over  d |> filter(key %in% fails)
## ---------------------------------------------------------------------------