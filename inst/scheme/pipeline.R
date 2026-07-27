## pipeline.R -- the SET-AWARE layer. Owns the spine (`set`), the window->global
## index arithmetic, conformance checks, and the build sequence. Calls INTO
## blocklist for the stateless renders (parse_mosaic_vrt, scan_source_chunks).
## Never emits Zarr -- that's blocklist's job, downstream, from the join of this
## cache and the VRT.
##
## The one idea underneath: `set` is the spine. The VRT is `set` rendered to
## structure + coords (disposable, rebuilt each run). This cache is `set`'s data
## chunks rendered to byte-refs (durable, upserted). Neither is the truth; both
## derive from `set`.
## ----------------------------------------------------------------------------

source("store.R")

RAAD_ROOT  <- "/rdsi/PUBLIC/raad/data/"
.mr_public <- function(local) paste0("https://", sub(RAAD_ROOT, "", local, fixed = TRUE))
.CHUNK_COL <- "^c[0-9]+$"

## ---- the window: a literal subset of authoritative `set` -------------------
## idx0 is the ABSOLUTE day number since the series began -- NOT a position in
## today's auth. This makes idx0 intrinsic to the date: stable under any auth
## change, order-independent, backfill-safe. A chunk's slot is its date, full stop.
CANON_EPOCH  <- as.Date("1981-09-01")            # OISST series origin = idx0 zero
mr_canon_idx <- function(date) as.integer(as.Date(date) - CANON_EPOCH)

mr_window <- function(auth, cutoff = NULL) {
  stopifnot(!is.unsorted(auth$date), !anyDuplicated(auth$date))
  w <- if (is.null(cutoff)) auth else auth[auth$date >= cutoff, , drop = FALSE]
  w$idx0 <- mr_canon_idx(w$date)                  # absolute day number == chunk position
  w
}

## ---- render the window to a mosaic VRT (throwaway; full mdim over the window)
mr_mosaic <- function(window, vrt = tempfile("mosaic_", fileext = ".vrt")) {
  flist <- tempfile("src_", fileext = ".txt")
  writeLines(window$access, flist)
  st <- system2("gdal", c("mdim", "mosaic", paste0("@", flist), vrt, "--overwrite"),
                stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(st, "status")) && attr(st, "status") != 0L)
    stop("mdim mosaic failed:\n", paste(st, collapse = "\n"))
  vrt
}

## ---- byte refs for the window, placed in GLOBAL index space -----------------
## time axis (idx0) is remapped from window-local dest to the global auth
## position; other dims keep their dest. scan_source_chunks supplies the bytes;
## its c1..cN source-local chunk coords are added to the (global) base in .place.
.place <- function(r, gdest) {
  cc <- grep(.CHUNK_COL, names(r), value = TRUE)
  cc <- cc[order(as.integer(sub("^c", "", cc)))]
  stopifnot(length(cc) == length(gdest))
  idx <- sweep(as.matrix(r[cc]), 2L, as.integer(gdest), `+`)
  storage.mode(idx) <- "integer"
  colnames(idx) <- paste0("idx", seq_along(gdest) - 1L)
  data.frame(as.data.frame(idx),
             path    = r$path,
             offset  = bit64::as.integer64(r$offset),
             size    = bit64::as.integer64(r$size),
             present = as.integer(!is.na(r$offset)),
             stringsAsFactors = FALSE)
}

mr_scan <- function(parsed, window, time_axis = 1L, contiguous = FALSE) {
  data_arrays <- names(Filter(Negate(is.null), parsed$arrays))   # coords excluded
  out <- lapply(data_arrays, function(nm) {
    A <- parsed$arrays[[nm]]
    do.call(rbind, lapply(A$sources, function(s) {
      refs  <- blocklist::scan_source_chunks(s$filename, s$array,
                                             .mr_public(s$filename), A,
                                             contiguous = contiguous)
      gdest <- s$dest
      gdest[time_axis] <- window$idx0[s$dest[time_axis] + 1L]     # local -> global
      .place(refs, gdest)
    }))
  })
  setNames(out, data_arrays)
}

