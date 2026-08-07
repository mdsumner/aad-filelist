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

---

## Collections

| id | R source | Parquet |
|---|---|---|
| `cordex-polarres-ant12-hclim-dmi` | [hclim_dmi.R](sources/hclim_dmi.R) | [parquet](../../releases/download/latest/cordex-polarres-ant12-hclim-dmi.parquet) |
| `cordex-polarres-ant12-racmo-uu-imau` | [racmo_uu_imau.R](sources/racmo_uu_imau.R) | [parquet](../../releases/download/latest/cordex-polarres-ant12-racmo-uu-imau.parquet) |
| `polarres-ant12-mar-v3.13-ulg` | [mar_ulg.R](sources/mar_ulg.R) | [parquet](../../releases/download/latest/polarres-ant12-mar-v3.13-ulg.parquet) |
| `nci-gb6-bran2023` | [bran2023_nci.R](sources/bran2023_nci.R) | [parquet](../../releases/download/latest/nci-gb6-bran2023.parquet) |
| `cdr_sic_G02202_V6` | [cdr_sic_G02202_V6.R](sources/cdr_sic_G02202_V6.R) | [parquet](../../releases/download/latest/cdr_sic_G02202_V6.parquet) |
| `noaa_oisst_daily` | [oisst_daily.R](sources/oisst_daily.R) | [parquet](../../releases/download/latest/noaa_oisst_daily.parquet) |
| `ausantarctic-ghrsst-mur-v2` | [ausantarctic_ghrsst.R](sources/ausantarctic_ghrsst.R) | [parquet](../../releases/download/latest/ausantarctic-ghrsst-mur-v2.parquet) |
| `cordex-polarres-ant12-metum-bas` | [metum_bas.R](sources/metum_bas.R) | [parquet](../../releases/download/latest/cordex-polarres-ant12-metum-bas.parquet) |

In addition the same `latest` release carries `raad_file_db.parquet`, the full
bowerbird+raadtools public file listing, uploaded daily by an external process:

```r
raad <- arrow::read_parquet(
  "https://github.com/mdsumner/aad-filelist/releases/download/latest/raad_file_db.parquet"
)
```

---

## Adding a new collection

1. Copy an existing file from `sources/` as a template.
2. Edit: set a unique `id`, `name`, `source_url`, and appropriate `method` args.
3. Open a PR — CI will lint for duplicate `id` values.
4. Once merged, the next scheduled sync (or a manual dispatch) will generate
   the Parquet and update the summary page.

The `id` field is the stable key: it names the Parquet file and appears in
every row of the manifest. Choose something that won't need to change.
For new collections prefer lowercase, hyphen-separated ids (like
`nci-gb6-bran2023`); a few existing ids use underscores and are kept as-is
for stability, since renaming an id renames its published Parquet file.

---

## Running locally

```bash
Rscript sync.R sources/hclim_dmi.R
```

```r
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
  sync.R                 # Rscript sync.R sources/<name>.R (listing only, always dry-run)
  index.qmd              # GitHub Pages summary (rendered after each sync)
  .github/workflows/
    sync.yml             # matrix sync, uploads Parquet to latest release
    pages.yml            # renders and deploys index.qmd
    lint.yml             # duplicate-id check on sources/**
```
