## mdim_refs_sqlite.R
## ----------------------------------------------------------------------------
## The intermediary "Step 3" store: a plain SQLite DB of multidim chunk refs.
## One DB == one virtual dataset. One table == one array (data var OR coord
## var). The published forms (kerchunk-parquet / Zarr V2, then Icechunk) are
## projections OF this; this is the mutable source of truth.
##
## Package split (deliberately minimal dependency surface):
##   gdalraster  -> chunk-reference EXTRACTION only (GetRawBlockInfo / mdim).
##                  This is the one irreplaceable GDAL touch.
##   DBI/RSQLite -> the store: schema, transactional merge, the read path.
##                  Plain SQLite, so NO OGR/GPKG bookkeeping, NO GDAL for reads.
##   jsonlite    -> encode the list-valued array metadata (dims/shape/codec).
##   bit64       -> 64-bit offset/size round-tripped exactly (bigint=integer64).
##   (downstream) blocklist reads this DB and emits the Zarr/kerchunk store.
##   (read side) dbplyr::tbl() gives the lazy tidy interface that lazysf gave
##                  you over OGR -- but native to a plain SQLite DB.
## ----------------------------------------------------------------------------

library(DBI)

## ---- connection ------------------------------------------------------------
## bigint = "integer64" so offset/size come back as bit64, not lossy double.
mr_open <- function(path, write = FALSE) {
  con <- dbConnect(RSQLite::SQLite(), path,
                   bigint = "integer64",
                   flags = if (write) RSQLite::SQLITE_RWC else RSQLite::SQLITE_RO)
  dbExecute(con, "PRAGMA foreign_keys = ON")
  if (write) {
    dbExecute(con, "PRAGMA journal_mode = WAL")    # readers during the merge
    dbExecute(con, "PRAGMA synchronous = NORMAL")
    dbExecute(con, "PRAGMA busy_timeout = 30000")
  }
  con
}

FORMAT_VERSION <- "mdim-refs/0.1"

