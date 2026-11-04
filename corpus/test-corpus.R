#!/usr/bin/env Rscript
## corpus/test-corpus.R -- the change rule and short-listing guard on fixtures
## (no network). Run from the repo root: Rscript corpus/test-corpus.R

source("corpus/corpus.R")
ok <- 0
check <- function(cond, what) {
  if (!isTRUE(cond)) stop("FAIL: ", what)
  ok <<- ok + 1
}
t0 <- as.POSIXct("2026-11-01 00:00:00", tz = "UTC")

## run 1: four urls, mixed evidence
r1 <- corpus_listing(paste0("https://h/f", 1:4, ".nc"),
                     size = c(10, 20, NA, NA), mtime = c(t0, t0, t0, NA),
                     etag = c('"a1"', NA, NA, NA), how = c("s3-list", "head", "listing", "none"))
c1 <- corpus_compare(NULL, r1, "R1", "src")
check(c1$counts$n_add == 4 && c1$counts$n_change == 0, "first run is all adds")
check(all(c1$current$first_seen == "R1"), "first_seen set")
check(identical(c1$current$etag[1], "a1"), "etag quotes stripped")

## run 2: f1 new etag same size (etag decides), f2 new size, f3 only mtime moved
## (HEAD says same size: false alarm), f4 still unknown and engine gives nothing,
## f5 added, nothing removed
r2 <- corpus_listing(paste0("https://h/f", 1:5, ".nc"),
                     size = c(10, 21, NA, NA, 5), mtime = c(t0, t0, t0 + 60, NA, t0),
                     etag = c("a2", NA, NA, NA, NA), how = c("s3-list", "head", "listing", "none", "head"))
heads <- function(u) corpus_listing(u, size = 30, mtime = t0 + 60, how = "head")
prev <- c1$current
prev$size[3] <- 30   # f3 was sized by an earlier HEAD
c2 <- corpus_compare(prev, r2, "R2", "src", confirm = heads)
ev <- c2$events
check(c2$counts$n_add == 1 && ev$url[ev$op == "add"] == "https://h/f5.nc", "f5 added")
chg <- ev[ev$op == "change", ]
check(setequal(chg$url, c("https://h/f1.nc", "https://h/f2.nc")), "f1 and f2 changed")
check(chg$signal[chg$url == "https://h/f1.nc"] == "etag", "etag signal")
check(chg$signal[chg$url == "https://h/f2.nc"] == "size", "size signal")
check(chg$prev_size[chg$url == "https://h/f2.nc"] == 20, "prev_size kept")
check(c2$counts$n_mtime_false_alarm == 1, "mtime-only difference settled by HEAD")
cur <- c2$current
check(cur$last_changed[cur$url == "https://h/f3.nc"] == "R1", "false alarm is not a change")
check(as.numeric(cur$mtime[cur$url == "https://h/f3.nc"]) == as.numeric(t0 + 60), "mtime bumped")
check(cur$size[cur$url == "https://h/f1.nc"] == 10 && cur$last_changed[1] == "R2", "f1 last_changed")

## run 3: f2 withdrawn; f1 listed with no evidence keeps its etag (fill forward)
r3 <- corpus_listing(paste0("https://h/f", c(1, 3, 4, 5), ".nc"), how = "none")
c3 <- corpus_compare(c2$current, r3, "R3", "src")
check(c3$counts$n_remove == 1 && c3$events$url[c3$events$op == "remove"] == "https://h/f2.nc", "f2 removed")
check(c3$counts$n_change == 0, "no evidence is no change")
check(identical(c3$current$etag[c3$current$url == "https://h/f1.nc"], "a2"), "etag filled forward")
check(c3$current$how[c3$current$url == "https://h/f1.nc"] == "s3-list", "how filled forward")

## without confirm, an mtime-only move is reported as a hint
r4 <- r3; r4$mtime <- t0 + 3600
c4 <- corpus_compare(c3$current, r4, "R4", "src")
check(all(c4$events$signal[c4$events$op == "change"] == "mtime-hint"), "unconfirmed mtime is a hint")

## short listing guard
check(corpus_short(1000, 400, 0.5), "60% drop refused")
check(!corpus_short(1000, 600, 0.5), "40% drop accepted")
check(!corpus_short(0, 0, 0.5), "first run never short")

## rebuild a lost current from run files: snapshot R1, then diffs R2, R3.
## Diffs hold events only, so values learned without an event (an mtime
## false alarm, a size filled by HEAD) wait for the next run's listing.
snap <- function(cmp, rid) { x <- cmp$current
  data.frame(source_id = "src", run_id = rid, op = "present", url = x$url, size = x$size,
             mtime = x$mtime, etag = x$etag, how = x$how, stringsAsFactors = FALSE) }
diffs <- function(cmp) cmp$events[, c("source_id", "run_id", "op", "url", "size", "mtime", "etag", "how")]
b2 <- corpus_compare(c1$current, r2, "R2", "src", confirm = heads)
b3 <- corpus_compare(b2$current, r3, "R3", "src")
files <- list(R1 = snap(c1, "R1"), R2 = diffs(b2), R3 = diffs(b3))
mine <- data.frame(run_id = c("R1", "R2", "R3"), ok = TRUE, kind = c("snapshot", "diff", "diff"))
rb <- corpus_rebuild_current(mine, function(rid) files[[rid]], rbind(c1$events, b2$events, b3$events))
check(identical(rb$url, b3$current$url), "rebuilt current has the same urls")
check(identical(rb$etag, b3$current$etag), "rebuilt etags")
check(identical(rb$last_changed, b3$current$last_changed), "rebuilt last_changed")
check(identical(rb$first_seen, b3$current$first_seen), "rebuilt first_seen")
check(rb$size[rb$url == "https://h/f2.nc"] == 21 || !("https://h/f2.nc" %in% rb$url), "change event size applied")
check(is.null(corpus_rebuild_current(mine, function(rid) NULL)), "no run files: no rebuild")

## recent dates
u <- c(sprintf("x_%s_.nc", format(Sys.Date() - 3, "%Y%m%d")), "x_19800101_.nc", "nodate.nc")
check(identical(corpus_recent(u, "_([0-9]{8})_", 7), c(TRUE, FALSE, FALSE)), "recheck window")

## times
p <- .parse_time(c("2025-04-26T21:01:58.000Z", "Wed, 21 Oct 2015 07:28:00 GMT"))
check(format(p[2], "%Y-%m-%d %H:%M", tz = "UTC") == "2015-10-21 07:28", "RFC 1123 date")

message("OK: ", ok, " checks")
