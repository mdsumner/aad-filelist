## mdim_refs_vrt.R  -- wire blocklist::parse_mosaic_vrt + scan_source_chunks
##                     into the SQLite refs store from mdim_refs_sqlite.R
## ----------------------------------------------------------------------------
## Division of labour:
##   parse_mosaic_vrt(vrt)$arrays[[name]]  -> the LOGICAL array `A`:
##        dim_names, shape, chunks, dtype, scale/offset/nodata/unit, and
##        $sources (each: filename, array "/anom", dest = placement index)
##   scan_source_chunks(scan_path, source_array, ref_path, A, contiguous)
##        -> the BYTE refs for ONE source array in ONE file (path=ref_path,
##           offset, size, codec/info). This is the only thing that touches
##           the HDF5 chunk index -- the gdalraster/rhdf5 work lives in here.
##   dest (from the parse, NOT passed to scan_source_chunks) places those
##        source-local chunks into the mosaic PK index space.
## ----------------------------------------------------------------------------

source("inst/scheme/mdim_refs_sqlite.R")   # mr_open/mr_init/mr_add_array/mr_merge/mr_chunk

## local /rdsi path  ->  public https ref target (what refs point at)
RAAD_ROOT <- "/rdsi/PUBLIC/raad/data/"
.mr_public <- function(local) paste0("https://", sub(RAAD_ROOT, "", local, fixed = TRUE))

## scan_source_chunks() returns, per chunk: the source-local chunk coordinates
## as columns c1..cN (0-based, in dim order) plus offset, size, path. No codec
## column -> see note on codec promotion below.
.CHUNK_COL <- "^c[0-9]+$"                                    # c1, c2, ... (or c0)

## byte payload -> canonical store columns (the c* coords are split off in .place)
.canon_refs <- function(r) {
  data.frame(
    path    = r$path,
    offset  = bit64::as.integer64(r$offset),
    size    = bit64::as.integer64(r$size),
    info    = if (!is.null(r$info)) as.character(r$info) else NA_character_,
    present = as.integer(!is.na(r$offset)),                  # sparse -> 0
    stringsAsFactors = FALSE)
}

## place a source's chunks into mosaic index space: final = dest + local(c*).
## - c* are detected by pattern and ordered by their numeric suffix, so this is
##   rank-agnostic and indifferent to c0- vs c1-naming.
## - dest is taken as the chunk-coordinate base (chunks/source == 1 here, so
##   single chunk c==0 => final == dest). If parse_mosaic_vrt ever expresses
##   dest in element units, divide by A$chunks before adding.
.place <- function(r, dest) {
  cc <- grep(.CHUNK_COL, names(r), value = TRUE)
  cc <- cc[order(as.integer(sub("^c", "", cc)))]            # dim order: c1->idx0
  stopifnot(length(cc) == length(dest))
  local <- as.matrix(r[cc])                                  # n x rank, 0-based
  idx   <- sweep(local, 2L, as.integer(dest), `+`)           # mosaic chunk coords
  storage.mode(idx) <- "integer"
  colnames(idx) <- paste0("idx", seq_along(dest) - 1L)
  byte <- r[setdiff(names(r), cc)]                           # offset, size, path
  cbind(as.data.frame(idx), .canon_refs(byte))
}

## ---- the extractor factory -------------------------------------------------
## Returns a closure-bundle: $arrays, $register(con,name), $extract(name).
## Captures the parsed VRT so dest + A travel with it.
make_vrt_extractor <- function(vrt_path, contiguous = FALSE) {
  parsed <- blocklist::parse_mosaic_vrt(vrt_path)
  ## the dataset's dimension names come from the data vars (which report them);
  ## a coord array is one whose name is in that set. Coords don't self-report
  ## usable dim_names in the VRT, so we can't rely on A$dim_names for them.
  dimset <- unique(unlist(lapply(parsed$arrays, `[[`, "dim_names")))

  register <- function(con, name) {
    A <- parsed$arrays[[name]]
    kind <- if (A$name %in% dimset) "coord" else "data"
    ## rank comes from shape (the field reliably present); make dims and chunks
    ## conform. Coords often arrive with empty/short dim_names -- a 1-D coord's
    ## dimension is itself; one chunk == whole array if chunks is absent.
    shape  <- A$shape
    chunks <- A$chunks
    dims   <- A$dim_names
    rank   <- length(shape)
    if (rank < 1L)
      stop(sprintf("array '%s': VRT parse returned empty shape -- cannot size it. str:\n%s",
                   name, paste(utils::capture.output(utils::str(A)), collapse = "\n")))
    if (length(chunks) != rank) chunks <- shape
    if (length(dims)   != rank)
      dims <- if (rank == 1L) A$name else paste0(A$name, "_d", seq_len(rank))
    attrs <- Filter(Negate(is.null), list(
      scale_factor = A$scale, add_offset = A$offset, units = A$unit))
    mr_add_array(con, A$name, dims, shape, chunks, A$dtype,
                 kind = kind, storage = "referenced",
                 fill = if (is.null(A$nodata)) NA_character_ else as.character(A$nodata),
                 attrs = if (length(attrs)) attrs else NULL)
    ## codec is array-level and surfaced by NEITHER the VRT NOR scan_source_chunks
    ## (its return has no info column). Fill arrays.codec once per array from the
    ## HDF5 filter pipeline -- e.g. rhdf5::H5Dget_create_plist() + H5Pget_filter(),
    ## or GetRawBlockInfo()'s codec text if you extend scan_source_chunks to
    ## return it. One probe per array suffices (uniform across chunks).
  }

  extract <- function(name) {
    A    <- parsed$arrays[[name]]
    srcs <- A$sources
    ## skip redundant scans for arrays whose placement doesn't vary across
    ## sources (lon/lat/zlev): same dest => same chunk => scan once.
    if (length(srcs) > 1 &&
        length(unique(lapply(srcs, `[[`, "dest"))) == 1L) srcs <- srcs[1L]
    do.call(rbind, lapply(srcs, function(s) {
      local  <- s$filename
      refs   <- blocklist::scan_source_chunks(
        scan_path    = local,             # /rdsi ... .nc  (read chunk index here)
        source_array = s$array,           # "/anom"
        ref_path     = .mr_public(local), # https ...      (refs point here)
        A            = A,
        contiguous   = contiguous)
      .place(refs, s$dest)
    }))
  }

  list(parsed = parsed,
       arrays = names(Filter(Negate(is.null), parsed$arrays)),  # DATA vars only
       dims   = dimset,                                         # coord names
       register = register, extract = extract)
}

