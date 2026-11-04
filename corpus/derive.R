#!/usr/bin/env Rscript
## corpus/derive.R -- fold one run's listings into the corpus
##
## Usage: Rscript corpus/derive.R RUN_ID LISTING_DIR CORPUS_DIR RUN_DIR
##
## LISTING_DIR  what corpus/list.R wrote for each source of this run
## CORPUS_DIR   the derived corpus as it stood (may be empty on the first run):
##                runs.parquet, current/<id>.parquet, changes/<id>.parquet,
##                sources/<id>/<config_hash>.json; updated in place
## RUN_DIR      receives this run's files, never rewritten later:
##                runs/<id>/<run_id>.parquet (snapshot or diff), <id>.json
##
## Per source: compare with current (corpus_compare; mtime-only differences
## settled by HEAD), refuse a short listing (rule max_drop), choose snapshot
## or diff storage (rule storage), append the events to changes/, a row to
## runs.parquet, and rebuild matrix.parquet.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4) stop("Usage: Rscript corpus/derive.R RUN_ID LISTING_DIR CORPUS_DIR RUN_DIR")
run_id <- args[1]; listing_dir <- args[2]; corpus_dir <- args[3]; run_dir <- args[4]

here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
source(file.path(here, "corpus.R"))

dir.create(run_dir, showWarnings = FALSE, recursive = TRUE)

## a past run's file: corpus_dir/runs/<id>/<run_id>.parquet, else the
## run-<run_id> release under CORPUS_RUN_BASE (sync.yml sets it)
.fetch_run <- function(id, rid) {
  f <- file.path(corpus_dir, "runs", id, paste0(rid, ".parquet"))
  if (file.exists(f)) return(corpus_read(f))
  base <- Sys.getenv("CORPUS_RUN_BASE")
  if (!nzchar(base)) return(NULL)
  tmp <- tempfile(fileext = ".parquet")
  u <- sprintf("%s/run-%s/runs__%s__%s.parquet", base, rid, id, rid)
  ok <- tryCatch(utils::download.file(u, tmp, mode = "wb", quiet = TRUE) == 0,
                 error = function(e) FALSE, warning = function(w) FALSE)
  if (ok) corpus_read(tmp) else NULL
}
runs_file <- file.path(corpus_dir, "runs.parquet")
runs <- corpus_read(runs_file)
new_runs <- list()

status_files <- list.files(listing_dir, pattern = "\\.status\\.json$", full.names = TRUE)
if (!length(status_files)) stop("derive: no status files in ", listing_dir)

