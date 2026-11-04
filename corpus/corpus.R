## corpus/corpus.R -- listing corpus helpers, schema v0
##
## The corpus keeps every run's listing of every source and derives from them
## what exists now (current), what changed (changes) and how each source
## behaves over time (runs, matrix). Plan:
## /mnt/project-files/listing-corpus/move-plan.md (project files), section 3.
##
## This file needs only curl, xml2, jsonlite and nanoparquet (no bowerbird),
## so the change logic can be tested without running a sync.
##
## A listing is a data.frame with columns
##   url    character  exactly as listed
##   size   double     bytes, NA where unknown (DOUBLE in v0: exact to 2^53)
##   mtime  POSIXct    UTC, NA where unknown
##   etag   character  surrounding quotes and W/ stripped, NA where unknown
##   how    character  s3-list, head, listing, api, none

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

CORPUS_UA <- "aad-filelist listing corpus (https://github.com/mdsumner/aad-filelist)"

## path-safe, unique source key (blueant ids hold slashes and collide)
CORPUS_ID_RX <- "^[A-Za-z0-9._-]+$"

corpus_run_id <- function(t = Sys.time()) format(t, "%Y%m%dT%H%M%SZ", tz = "UTC")

.utc <- function(x) {
  if (inherits(x, "POSIXct")) x <- as.numeric(x)
  if (is.character(x)) return(.parse_time(x))
  as.POSIXct(as.numeric(x), origin = "1970-01-01", tz = "UTC")
}

