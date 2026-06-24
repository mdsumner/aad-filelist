## ===========================================================================
## step-4+-virtualization.R  -- NOTES / PICK-UP POINT (no code yet)
##
## Where we are: the whole OISST AVHRR archive (1981-09-01 .. present) is one
## coherent multidim VRT cube. `gdal mdim info` confirms:
##   /time 16365, /lat 720, /lon 1440, /zlev 1
##   vars anom/err/ice/sst, each [16365, 1, 720, 1440], chunk [1, 1, 720, 1440]
##   => exactly one chunk per timestep per variable. clean, regular, no partial
##      chunks on the time axis. attributes + nodata + valid ranges intact.
##
## How we got here (recap, so the next session has the thread):
##   - bowerbird mirrors bytes (OpenStack, PUBLIC/ mounted); separate from
##     mdsumner/aad-filelist (dry-run collections + the big list).
##   - per-file atomic mdim VRT -> Acacia s3://aad-index/mdim-vrt/ key/value
##     (key = protocol-less path + .vrt, value = VRT xml, SourceFilename made
##     absolute via /vsicurl/https://). THIS STORE IS A PUBLISHED PRODUCT, not
##     a stage in this pipeline -- runs daily as general infra, set aside here.
##   - raadfiles defines the SET: get_raad_file_names() -> pattern cull ->
##     date-stamp -> arrange(date, preliminary) -> distinct(date) [dedup fix:
##     arrange BEFORE distinct, preference explicit; port back to raadfiles].
##     OISST currently 0 dups (one file/day in the stable interior).
##   - mosaic from /rdsi paths DIRECTLY (no leaf injection) via @filelist.
##
## STEP 0 finding (banked): mdim mosaic on .nc vs precomputed .vrt leaves is
## only ~1.2-1.3x (warm), stable across N. NOT worth the temp-VRT indirection
## on the LOCAL leg. Precompute keeps its value on remote/distribution only.
## Confirmed: @filelist works for `gdal mdim mosaic`.
##
## mdim mosaic is SERIAL by source (verified in GDAL source: no num_threads /
## WorkerThreadPool in the mdim path; flag is a no-op). The flat 16k build is a
## ONE-TIME cold cost. Method for "does op X thread?": grep call-site for
## numthreads / WorkerThreadPool; --json-usage for this build; NEWS for when.
##
## TWO RENDERS (build once, sub twice -- two layers, keep distinct):
##   - leaf layer:   each daily VRT's inner <SourceFilename> -> the .nc
##                   (/rdsi/PUBLIC/raad/data/{key}  vs  /vsicurl/https://{key})
##   - mosaic layer: the mosaic's sources -> the leaves
##   vrt_local and vrt_absolute differ ONLY by the inner-leaf sub. Considered a
##   neutral placeholder (RAADROOT/) so neither is privileged -- decide at the
##   render step. (relativeToVRT=2 / GDAL_VRT_PREFIX is the upstream wish; text
##   sub is the userspace stand-in and is the normalized idiom in py/STAC/s3.)
##
## ---------------------------------------------------------------------------
## NEXT (the actual step-4+ work):
##
## 1. mdim VRT -> kerchunk/Zarr byte-refs Parquet store. (done this before;
##    this just brings raad-family to the door.) The cube IS the spec:
##    16365 x 4 chunk-refs + small coord arrays; one ref = (key -> day's .nc
##    byte range for that var); regular grid, no time-edge cases.
##
## 2. refs-Parquet -> Icechunk. (also done before.) First layer in the stack
##    with REAL versioned commits -> natively answers the parked "changes"
##    (same-key-new-bytes) problem.
##
## 3. THEN review UPDATES across all three layers side by side:
##    - VRT mosaic: append = clone last <Source>, splice, extend /time index.
##      vrtstack-level userspace concat tool; the full VRT is template+proof-of-
##      conformability. Assert conformability against VRT-recorded structure
##      (NOT by re-opening .nc). Two cases: new-day (append-1) and open-month
##      edit (replace/insert: preliminary->final, late arrivals).
##    - refs-Parquet: append = new time-chunk rows.
##    - Icechunk: append = a commit. <- where update wants to live.
##    Everything is APPEND-SHAPED because time chunk = 1/day. closed months
##    immutable; only the open ~2 weeks churn (prelim/final + changes).
##
## ---------------------------------------------------------------------------
## LOOSE THREAD to verify before trusting into Zarr-land:
##   Is /time self-contained in the VRT, or does it source back into each .nc?
##   The step-0 ~1.2x hinted the time coord reaches back. Free locally; a real
##   cost over /vsicurl (kerchunk step WILL read time). Check: `gdal mdim info`
##   on the /vsicurl render (or with one source moved aside) -> baked vs
##   referential. If referential, that's a self-containment issue for the
##   atomic VRTs generally, relevant to the published store too.
## ===========================================================================