## ---- core tables -----------------------------------------------------------
mr_init <- function(con) {
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS meta(
      key TEXT PRIMARY KEY, value TEXT
    ) WITHOUT ROWID")
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS sources(
      file_id INTEGER PRIMARY KEY,
      access  TEXT,           -- local read path (bytes / chunk index live here)
      public  TEXT UNIQUE     -- what the published refs point at
    )")
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS arrays(
      name    TEXT PRIMARY KEY,
      kind    TEXT,           -- 'data' | 'coord'
      storage TEXT,           -- 'referenced' | 'inline' | 'affine'
      dims    TEXT,           -- JSON ordered dim names         e.g. [\"time\",\"lat\",\"lon\"]
      shape   TEXT,           -- JSON ints
      chunks  TEXT,           -- JSON ints (block shape)
      dtype   TEXT,           -- numpy style, e.g. '<f4'
      fill    TEXT,           -- TEXT token to survive NaN/Inf
      codec   TEXT,           -- JSON: zarr v2 filters + compressor
      crs     TEXT,           -- WKT/PROJJSON/authority, nullable
      attrs   TEXT,           -- JSON of array attributes (units, ...)
      affine  TEXT            -- JSON (start,step) per regular dim, nullable
    ) WITHOUT ROWID")
  dbExecute(con,
    "INSERT OR IGNORE INTO meta(key,value) VALUES('format_version', ?)",
    params = list(FORMAT_VERSION))
  invisible(con)
}

## ---- register an array: write its arrays row + create its refs table -------
## rank drives the idx0..idx{rank-1} columns; schema is otherwise uniform, so
## the read path and merge statement are identical across arrays. The `data`
## BLOB is null for referenced chunks, the inline bytes for inline coords.
mr_add_array <- function(con, name, dims, shape, chunks, dtype,
                         kind = "data", storage = "referenced",
                         fill = NA_character_, codec = NULL,
                         crs = NA_character_, attrs = NULL, affine = NULL) {
  rank <- length(dims)
  ## rank >= 1 guard: an empty dims would emit a degenerate "PRIMARY KEY ()"
  ## DDL (hard SQLite syntax error). Catch it here with a clear message.
  stopifnot(rank >= 1L, rank == length(shape), rank == length(chunks))
  j <- function(x) if (is.null(x)) NA_character_ else jsonlite::toJSON(x, auto_unbox = FALSE)

  dbExecute(con, "
    INSERT INTO arrays(name,kind,storage,dims,shape,chunks,dtype,fill,codec,crs,attrs,affine)
    VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
    ON CONFLICT(name) DO UPDATE SET
      kind=excluded.kind, storage=excluded.storage, dims=excluded.dims,
      shape=excluded.shape, chunks=excluded.chunks, dtype=excluded.dtype,
      fill=excluded.fill, codec=excluded.codec, crs=excluded.crs,
      attrs=excluded.attrs, affine=excluded.affine",
    params = list(name, kind, storage,
                  jsonlite::toJSON(dims,  auto_unbox = FALSE),
                  jsonlite::toJSON(shape, auto_unbox = FALSE),
                  jsonlite::toJSON(chunks, auto_unbox = FALSE),
                  dtype, fill, j(codec), crs, j(attrs), j(affine)))

  idx  <- paste0("idx", seq_len(rank) - 1L)
  cols <- paste0("  ", idx, " INTEGER NOT NULL", collapse = ",\n")
  tbl  <- dbQuoteIdentifier(con, name)
  ## auto-heal: CREATE TABLE IF NOT EXISTS silently preserves a pre-existing
  ## table -- including one left at the wrong rank by an earlier schema. If the
  ## existing idx-column count doesn't match, drop it so the correct shape is
  ## rebuilt. (Only fires on genuine schema drift; harmless otherwise.)
  if (name %in% dbListTables(con)) {
    have <- sum(grepl("^idx[0-9]+$",
      dbGetQuery(con, sprintf("PRAGMA table_info(%s)", tbl))$name))
    if (have != rank) {
      message(sprintf("array '%s': replacing stale table (had %d idx cols, need %d)",
                      name, have, rank))
      dbExecute(con, sprintf("DROP TABLE %s", tbl))
    }
  }
  dbExecute(con, sprintf('
    CREATE TABLE IF NOT EXISTS %s (
%s,
      present INTEGER NOT NULL DEFAULT 1,
      file_id INTEGER REFERENCES sources(file_id),
      "offset" INTEGER,        -- quoted: OFFSET is a keyword
      size     INTEGER,
      info     TEXT,           -- per-chunk codec text, if a driver varies it
      data     BLOB,           -- inline payload (coords); null when referenced
      PRIMARY KEY (%s)
    ) WITHOUT ROWID', tbl, cols, paste(idx, collapse = ", ")))
  invisible(name)
}

## rank is authoritative in the refs table's idx* columns -- don't round-trip
## it through the dims JSON (a coord with absent dim_names would break that).
mr_rank <- function(con, array) {
  ti <- DBI::dbGetQuery(con, sprintf("PRAGMA table_info(%s)",
                                     DBI::dbQuoteIdentifier(con, array)))
  sum(grepl("^idx[0-9]+$", ti$name))
}

## ---- EXTRACTION (the single gdalraster swap point) -------------------------
## Return one row per chunk of `array` in `file`, columns:
##   idx0..idx{rank-1}, present, path, offset, size, info   (data optional)
## In production the body is the gdalraster multidim refs call -- i.e.
## GetRawBlockInfo() per chunk (your getRawBlockRefs() fork), or the eventual
## `gdal mdim list-chunks`. `path` here is the PUBLIC ref target.
mr_block_refs <- function(file, array, rank, public,
                          .extract = getOption("mr.extract", NULL)) {
  if (!is.null(.extract)) return(.extract(file, array, rank, public))
  ## ---- synthetic stand-in so the module runs end-to-end without GDAL ----
  ## (single chunk per file along idx0; replace with the real extractor)
  data.frame(idx0 = 0L, present = 1L, path = public,
             offset = bit64::as.integer64(1024),
             size = bit64::as.integer64(512), info = "zlib",
             stringsAsFactors = FALSE)
}

## ---- MERGE: the serial boundary --------------------------------------------
## Caller does parallel per-file extraction (you have the atomic per-file
## pipeline already), then hands the window's refs here. This is the ONLY
## writer: one transaction wraps the whole window across all arrays, so
## single-writer locking is a design boundary, not a surprise.
##
## `refs` is a named list: array_name -> data.frame(idx0..,present,path,offset,size,info).
## Upsert on the positional PK => a prelim->final swap at a fixed time index is
## a clean in-place replacement (validated: row count stays put, file_id/offset
## change). A mid-series backfill shifts positions -> that's the rebuild path.
mr_merge <- function(con, refs) {
  dbWithTransaction(con, {
    ## 1. upsert sources, resolve public -> file_id
    pub <- unique(unlist(lapply(refs, `[[`, "path"), use.names = FALSE))
    pub <- pub[!is.na(pub)]
    if (length(pub)) {
      dbExecute(con,
        "INSERT INTO sources(access,public) VALUES(?,?)
         ON CONFLICT(public) DO UPDATE SET access=excluded.access",
        params = list(.mr_access(pub), pub))     # access derived per your roots
    }
    qn  <- paste(rep("?", length(pub)), collapse = ",")
    fid <- dbGetQuery(con, sprintf(
      "SELECT public, file_id FROM sources WHERE public IN (%s)", qn),
      params = as.list(pub))

    ## 2. upsert chunk rows, per array
    for (nm in names(refs)) {
      df <- refs[[nm]]
      if (!nrow(df)) next
      df$file_id <- fid$file_id[match(df$path, fid$public)]
      rank <- mr_rank(con, nm)
      idx  <- paste0("idx", seq_len(rank) - 1L)
      tbl  <- dbQuoteIdentifier(con, nm)
      val  <- c(idx, "present", "file_id", '"offset"', "size", "info")
      set  <- setdiff(val, idx)                  # PK cols are not updated
      sql  <- sprintf(
        'INSERT INTO %s (%s) VALUES (%s)
         ON CONFLICT (%s) DO UPDATE SET %s',
        tbl, paste(val, collapse = ","),
        paste(rep("?", length(val)), collapse = ","),
        paste(idx, collapse = ","),
        paste(sprintf("%s=excluded.%s", set, set), collapse = ", "))
      dbExecute(con, sql, params = c(
        lapply(idx, function(k) df[[k]]),
        list(df$present, df$file_id, df$offset, df$size, df$info)))
    }
    TRUE
  })
}

## access path derived from the public ref + your local roots (placeholder:
## identity). In raadfiles this is the /rdsi prefix swap from your step 2.
.mr_access <- function(public) gsub("https://", "/rdsi/PUBLIC/raad/data", public)

## ---- READ PATH: Even's query, made a function ------------------------------
## SELECT path, offset, size FROM <array> WHERE idx0=? AND idx1=? ...
## Single clustered-key seek (validated). This is what a future read-side
## metadriver (RFC Stage 4) calls per chunk.
mr_chunk <- function(con, array, idx) {
  rank <- mr_rank(con, array)
  stopifnot(length(idx) == rank)
  tbl  <- dbQuoteIdentifier(con, array)
  where <- paste(sprintf("idx%d = ?", seq_len(rank) - 1L), collapse = " AND ")
  dbGetQuery(con, sprintf(
    'SELECT s.public AS path, a."offset", a.size, a.present, a.data
     FROM %s a LEFT JOIN sources s USING(file_id) WHERE %s',
    tbl, where), params = as.list(as.integer(idx)))
}

## ---- synthesize Zarr V2 .zarray-ish metadata from an arrays row ------------
## blocklist would consume this rather than re-deriving from GDAL.
mr_zarr_meta <- function(con, array) {
  a <- dbGetQuery(con, "SELECT * FROM arrays WHERE name = ?", params = list(array))
  list(
    zarr_format = 2L,
    shape       = jsonlite::fromJSON(a$shape),
    chunks      = jsonlite::fromJSON(a$chunks),
    dtype       = a$dtype,
    fill_value  = a$fill,
    order       = "C",
    compressor  = if (!is.na(a$codec)) jsonlite::fromJSON(a$codec) else NULL,
    dimension_names = jsonlite::fromJSON(a$dims)   # xarray _ARRAY_DIMENSIONS
  )
}

## ============================================================================
## DEMO (runs without GDAL via the synthetic extractor) ----------------------
if (sys.nframe() == 0L) {
  path <- tempfile(fileext = ".sqlite")
  con  <- mr_open(path, write = TRUE); mr_init(con)

  ## one DB = one dataset. coords are arrays too (shared across data vars).
  mr_add_array(con, "time", dims = "time", shape = 2L, chunks = 2L,
               dtype = "<i8", kind = "coord", storage = "inline")
  mr_add_array(con, "sst", dims = c("time","lat","lon"),
               shape = c(2L,720L,1440L), chunks = c(1L,720L,1440L),
               dtype = "<f4", fill = "NaN",
               codec = list(id = "zlib", level = 5L))

  ## extract two daily files in parallel (here: serial synthetic), one chunk each
  files  <- c("host/oisst/20240101.nc", "host/oisst/20240102.nc")
  refs_sst <- do.call(rbind, Map(function(f, t) {
    r <- mr_block_refs(f, "sst", rank = 3L, public = f)
    r$idx0 <- t; r$idx1 <- 0L; r$idx2 <- 0L; r
  }, files, c(0L, 1L)))

  mr_merge(con, list(sst = refs_sst))

  cat("chunk (0,0,0):\n");  print(mr_chunk(con, "sst", c(0,0,0)))
  cat("\nzarr meta for sst:\n"); str(mr_zarr_meta(con, "sst"))

  ## prelim -> final for day 0: same position, new source. clean upsert.
  fin <- mr_block_refs("host/oisst/20240101_final.nc", "sst", 3L,
                       "host/oisst/20240101_final.nc")
  fin$idx0 <- 0L; fin$idx1 <- 0L; fin$idx2 <- 0L
  fin$offset <- bit64::as.integer64(4096)
  mr_merge(con, list(sst = fin))
  cat("\nafter prelim->final, chunk (0,0,0):\n"); print(mr_chunk(con, "sst", c(0,0,0)))
  cat("row count (expect 2):",
      dbGetQuery(con, 'SELECT count(*) n FROM "sst"')$n, "\n")

  dbDisconnect(con)
}
