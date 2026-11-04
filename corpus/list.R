#!/usr/bin/env Rscript
## corpus/list.R -- list one source for a corpus run
##
## Usage: Rscript corpus/list.R sources/<name>.R RUN_ID OUT_DIR [PREV_DIR]
##
## The source file defines `src` (a bb_source: the record, and the bowerbird
## method) and optionally `engine`, a list naming another lister:
##   engine <- list(type = "s3-list", endpoint = ..., prefix = ..., url_base = ...,
##                  bucket = NULL, accept = NULL)
## or list(type = "urls", urls = c(...)) for a fixed set of files (sized by HEAD).
## Without `engine` the listing is a bowerbird dry run (urls only). `bb_id`,
## if set, is the bowerbird/blueant id when it differs from the corpus key.
##
## PREV_DIR holds current__<source_id>.parquet from the previous run, if any:
## with rule head_new, urls not in it (or with no size there) are HEADed; with
## recheck_days, recent urls are HEADed again.
##
## Writes to OUT_DIR:
##   <source_id>.listing.parquet   url, size, mtime, etag, how (corpus/corpus.R)
##   <source_id>.json              the source as run (record, engine, rule)
##   <source_id>.status.json       started, finished, ok, message, engine, n_requests
##   legacy/<source_id>.parquet    the old `latest` shape (id, path, url, size,
##                                 was_downloaded, ok, sync_time), now with size

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) stop("Usage: Rscript corpus/list.R sources/<name>.R RUN_ID OUT_DIR [PREV_DIR]")
source_file <- args[1]; run_id <- args[2]; out_dir <- args[3]
prev_dir <- if (length(args) >= 4) args[4] else ""

here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
source(file.path(here, "corpus.R"))
.iso_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
dir.create(file.path(out_dir, "legacy"), showWarnings = FALSE, recursive = TRUE)

e <- new.env(parent = baseenv())
source(source_file, local = e)
src <- e$src
engine <- e$engine
stopifnot(inherits(src, "data.frame"), "id" %in% names(src))
source_id <- src$id[[1]]
if (!grepl(CORPUS_ID_RX, source_id)) stop("source id is not path safe: ", source_id)
rule <- corpus_rule(source_id, "rules.tsv")
bb_version <- tryCatch(as.character(utils::packageVersion("bowerbird")), error = function(e) NA_character_)
engine_name <- if (is.null(engine)) paste("bowerbird", bb_version) else engine$type
message("source ", source_id, " (", engine_name, "), run ", run_id)

status <- list(source_id = source_id, run_id = run_id, started = .iso_now(),
               ok = FALSE, message = "", engine = engine_name, n_requests = 0,
               runner = Sys.getenv("CORPUS_RUNNER", "local"))
write_status <- function() {
  status$finished <- .iso_now()
  jsonlite::write_json(status, file.path(out_dir, paste0(source_id, ".status.json")),
                       auto_unbox = TRUE, pretty = TRUE)
}

## the source as run: record, engine, rule (method args deparsed: some are functions)
rec <- lapply(as.list(src), function(v) {
  v <- if (is.list(v)) v[[1]] else v
  if (is.function(v)) paste(deparse(v), collapse = "\n") else v
})
rec$method <- lapply(src$method[[1]], function(v) if (is.function(v)) paste(deparse(v), collapse = "\n") else v)
def <- list(source_id = source_id, bb_id = e$bb_id %||% source_id, source_file = basename(source_file),
            engine = engine %||% list(type = "bowerbird"), rule = rule, record = rec,
            bowerbird_version = bb_version)
jsonlite::write_json(def, file.path(out_dir, paste0(source_id, ".json")), auto_unbox = TRUE,
                     pretty = TRUE, null = "null", na = "null", force = TRUE)

res <- tryCatch({
  if (is.null(engine)) {
    cf <- bowerbird::bb_add(bowerbird::bb_config(local_file_root = Sys.getenv("MIRROR_ROOT", tempdir())), src)
    st <- bowerbird::bb_sync(cf, verbose = TRUE, dry_run = TRUE, create_root = TRUE)
    ## bb_sync returns one row per source; `status` is a logical column in
    ## current bowerbird (a data frame with `ok` in some older versions)
    okv <- st$status
    if (is.data.frame(okv)) okv <- okv$ok
    if (!isTRUE(as.logical(unlist(okv))[1])) stop("bb_sync reported not ok")
    fd <- st$files[[1]]
    if (!is.data.frame(fd)) fd <- data.frame(url = character())
    u <- if ("url" %in% names(fd)) fd$url else character()
    u <- u[!is.na(u) & nzchar(u)]
    lst <- corpus_listing(u, how = "none")
  } else if (identical(engine$type, "urls")) {
    ## a fixed list of files (static products): sized by HEAD
    lst <- corpus_listing(unique(engine$urls), how = "none")
  } else if (identical(engine$type, "cmr")) {
    lst <- engine_cmr(engine$concept_id, engine$url_match %||% "^https://")
    status$n_requests <- attr(lst, "n_requests") %||% 0
  } else if (identical(engine$type, "s3-list")) {
    lst <- engine_s3_list(engine$endpoint, engine$prefix %||% "", engine$url_base,
                          bucket = engine$bucket, accept = engine$accept)
    status$n_requests <- attr(lst, "n_requests") %||% 0
  } else stop("unknown engine type ", engine$type)

  ## HEAD what the engine could not size: new urls, and recent ones again
  prev <- corpus_read(file.path(prev_dir, paste0("current__", source_id, ".parquet")))
  need <- rep(FALSE, nrow(lst))
  if (rule$head_new) {
    unsized <- is.na(lst$size) & is.na(lst$etag)
    known <- if (is.null(prev)) rep(FALSE, nrow(lst))
             else lst$url %in% prev$url[!is.na(prev$size) | !is.na(prev$etag)]
    need <- need | (unsized & !known)
  }
  if (rule$head_all) need <- need | lst$how %in% c("none", "listing")
  need <- need | (lst$how %in% c("none", "listing") &
                  corpus_recent(lst$url, rule$date_regex, rule$recheck_days))
  if (any(need)) {
    message("HEAD ", sum(need), " url(s) at ", rule$head_rate, "/s")
    h <- corpus_head(lst$url[need], rate = rule$head_rate)
    ok <- h$how != "none"
    idx <- which(need)[ok]
    lst[idx, c("size", "mtime", "etag", "how")] <- h[ok, c("size", "mtime", "etag", "how")]
    status$n_requests <- status$n_requests + sum(need)
    if (any(!ok)) message("HEAD failed for ", sum(!ok), " url(s)")
  }
  lst
}, error = function(err) err)

if (inherits(res, "error")) {
  status$message <- conditionMessage(res)
  write_status()
  message("FAILED: ", status$message)
  quit(status = 1)
}

corpus_write(res, file.path(out_dir, paste0(source_id, ".listing.parquet")))
legacy <- data.frame(id = source_id, path = NA_character_, url = res$url, size = res$size,
                     was_downloaded = FALSE, ok = TRUE, sync_time = Sys.time(),
                     stringsAsFactors = FALSE)
corpus_write(legacy, file.path(out_dir, "legacy", paste0(source_id, ".parquet")))
status$ok <- TRUE
status$n_urls <- nrow(res)
write_status()
message("listed ", nrow(res), " url(s); size known for ", sum(!is.na(res$size)))
