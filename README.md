# aad-filelist

File-listing cache for Antarctic and Southern Ocean model output collections.

Each collection is defined in its own R file under [`sources/`](sources/) using
[bowerbird](https://docs.ropensci.org/bowerbird/). A scheduled GitHub Actions
workflow enumerates each collection and publishes the result as a Parquet file
on the [latest release](../../releases/latest).

**Summary page:** <https://mdsumner.github.io/aad-filelist/>

---

## Using a file listing

```r
library(arrow)

## read any listing directly from the release
hclim <- read_parquet(
  "https://github.com/mdsumner/aad-filelist/releases/download/latest/cordex-polarres-ant12-hclim-dmi.parquet"
)

dplyr::glimpse(hclim)
```

Each Parquet file has columns:

| column | description |
|---|---|
| `id` | bowerbird source id (matches filename) |
| `path` | local mirror path (URL structure preserved) |
| `url` | remote URL of the file |
| `size` | file size in bytes |
| `was_downloaded` | logical; FALSE in a dry-run listing |
| `ok` | logical; sync success |
| `sync_time` | UTC timestamp of the sync run |
| `dry_run` | logical; TRUE if this was an enumeration-only run |

---

## Collections

| id | R source | Parquet |
|---|---|---|
| `cordex-polarres-ant12-hclim-dmi` | [hclim_dmi.R](sources/hclim_dmi.R) | [↓ parquet](../../releases/download/latest/cordex-polarres-ant12-hclim-dmi.parquet) |
| `cordex-polarres-ant12-racmo-uu-imau` | [racmo_uu_imau.R](sources/racmo_uu_imau.R) | [↓ parquet](../../releases/download/latest/cordex-polarres-ant12-racmo-uu-imau.parquet) |
| `polarres-ant12-mar-v3.13-ulg` | [mar_ulg.R](sources/mar_ulg.R) | [↓ parquet](../../releases/download/latest/polarres-ant12-mar-v3.13-ulg.parquet) |

---

## Adding a new collection

1. Copy an existing file from `sources/` as a template.
2. Edit: set a unique `id`, `name`, `source_url`, and appropriate `method` args.
3. Open a PR — CI will lint for duplicate `id` values.
4. Once merged, the next scheduled sync (or a manual dispatch) will generate
   the Parquet and update the summary page.

The `id` field is the stable key: it names the Parquet file and appears in
every row of the manifest. Choose something that won't need to change.

---

## Running locally

```r
## dry run for one source (enumerate, don't download)
DRY_RUN=TRUE Rscript sync.R sources/hclim_dmi.R

## or from within R
source("sources/hclim_dmi.R")   # defines `src`
cf <- bowerbird::bb_config(local_file_root = "~/data/polarres") |>
  bowerbird::bb_add(src)
status <- bowerbird::bb_sync(cf, verbose = TRUE, dry_run = TRUE)
```

---

## Repo layout

```
aad-filelist/
  sources/
    hclim_dmi.R          # one file per collection; defines a single `src` object
    racmo_uu_imau.R
    mar_ulg.R
  sync.R                 # Rscript sync.R sources/<name>.R [--dry-run]
  index.qmd              # GitHub Pages summary (rendered on each release)
  .github/workflows/
    sync.yml             # matrix sync, uploads Parquet to latest release
    pages.yml            # renders and deploys index.qmd
```
