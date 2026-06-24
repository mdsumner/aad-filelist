## ===========================================================================
## STEP 0 -- does `gdal mdim mosaic` go faster from precomputed .vrt leaves
## than from the raw .nc files, on LOCAL paths?
##
## Same files, two ways, warm cache. The .nc run opens each NetCDF (HDF5
## metadata) to read its structure; the .vrt run opens tiny XML instead. The
## question is purely whether that open-cost difference is worth the temp-VRT
## indirection in step 3. It does NOT bear on the precompute's value for the
## remote / distribution legs -- that's already decided.
##
## RUN THIS ON THE MACHINE/FILESYSTEM THAT WILL ACTUALLY DO THE LOCAL MOSAIC
## (Pawsey /rdsi), because the whole effect is filesystem open-latency and it
## differs between the OpenStack PUBLIC mount and /rdsi.
## ===========================================================================

library(gdalraster)

N    <- 400L                              # bump to 365 / 16384 if inconclusive
root <- "/rdsi/PUBLIC/raad/data"         # adjust to wherever PUBLIC is here
glob <- file.path(root,
                  "www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation",
                  "v2.1/access/avhrr/198*/*.nc")      # one+ month of daily OISST

nc <- head(sort(Sys.glob(glob)), N)
stopifnot(length(nc) > 1L)
message(sprintf("%d files", length(nc)))

## --- precompute the atomic VRTs for these N (this cost is amortized in the
##     real pipeline; we time it only for context, not as part of the test) ---
vdir <- tempfile("vrt0_"); dir.create(vdir)
vrt  <- file.path(vdir, paste0(basename(nc), ".vrt"))
gen  <- system.time(
  for (i in seq_along(nc))
    mdim_translate(nc[i], vrt[i], output_format = "VRT", quiet = TRUE)
)

message(sprintf("(context) generated %d VRTs in %.1fs", length(vrt), gen[["elapsed"]]))

out_nc  <- tempfile(fileext = ".vrt")
out_vrt <- tempfile(fileext = ".vrt")

## direct positional args (NOT @filelist -- mdim's @filelist support is
## unconfirmed; 80 paths sit well under ARG_MAX). inputs... then output.
run <- function(inputs, out)
  system2("gdal", c("mdim", "mosaic", inputs, out, "--overwrite"),
          stdout = FALSE, stderr = FALSE)

## warm the page cache for BOTH input sets (and prove both build at all)
stopifnot(run(nc,  out_nc)  == 0L)
stopifnot(run(vrt, out_vrt) == 0L)

## --- timed, warm, a few reps; min is the cleanest steady-state number -------
reps  <- 3L
bench <- function(inputs, out, label) {
  t <- replicate(reps, system.time(run(inputs, out))[["elapsed"]])
  tibble::tibble(input = label, n = length(inputs),
                 min = min(t), median = stats::median(t), max = max(t))
}
res <- dplyr::bind_rows(
  bench(nc,  out_nc,  "nc"),
  bench(vrt, out_vrt, "vrt")
)
print(res)
message(sprintf("nc / vrt  (min elapsed): %.2fx",
                res$min[res$input == "nc"] / res$min[res$input == "vrt"]))

## --- sanity: the two mosaics must describe the SAME structure, else the
##     timing isn't apples-to-apples. Compare the dimension lines. ------------
dims <- function(f)
  grep("/time|/lat|/lon|/zlev",
       system2("gdal", c("mdim", "info", f), stdout = TRUE), value = TRUE)
cat("\n-- nc mosaic dims --\n");  cat(dims(out_nc),  sep = "\n")
cat("\n-- vrt mosaic dims --\n"); cat(dims(out_vrt), sep = "\n")