## ---- conformance, leaning on the VRT ----------------------------------------
## (1) window is referenced to auth: every window date is in auth (idx0 is a
##     match into auth, so this is the precondition for that match being valid).
## (2) the VRT was built in window order: the source filename dates, read back in
##     dest order from the VRT, equal the window dates. Catches a gdal reorder or
##     a stale/foreign VRT before any chunk lands at a wrong index.
mr_conform <- function(parsed, window, auth, time_axis = 1L) {
  stopifnot(all(window$date %in% auth$date))
  dv <- names(Filter(Negate(is.null), parsed$arrays))[1]
  src <- parsed$arrays[[dv]]$sources
  ord <- order(vapply(src, function(s) s$dest[time_axis], 0L))
  fdate <- as.Date(vapply(src[ord], function(s)
    stringr::str_extract(basename(s$filename), "[0-9]{8}"), ""), "%Y%m%d")
  if (!isTRUE(all.equal(fdate, as.Date(window$date))))
    stop("VRT source order does not match the window -- rebuild the mosaic from `set`")
  invisible(TRUE)
}

## ---- position-stability guard: has auth's shape moved under us? --------------
## Compares the cache's stored axis to current auth on the overlapping prefix. A
## trailing append or prelim->final keeps positions; a MID-SERIES backfill shifts
## them -> returns FALSE, which is the signal to flush (cutoff = NULL) rather than
## window-upsert into a misaligned index space.
mr_axis_stable <- function(con, auth) {
  stored <- mr_axis_get(con)
  if (!length(stored)) return(TRUE)                # first build
  n <- min(length(stored), nrow(auth))
  isTRUE(all.equal(stored[seq_len(n)], as.numeric(auth$date)[seq_len(n)]))
}

## ============================================================================
## DRIVER -- the two-step, with the flush fallback wired to the guard ----------
if (sys.nframe() == 0L) {
  ## auth = today's authoritative, deduped, date-sorted set (raadfiles rules).
  ## date | access (/rdsi local) | public (https ref target).
  auth <- local({
    d <- arrow::read_parquet(
      "https://github.com/mdsumner/aad-filelist/releases/download/latest/raad_file_db.parquet")
    ## ... raadfiles culling/dedup as in step 1 -> d with `date` and `file` ...
    data.frame(date   = d$date,
               access = paste0(RAAD_ROOT, d$file),
               public = paste0("https://", d$file))
  })

  con <- mr_open("oisst.sqlite", write = TRUE); mr_init(con)

  ## idx0 is absolute, so window vs flush is a COST choice, not a correctness
  ## one -- backfill lands in its reserved slot either way. No stability guard.
  cutoff <- Sys.Date() - 14                          # or NULL to rescan everything
  window <- mr_window(auth, cutoff)

  vrt    <- mr_mosaic(window)
  parsed <- blocklist::parse_mosaic_vrt(vrt)        # parse ONCE; lean on it

  mr_conform(parsed, window, auth)                  # (1)+(2): stop if misaligned
  for (nm in names(Filter(Negate(is.null), parsed$arrays)))
    mr_declare_array(con, nm, length(parsed$arrays[[nm]]$shape), "data")

  mr_merge(con, mr_scan(parsed, window))            # upsert data-var chunks
  mr_axis_set(con, as.numeric(auth$date))           # record the ordering we're now consistent with

  ## coords + array metadata are NOT here -- blocklist reads them from `vrt`
  ## and joins with this cache to emit Zarr/kerchunk/Icechunk, downstream.
  cat("anom (1,0,0,0):\n"); print(mr_chunk(con, "anom", c(1,0,0,0)))
  DBI::dbDisconnect(con)
}
