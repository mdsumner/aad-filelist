## store.R -- the byte-ref cache. SET-AGNOSTIC: it knows about chunks, sources,
## and an authoritative axis ordering, but nothing about raadfiles, windows, or
## VRTs. A pure mutable cache of "chunk position -> {file, offset, size}".
##
## Contracted to exactly what the VRT does NOT cheaply give you:
##   sources(file_id, public)        -- the ref targets, factored out
##   <array>(idx.., present, file_id, offset, size)  -- one table per data var
##   axis(idx0, epoch)               -- the auth date ordering this cache is
##                                      currently consistent with (drift guard)
##   arrays(name, kind, ndim)        -- thin self-description (no zarr metadata)
##
## NOT here, by design: coordinate values, dtype/shape/chunks/codec/fill, inline
## blobs. Those live in the VRT (regenerated each run) and are joined at publish
## time by blocklist. This cache cannot "be Zarr" on its own -- that's the point.
## ----------------------------------------------------------------------------

library(DBI)

mr_open <- function(path, write = FALSE) {
  con <- dbConnect(RSQLite::SQLite(), path, bigint = "integer64",
                   flags = if (write) RSQLite::SQLITE_RWC else RSQLite::SQLITE_RO)
  dbExecute(con, "PRAGMA foreign_keys = ON")
  if (write) {
    dbExecute(con, "PRAGMA journal_mode = WAL")
    dbExecute(con, "PRAGMA synchronous = NORMAL")
    dbExecute(con, "PRAGMA busy_timeout = 30000")
  }
  con
}

mr_init <- function(con) {
  dbExecute(con, "CREATE TABLE IF NOT EXISTS sources(
                    file_id INTEGER PRIMARY KEY, public TEXT UNIQUE)")
  dbExecute(con, "CREATE TABLE IF NOT EXISTS arrays(
                    name TEXT PRIMARY KEY, kind TEXT, ndim INTEGER) WITHOUT ROWID")
  dbExecute(con, "CREATE TABLE IF NOT EXISTS axis(
                    idx0 INTEGER PRIMARY KEY, epoch REAL) WITHOUT ROWID")
  invisible(con)
}

## rank is authoritative in the refs table's idx* columns (never inferred from
## anything stored as metadata).
mr_rank <- function(con, array) {
  ti <- dbGetQuery(con, sprintf("PRAGMA table_info(%s)",
                                dbQuoteIdentifier(con, array)))
  sum(grepl("^idx[0-9]+$", ti$name))
}

## create a data-var refs table of the given rank (idx0..idx{rank-1}), keyed on
## the chunk index. Auto-heals a table left at the wrong rank by an earlier
## schema (CREATE TABLE IF NOT EXISTS would otherwise silently keep it).
mr_declare_array <- function(con, name, rank, kind = "data") {
  stopifnot(rank >= 1L)
  idx <- paste0("idx", seq_len(rank) - 1L)
  tbl <- dbQuoteIdentifier(con, name)
  if (name %in% dbListTables(con)) {
    have <- sum(grepl("^idx[0-9]+$",
      dbGetQuery(con, sprintf("PRAGMA table_info(%s)", tbl))$name))
    if (have != rank) {
      message(sprintf("array '%s': replacing stale table (had %d idx cols, need %d)",
                      name, have, rank))
      dbExecute(con, sprintf("DROP TABLE %s", tbl))
    }
  }
  dbExecute(con, sprintf('CREATE TABLE IF NOT EXISTS %s (
      %s,
      present INTEGER NOT NULL DEFAULT 1,
      file_id INTEGER REFERENCES sources(file_id),
      "offset" INTEGER,
      size     INTEGER,
      PRIMARY KEY (%s)
    ) WITHOUT ROWID', tbl,
    paste0(idx, " INTEGER NOT NULL", collapse = ",\n      "),
    paste(idx, collapse = ", ")))
  dbExecute(con, "INSERT INTO arrays(name,kind,ndim) VALUES(?,?,?)
                  ON CONFLICT(name) DO UPDATE SET kind=excluded.kind, ndim=excluded.ndim",
            params = list(name, kind, rank))
  invisible(name)
}

## MERGE -- the only writer. `refs` is array_name -> data.frame with columns
## idx0..idx{rank-1}, present, path, offset, size. One transaction wraps the
## whole window across arrays (single-writer boundary). Upsert on the chunk PK:
## a prelim->final swap at a fixed global index replaces in place.
mr_merge <- function(con, refs) {
  dbWithTransaction(con, {
    pub <- unique(unlist(lapply(refs, `[[`, "path"), use.names = FALSE))
    pub <- pub[!is.na(pub)]
    if (length(pub))
      dbExecute(con, "INSERT INTO sources(public) VALUES(?)
                      ON CONFLICT(public) DO NOTHING", params = list(pub))
    qn  <- paste(rep("?", length(pub)), collapse = ",")
    fid <- dbGetQuery(con, sprintf(
      "SELECT public, file_id FROM sources WHERE public IN (%s)", qn),
      params = as.list(pub))

    for (nm in names(refs)) {
      df <- refs[[nm]]
      if (!nrow(df)) next
      df$file_id <- fid$file_id[match(df$path, fid$public)]
      rank <- mr_rank(con, nm)
      idx  <- paste0("idx", seq_len(rank) - 1L)
      val  <- c(idx, "present", "file_id", '"offset"', "size")
      set  <- setdiff(val, idx)
      sql  <- sprintf('INSERT INTO %s (%s) VALUES (%s)
                       ON CONFLICT (%s) DO UPDATE SET %s',
        dbQuoteIdentifier(con, nm), paste(val, collapse = ","),
        paste(rep("?", length(val)), collapse = ","),
        paste(idx, collapse = ","),
        paste(sprintf("%s=excluded.%s", set, set), collapse = ", "))
      dbExecute(con, sql, params = c(
        lapply(idx, function(k) df[[k]]),
        list(df$present, df$file_id, df$offset, df$size)))
    }
    TRUE
  })
}

## READ -- the per-chunk seek (single clustered-key lookup + sources join).
mr_chunk <- function(con, array, idx) {
  rank <- mr_rank(con, array)
  stopifnot(length(idx) == rank)
  where <- paste(sprintf("idx%d = ?", seq_len(rank) - 1L), collapse = " AND ")
  dbGetQuery(con, sprintf(
    'SELECT s.public AS path, a."offset", a.size, a.present
     FROM %s a LEFT JOIN sources s USING(file_id) WHERE %s',
    dbQuoteIdentifier(con, array), where), params = as.list(as.integer(idx)))
}

## the stored authoritative axis (date ordering this cache is consistent with).
mr_axis_get <- function(con)
  dbGetQuery(con, "SELECT epoch FROM axis ORDER BY idx0")$epoch

mr_axis_set <- function(con, epoch) {
  dbWithTransaction(con, {
    dbExecute(con, "DELETE FROM axis")
    dbExecute(con, "INSERT INTO axis(idx0,epoch) VALUES(?,?)",
              params = list(seq_along(epoch) - 1L, as.numeric(epoch)))
    TRUE
  })
}
