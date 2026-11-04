# Listing corpus

Every run of `sync.yml` keeps the listing of every source, so the repo is
its own history of what each publisher offered. Stores (raad.virtualize),
sooty and raadtools read what exists now (`current`) and what changed
(`changes`); the history answers how reliable a source is and catches a file
replaced at the same URL, which silently invalidates byte references.

Schema v0. Plan and rationale: the project's listing-corpus move plan
(`listing-corpus/move-plan.md`).

## Files

| step | file | does |
|---|---|---|
| list | `corpus/list.R` | one source: bowerbird dry run or another engine, HEAD where needed |
| derive | `corpus/derive.R` | folds a run into the corpus: compare, refuse short listings, write runs, current, changes, matrix |
| helpers | `corpus/corpus.R` | engines (s3-list, HEAD), change rule, rules, Parquet I/O (no bowerbird) |
| test | `corpus/test-corpus.R` | the change rule on fixtures, no network: `Rscript corpus/test-corpus.R` |
| rules | `rules.tsv` | per-source rules; empty cell = default |
| assets | `corpus/flat.sh` | tree <-> flat release asset names ("/" is "__") |
| retry | `corpus/retry.sh` | `retry <cmd>` with backoff, for gh release calls (GitHub 5xx) |

## Where it is published (GitHub releases, for now)

- `run-<run_id>`: that run's files, never rewritten:
  `runs__<id>__<run_id>.parquet` (snapshot or diff) and `<id>.json` (the
  source as run).
- `corpus`: rebuilt every run: `runs.parquet`, `matrix.parquet`,
  `current__<id>.parquet`, `changes__<id>.parquet`,
  `sources__<id>__<hash>.json`.
- `latest`: `<id>.parquet` in the old shape (now with `size` where known),
  for readers that predate the corpus.

When Actions can hold a source.coop credential, the same tree (with "/"
for "__") goes to source.coop as well.

```r
base <- "https://github.com/mdsumner/aad-filelist/releases/download/corpus"
cur <- nanoparquet::read_parquet(url(file.path(base, "current__cdr_sic_G02202_V6.parquet")))
```

## Tables

Run file (`runs/<id>/<run_id>.parquet`): `source_id, run_id, op, url, size,
mtime, etag, how`. `op` is `present` in a snapshot; `add`, `remove`,
`change` in a diff (against `base_run_id` in `runs.parquet`).

- `url` exactly as listed. `size` bytes (DOUBLE in v0), `mtime` UTC,
  `etag` with quotes stripped, all nullable. `how`: `s3-list`, `head`,
  `listing`, `api`, `none` (where size/mtime/etag came from).

`current/<id>.parquet`: `url, size, mtime, etag, how, first_seen,
last_changed, last_seen` (run ids). Present urls only.

`changes/<id>.parquet`: `source_id, run_id, op, url, size, mtime, etag, how,
prev_size, prev_mtime, prev_etag, signal`.

`runs.parquet`: `source_id, run_id, started, finished, ok, kind,
base_run_id, n_urls, n_add, n_remove, n_change, n_mtime_false_alarm,
n_requests, engine, config_hash, runner, message`.

`matrix.parquet`: per source over all runs: success rate, run time,
requests, change and remove rates, mtime false alarms, share of current
rows with size/etag/mtime, and the `how` mix. Change a default in
`rules.tsv` with the matrix row that justified it.

## Change rule

For a url in both the previous `current` and this run, the first pair where
both sides are non-null decides: etag differs -> change; else size differs
-> change; else mtime differs -> HEAD it, and it is a change only if the
HEAD shows a new etag or size (otherwise a false alarm: mtime is bumped,
nothing recorded). Values this run's engine did not give are carried
forward from `current`.

A listing shorter than `(1 - max_drop)` of the last one is refused (the run
row says so, `current` is unchanged): a failed crawl, not a mass
withdrawal. Withdrawn files show as `remove` events.

If `current/<id>` is missing while `runs.parquet` has ok runs of the source
(a release upload that failed after `--clobber` removed the old asset), derive
rebuilds it from the last snapshot and the diffs after it (from the
`run-<run_id>` releases), with `first_seen` and `last_changed` from
`changes`. If the run files cannot be read, the run is refused rather than
logging every url as a new add.

A manual run (Actions, "Sync file listings") takes one source or several,
comma separated. Dispatch a batch as one run: the `corpus` concurrency group
keeps only one run waiting, so a second dispatch cancels the first one queued.

## Sources

A `sources/*.R` file defines `src` (a `bb_source`: the record, and the
bowerbird method). It may also define `engine`, another lister:

```r
engine <- list(type = "s3-list", endpoint = "https://<bucket>.s3.amazonaws.com",
               prefix = "data/", url_base = "https://<bucket>.s3.amazonaws.com/",
               accept = "\\.nc$")   # bucket = "..." for path-style endpoints
```

The source id is the corpus key: `[A-Za-z0-9._-]`, unique, no `__`
(`lint-ids.R`).