for (sf in status_files) {
  st <- jsonlite::read_json(sf)
  id <- st$source_id
  rule <- corpus_rule(id, "rules.tsv")
  row <- list(source_id = id, run_id = run_id, started = .parse_time(st$started),
              finished = .parse_time(st$finished %||% st$started),
              ok = isTRUE(st$ok), kind = NA_character_, base_run_id = NA_character_,
              n_urls = NA_real_, n_add = NA_real_, n_remove = NA_real_, n_change = NA_real_,
              n_mtime_false_alarm = NA_real_, n_requests = as.double(st$n_requests %||% NA),
              engine = st$engine %||% NA_character_, config_hash = NA_character_,
              runner = st$runner %||% NA_character_, message = st$message %||% "")

  ## the definition as run, kept once per hash
  def <- file.path(listing_dir, paste0(id, ".json"))
  if (file.exists(def)) {
    h <- unname(tools::md5sum(def))
    row$config_hash <- substr(h, 1, 12)
    d <- file.path(corpus_dir, "sources", id)
    dir.create(d, showWarnings = FALSE, recursive = TRUE)
    target <- file.path(d, paste0(row$config_hash, ".json"))
    if (!file.exists(target)) file.copy(def, target)
    file.copy(def, file.path(run_dir, paste0(id, ".json")), overwrite = TRUE)
  }

  lst_file <- file.path(listing_dir, paste0(id, ".listing.parquet"))
  if (row$ok && file.exists(lst_file)) {
    now <- corpus_read(lst_file)
    cur_file <- file.path(corpus_dir, "current", paste0(id, ".parquet"))
    prev <- corpus_read(cur_file)
    mine <- if (is.null(runs)) NULL else runs[runs$source_id == id & runs$ok, , drop = FALSE]
    lost <- is.null(prev) && !is.null(mine) && nrow(mine) > 0
    if (lost) {
      ## current/<id> is gone but the source has ok runs: rebuild it
      prev <- corpus_rebuild_current(mine, function(rid) .fetch_run(id, rid),
                                     corpus_read(file.path(corpus_dir, "changes", paste0(id, ".parquet"))))
      message(id, ": current missing, ",
              if (is.null(prev)) "could not rebuild it from run files" else
                sprintf("rebuilt from run files (%d url(s))", nrow(prev)))
    }
    n_prev <- if (is.null(prev)) 0 else nrow(prev)
    if (lost && is.null(prev)) {
      row$ok <- FALSE
      row$n_urls <- nrow(now)
      row$message <- "current missing and not rebuilt from run files: run not folded in"
    } else if (corpus_short(n_prev, nrow(now), rule$max_drop)) {
      row$ok <- FALSE
      row$n_urls <- nrow(now)
      row$message <- sprintf("short listing refused: %d url(s), previous run %d (max_drop %.2f)",
                             nrow(now), n_prev, rule$max_drop)
      message(id, ": ", row$message)
    } else {
      cmp <- corpus_compare(prev, now, run_id, id,
                            confirm = function(u) corpus_head(u, rate = rule$head_rate))
      ## storage: a snapshot, or a diff against the last run of this source
      last <- if (is.null(mine) || !nrow(mine)) NULL else mine[nrow(mine), ]
      since_snap <- if (is.null(mine) || !nrow(mine)) Inf else {
        s <- which(mine$kind == "snapshot")
        if (length(s)) nrow(mine) - max(s) + 1 else Inf
      }
      kind <- switch(rule$storage,
                     snapshot = "snapshot",
                     diff = if (is.null(last) || since_snap >= rule$snapshot_every) "snapshot" else "diff",
                     auto = if (nrow(cmp$current) < 1e5 || is.null(last) ||
                                since_snap >= rule$snapshot_every) "snapshot" else "diff")
      out <- if (kind == "snapshot") {
        x <- cmp$current
        data.frame(source_id = id, run_id = run_id, op = rep("present", nrow(x)), url = x$url,
                   size = x$size, mtime = x$mtime, etag = x$etag, how = x$how, stringsAsFactors = FALSE)
      } else cmp$events[, c("source_id", "run_id", "op", "url", "size", "mtime", "etag", "how")]
      corpus_write(out, file.path(run_dir, "runs", id, paste0(run_id, ".parquet")))
      corpus_write(cmp$current, cur_file)
      if (nrow(cmp$events)) {
        ch_file <- file.path(corpus_dir, "changes", paste0(id, ".parquet"))
        old <- corpus_read(ch_file)
        corpus_write(if (is.null(old)) cmp$events else rbind(old, cmp$events), ch_file)
      }
      row$kind <- kind
      row$base_run_id <- if (kind == "diff") last$run_id else NA_character_
      row[names(cmp$counts)] <- lapply(cmp$counts, as.double)
      message(sprintf("%s: %d url(s), +%d -%d ~%d (%s)", id, cmp$counts$n_urls, cmp$counts$n_add,
                      cmp$counts$n_remove, cmp$counts$n_change, kind))
    }
  } else if (!nzchar(row$message)) row$message <- "no listing"
  new_runs[[length(new_runs) + 1]] <- as.data.frame(row, stringsAsFactors = FALSE)
}

new_runs <- do.call(rbind, new_runs)
runs <- if (is.null(runs)) new_runs else rbind(runs, new_runs[, names(runs)])
corpus_write(runs, runs_file)

## the learning matrix: one row per source over all its runs
mat <- do.call(rbind, lapply(split(runs, runs$source_id), function(r) {
  ok <- r[r$ok, , drop = FALSE]
  cur <- corpus_read(file.path(corpus_dir, "current", paste0(r$source_id[1], ".parquet")))
  frac <- function(x) if (is.null(cur) || !nrow(cur)) NA_real_ else mean(!is.na(x))
  data.frame(source_id = r$source_id[1], n_runs = nrow(r), success_rate = mean(r$ok),
             last_ok_run = if (nrow(ok)) ok$run_id[nrow(ok)] else NA_character_,
             n_urls = if (nrow(ok)) ok$n_urls[nrow(ok)] else NA_real_,
             median_seconds = stats::median(as.numeric(r$finished) - as.numeric(r$started), na.rm = TRUE),
             median_requests = stats::median(r$n_requests, na.rm = TRUE),
             change_per_run = if (nrow(ok)) mean(ok$n_change, na.rm = TRUE) else NA_real_,
             remove_per_run = if (nrow(ok)) mean(ok$n_remove, na.rm = TRUE) else NA_real_,
             mtime_false_alarms = sum(ok$n_mtime_false_alarm, na.rm = TRUE),
             share_size = frac(cur$size), share_etag = frac(cur$etag), share_mtime = frac(cur$mtime),
             how = if (is.null(cur) || !nrow(cur)) NA_character_
                   else paste(names(table(cur$how)), table(cur$how), sep = "=", collapse = ","),
             stringsAsFactors = FALSE)
}))
corpus_write(mat, file.path(corpus_dir, "matrix.parquet"))
print(mat, row.names = FALSE)
if (any(!new_runs$ok)) message("not ok this run: ", paste(new_runs$source_id[!new_runs$ok], collapse = ", "))