## ISO 8601 (S3 LastModified) or RFC 1123 (HTTP Last-Modified)
.parse_time <- function(x) {
  x <- as.character(x)
  out <- as.POSIXct(sub("\\.[0-9]+Z$", "Z", x), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  i <- which(is.na(out) & !is.na(x) & nzchar(x))
  if (length(i)) out[i] <- .utc(vapply(x[i], function(s) as.numeric(curl::parse_date(s)), 0))
  out
}

.norm_etag <- function(x) {
  x <- gsub('^W/|"', "", as.character(x))
  x[!is.na(x) & !nzchar(x)] <- NA_character_
  x
}

corpus_listing <- function(url = character(), size = NA_real_, mtime = NA_real_,
                           etag = NA_character_, how = "none") {
  n <- length(url)
  data.frame(url = as.character(url),
             size = rep_len(as.double(size), n),
             mtime = .utc(rep_len(if (inherits(mtime, "POSIXct")) as.numeric(mtime) else mtime, n)),
             etag = .norm_etag(rep_len(as.character(etag), n)),
             how = rep_len(as.character(how), n),
             stringsAsFactors = FALSE)
}

.empty_current <- function() {
  x <- corpus_listing()
  x$first_seen <- character(); x$last_changed <- character(); x$last_seen <- character()
  x
}

## ---------------------------------------------------------------------------
## rules

CORPUS_RULE_DEFAULTS <- list(
  engine = "bowerbird",    # informational; the source file decides
  cadence = "weekly",      # informational in v0: one schedule runs everything
  storage = "auto",        # snapshot, diff, auto (snapshot below 100000 urls)
  snapshot_every = 12,     # with diff storage, a full snapshot every N runs
  head_new = TRUE,         # HEAD urls not seen before when the engine gives no size/etag
  head_all = FALSE,        # HEAD every url every run (small static sources)
  recheck_days = 0,        # also HEAD urls whose date (date_regex) is this recent
  date_regex = NA_character_, # one capture group, YYYYMMDD or YYYYMM, from the url
  head_rate = 5,           # max HEAD requests per second
  max_drop = 0.5,          # a run listing fewer than (1 - max_drop) of the previous count is refused
  credentials = "none"
)

corpus_rule <- function(source_id, rules_file = "rules.tsv") {
  r <- CORPUS_RULE_DEFAULTS
  if (!file.exists(rules_file)) return(r)
  tab <- utils::read.delim(rules_file, comment.char = "#", colClasses = "character",
                           na.strings = "", strip.white = TRUE)
  row <- tab[tab$source_id == source_id, , drop = FALSE]
  if (!nrow(row)) return(r)
  for (k in intersect(names(row), names(r))) {
    v <- row[[k]][1]
    if (is.na(v)) next
    d <- CORPUS_RULE_DEFAULTS[[k]]
    r[[k]] <- if (is.logical(d)) v %in% c("yes", "TRUE", "true", "1")
              else if (is.numeric(d)) as.numeric(v) else v
  }
  r
}

## ---------------------------------------------------------------------------
## engines

## S3 ListObjectsV2, anonymous, paginated. endpoint is the bucket URL
## (virtual-host style) or, with bucket, the service URL (path style).
## The url written is url_base followed by the key.
engine_s3_list <- function(endpoint, prefix = "", url_base, bucket = NULL,
                           accept = NULL, max_pages = Inf) {
  base <- sub("/$", "", endpoint)
  if (!is.null(bucket)) base <- paste0(base, "/", bucket)
  token <- NULL
  pages <- list()
  n_req <- 0
  repeat {
    q <- paste0("?list-type=2&prefix=", curl::curl_escape(prefix),
                if (!is.null(token)) paste0("&continuation-token=", curl::curl_escape(token)))
    res <- curl::curl_fetch_memory(paste0(base, q), handle = curl::new_handle(useragent = CORPUS_UA))
    n_req <- n_req + 1
    if (res$status_code != 200)
      stop("s3-list: HTTP ", res$status_code, " for ", base, " prefix ", prefix)
    x <- xml2::read_xml(res$content)
    xml2::xml_ns_strip(x)
    cont <- xml2::xml_find_all(x, "./Contents")
    if (length(cont))
      pages[[length(pages) + 1]] <- data.frame(
        key = xml2::xml_text(xml2::xml_find_first(cont, "./Key")),
        size = as.double(xml2::xml_text(xml2::xml_find_first(cont, "./Size"))),
        mtime = xml2::xml_text(xml2::xml_find_first(cont, "./LastModified")),
        etag = xml2::xml_text(xml2::xml_find_first(cont, "./ETag")),
        stringsAsFactors = FALSE)
    trunc <- xml2::xml_text(xml2::xml_find_first(x, "./IsTruncated"))
    if (!identical(trunc, "true") || n_req >= max_pages) break
    token <- xml2::xml_text(xml2::xml_find_first(x, "./NextContinuationToken"))
  }
  d <- if (length(pages)) do.call(rbind, pages)
       else data.frame(key = character(), size = double(), mtime = character(), etag = character())
  if (!is.null(accept)) d <- d[grepl(accept, d$key), , drop = FALSE]
  out <- corpus_listing(paste0(url_base, d$key), d$size, .parse_time(d$mtime), d$etag, "s3-list")
  attr(out, "n_requests") <- n_req
  out
}

## NASA CMR granule search (public: listing needs no Earthdata login, only
## downloading does). size from the granule metadata; mtime and the change
## signal from DataGranule ProductionDateTime (a reprocessed granule gets a
## new one; the revision id also moves on metadata-only edits, so it is not
## used). url is the first GET DATA link matching `url_match`.
engine_cmr <- function(concept_id, url_match = "^https://", page_size = 2000,
                       max_pages = Inf) {
  base <- paste0("https://cmr.earthdata.nasa.gov/search/granules.umm_json?collection_concept_id=",
                 concept_id, "&page_size=", page_size, "&sort_key=start_date")
  after <- NULL
  rows <- list()
  n_req <- 0
  repeat {
    h <- curl::new_handle(useragent = CORPUS_UA)
    if (!is.null(after)) curl::handle_setheaders(h, "CMR-Search-After" = after)
    res <- curl::curl_fetch_memory(base, handle = h)
    n_req <- n_req + 1
    if (res$status_code != 200) stop("cmr: HTTP ", res$status_code, " for ", concept_id)
    d <- jsonlite::fromJSON(rawToChar(res$content), simplifyVector = FALSE)
    items <- d$items
    if (!length(items)) break
    rows[[length(rows) + 1]] <- do.call(rbind, lapply(items, function(it) {
      u <- it$umm
      links <- vapply(Filter(function(r) identical(r$Type, "GET DATA"), u$RelatedUrls %||% list()),
                      function(r) r$URL, "")
      link <- links[grepl(url_match, links)][1]
      ad <- u$DataGranule$ArchiveAndDistributionInformation %||% list()
      ## one entry per file in the granule (the data file, its .md5, ...):
      ## take the entry named like the link, else the largest
      bytes <- vapply(ad, function(a) {
        if (!is.null(a$SizeInBytes)) as.double(a$SizeInBytes)
        else if (!is.null(a$Size)) as.double(a$Size) *
          switch(toupper(a$SizeUnit %||% "MB"), KB = 2^10, MB = 2^20, GB = 2^30, B = 1, NA_real_)
        else NA_real_
      }, 0)
      nm <- vapply(ad, function(a) a$Name %||% "", "")
      hit <- if (is.na(link)) integer() else which(nm == basename(link))
      sz <- if (length(hit)) bytes[hit[1]]
            else if (any(!is.na(bytes))) max(bytes, na.rm = TRUE)
            else NA_real_
      prod <- u$DataGranule$ProductionDateTime %||% NA_character_
      data.frame(url = link %||% NA_character_, size = sz, mtime = prod,
                 etag = if (is.na(prod)) NA_character_ else paste0("cmr-prod:", prod),
                 stringsAsFactors = FALSE)
    }))
    after <- curl::parse_headers_list(res$headers)[["cmr-search-after"]]
    if (is.null(after) || length(items) < page_size || n_req >= max_pages) break
  }
  d <- if (length(rows)) do.call(rbind, rows) else
         data.frame(url = character(), size = double(), mtime = character(), etag = character())
  d <- d[!is.na(d$url), , drop = FALSE]
  out <- corpus_listing(d$url, d$size, .parse_time(d$mtime), d$etag, "api")
  attr(out, "n_requests") <- n_req
  out
}

## HEAD each url, at most `rate` per second; failures keep how = "none"
corpus_head <- function(urls, rate = 5, timeout = 60) {
  out <- corpus_listing(urls, how = "none")
  n <- length(urls)
  if (!n) return(out)
  batch <- max(1L, as.integer(rate))
  pool <- curl::new_pool(total_con = batch, host_con = batch)
  for (i in seq(1, n, by = batch)) {
    t0 <- Sys.time()
    for (k in i:min(n, i + batch - 1)) local({
      kk <- k
      h <- curl::new_handle(nobody = TRUE, followlocation = TRUE, timeout = timeout,
                            useragent = CORPUS_UA)
      curl::curl_fetch_multi(urls[kk], handle = h, pool = pool, done = function(res) {
        if (res$status_code >= 400) return(invisible())
        hd <- curl::parse_headers_list(res$headers)
        out$size[kk] <<- as.double(hd[["content-length"]] %||% NA)
        lm <- hd[["last-modified"]] %||% NA_character_
        out$mtime[kk] <<- if (is.na(lm)) .utc(NA_real_) else .parse_time(lm)
        out$etag[kk] <<- .norm_etag(hd[["etag"]] %||% NA_character_)
        out$how[kk] <<- "head"
      }, fail = function(msg) invisible())
    })
    curl::multi_run(pool = pool)
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (el < 1) Sys.sleep(1 - el)
  }
  out
}

## urls whose captured date is within `days` of now (YYYYMMDD or YYYYMM)
corpus_recent <- function(urls, date_regex, days) {
  if (is.na(date_regex) || !days) return(rep(FALSE, length(urls)))
  m <- regmatches(urls, regexec(date_regex, urls))
  d <- vapply(m, function(z) if (length(z) >= 2) z[2] else NA_character_, "")
  d <- ifelse(nchar(d) == 6, paste0(d, "01"), d)
  dt <- as.Date(d, format = "%Y%m%d")
  !is.na(dt) & dt >= Sys.Date() - days
}

## ---------------------------------------------------------------------------
## change rule (plan section 3): per url, the first pair where both sides are
## non-null decides; etag, then size, then mtime as a hint only

corpus_signal <- function(a, b) {
  e <- !is.na(a$etag) & !is.na(b$etag)
  s <- !is.na(a$size) & !is.na(b$size) & !e
  t <- !is.na(a$mtime) & !is.na(b$mtime) & !e & !s
  out <- rep(NA_character_, nrow(b))
  out[e & a$etag != b$etag] <- "etag"
  out[s & a$size != b$size] <- "size"
  out[t & as.numeric(a$mtime) != as.numeric(b$mtime)] <- "mtime-hint"
  out
}

## Compare this run's listing with the previous current. confirm, if given,
## is a function(urls) returning a listing (corpus_head); it settles
## mtime-only differences. Returns list(current, events, counts).
corpus_compare <- function(prev, now, run_id, source_id, confirm = NULL) {
  if (is.null(prev) || !nrow(prev)) prev <- .empty_current()
  now <- now[!is.na(now$url) & nzchar(now$url) & !duplicated(now$url), , drop = FALSE]
  m <- match(now$url, prev$url)
  known <- !is.na(m)
  old <- prev[m[known], , drop = FALSE]
  cur <- now[known, , drop = FALSE]
  sig <- corpus_signal(old, cur)
  false_alarm <- 0L
  hint <- which(sig == "mtime-hint")
  if (length(hint) && is.function(confirm)) {
    h <- confirm(cur$url[hint])
    ok <- h$how != "none"
    s2 <- corpus_signal(old[hint, , drop = FALSE], h)
    changed <- ok & s2 %in% c("etag", "size")
    for (k in c("size", "mtime", "etag", "how")) cur[[k]][hint[ok]] <- h[[k]][ok]
    sig[hint] <- ifelse(changed, s2, ifelse(ok, NA_character_, "mtime-hint"))
    false_alarm <- sum(ok & !changed)
  }
  ## fill forward what this run's engine did not give
  for (k in c("size", "mtime", "etag")) {
    i <- is.na(cur[[k]]) & !is.na(old[[k]])
    cur[[k]][i] <- old[[k]][i]
  }
  i <- cur$how == "none" & old$how != "none"
  cur$how[i] <- old$how[i]

  changed <- !is.na(sig)
  cur$first_seen <- as.character(old$first_seen)
  cur$last_changed <- ifelse(changed, run_id, as.character(old$last_changed))
  cur$last_seen <- rep(run_id, nrow(cur))
  add <- now[!known, , drop = FALSE]
  add$first_seen <- add$last_changed <- add$last_seen <- rep(run_id, nrow(add))
  current <- rbind(cur, add[, names(cur)])
  current <- current[order(current$url), , drop = FALSE]
  rownames(current) <- NULL

  gone <- prev[!prev$url %in% now$url, , drop = FALSE]
  ev <- function(op, x, p = NULL, signal = NA_character_) {
    n <- nrow(x)
    data.frame(source_id = rep(source_id, n), run_id = rep(run_id, n), op = rep(op, n),
               url = x$url, size = x$size, mtime = x$mtime, etag = x$etag, how = x$how,
               prev_size = if (is.null(p)) rep(NA_real_, n) else p$size,
               prev_mtime = if (is.null(p)) .utc(rep(NA_real_, n)) else p$mtime,
               prev_etag = if (is.null(p)) rep(NA_character_, n) else p$etag,
               signal = rep_len(signal, n), stringsAsFactors = FALSE)
  }
  events <- rbind(ev("add", now[!known, , drop = FALSE]),
                  ev("change", cur[changed, , drop = FALSE], old[changed, , drop = FALSE], sig[changed]),
                  ev("remove", gone))
  list(current = current, events = events,
       counts = list(n_urls = nrow(current), n_add = sum(!known), n_remove = nrow(gone),
                     n_change = sum(changed), n_mtime_false_alarm = false_alarm))
}

## a listing far shorter than the last one is a failed listing, not a mass
## withdrawal: refuse it (current stays as it was)
corpus_short <- function(n_prev, n_now, max_drop) {
  n_prev > 0 && n_now < (1 - max_drop) * n_prev
}

## ---------------------------------------------------------------------------
## Parquet I/O (nanoparquet)

corpus_read <- function(path) {
  if (!file.exists(path)) return(NULL)
  x <- as.data.frame(nanoparquet::read_parquet(path), stringsAsFactors = FALSE)
  for (k in intersect(c("mtime", "prev_mtime", "started", "finished"), names(x))) x[[k]] <- .utc(x[[k]])
  x
}

corpus_write <- function(x, path) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  tmp <- paste0(path, ".tmp")
  nanoparquet::write_parquet(x, tmp)
  file.rename(tmp, path)
  invisible(path)
}