## ---- coordinates: INLINE their values (not byte refs) ----------------------
## Coords aren't in parse_mosaic_vrt()$arrays -- they're dimensions. Inlining is
## the kerchunk-correct treatment regardless: small, shared across files, and
## needed as actual values for an xarray index. One inline chunk, raw little-
## endian bytes, codec null. blocklist base64s the BLOB into the published store.
register_coord <- function(con, name, values, dtype = "<f8", size = 8L,
                           attrs = NULL) {
  n <- length(values)
  mr_add_array(con, name, dims = name, shape = n, chunks = n, dtype = dtype,
               kind = "coord", storage = "inline", codec = NULL, attrs = attrs)
  blob <- writeBin(as.double(values), raw(), size = size, endian = "little")
  tbl  <- DBI::dbQuoteIdentifier(con, name)
  DBI::dbExecute(con, sprintf(
    'INSERT INTO %s (idx0, present, data) VALUES (0, 1, ?)
     ON CONFLICT(idx0) DO UPDATE SET data = excluded.data, present = 1', tbl),
    params = list(list(blob)))               # RSQLite binds list(raw) as BLOB
  invisible(name)
}

## coordinate VALUES: `time` you already hold (set$date); spatial coords are
## identical across files, read once from any source. RNetCDF is the least-
## friction reader; tidync or a gdalraster mdim read work equally.
read_coord <- function(file, name) {
  nc <- RNetCDF::open.nc(file); on.exit(RNetCDF::close.nc(nc))
  as.numeric(RNetCDF::var.get.nc(nc, name))
}

## ---- promote codec from first observed chunk info --------------------------
mr_promote_codec <- function(con, array) {
  tbl <- DBI::dbQuoteIdentifier(con, array)
  info <- DBI::dbGetQuery(con, sprintf(
    'SELECT info FROM %s WHERE info IS NOT NULL LIMIT 1', tbl))$info
  if (length(info))
    DBI::dbExecute(con, "UPDATE arrays SET codec = ? WHERE name = ?",
                   params = list(jsonlite::toJSON(list(id = info), auto_unbox = TRUE), array))
}

## ============================================================================
## DRIVER -- your exact two-file OISST mosaic ---------------------------------
if (sys.nframe() == 0L) {

  src <- tibble::tibble(
    access = paste0("/rdsi/PUBLIC/raad/data/", set$file),  # local: read bytes / chunk index here
    public = paste0("https://",        set$file)) # remote: what the refs point at

  writeLines(src$access, filelist <- tempfile())
  ## build the mosaic VRT (time axis == file order == date order)
  vrt <- "sst.vrt"
  print(system.time(
  {system(sprintf("gdal mdim mosaic @%s %s --overwrite",
                 filelist, vrt))
}))

  time <- Sys.time()
  ext <- make_vrt_extractor(vrt, contiguous = FALSE)   # set TRUE if HDF5 layout
                                                       # is contiguous (no chunk
                                                       # index); check via your
                                                       # rhdf5 H5Dget_chunk_info
  con <- mr_open("oisst.sqlite", write = TRUE); mr_init(con)

  ## DATA VARS -- referenced (parse_mosaic_vrt + scan_source_chunks):
  ##   anom err sst ice
  for (nm in ext$arrays) {
    ext$register(con, nm)
    refs <- ext$extract(nm)
    mr_merge(con, setNames(list(refs), nm))
    mr_promote_codec(con, nm)
  }

  ## COORDS -- inline values (ext$dims == time zlev lat lon):
  ##   time you already have from step 1's set; spatial coords read once.
  register_coord(con, "time", as.numeric(set$date), dtype = "<f8",
                 attrs = list(units = "seconds since 1970-01-01T00:00:00",
                              calendar = "proleptic_gregorian"))
  for (cn in setdiff(ext$dims, "time"))
    register_coord(con, cn, read_coord(src$access[1], cn), dtype = "<f8")

  ## reads:
  cat("anom chunk (1,0,0,0)  [second day, referenced]:\n")
  print(mr_chunk(con, "anom", c(1, 0, 0, 0)))
  cat("\ntime chunk (0)  [inline: data BLOB, null path]:\n")
  print(within(mr_chunk(con, "time", 0), data <- vapply(data, length, 0L)))  # show blob size
  cat("\nanom zarr meta:\n"); str(mr_zarr_meta(con, "anom"))

  print(Sys.time() - time)
  DBI::dbDisconnect(con)
}

## ----------------------------------------------------------------------------
## INCREMENTAL (the trailing-window rewrite) ---------------------------------
## Same path, narrower set: rebuild sst.vrt over just the last ~14 days from
## step 1's set, make_vrt_extractor on it, and the per-array mr_merge upserts
## in place. prelim->final lands at the same dest (= same time idx) => clean
## replacement, no renumber. A mid-series backfill shifts dest => full rebuild.
## ----------------------------------------------------------------------------
