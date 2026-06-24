## ===========================================================================
## STEP 2 -- defined set -> one multidim mosaic VRT, rendered for local use.
## (the old "step 3"; the per-file VRT store is off this path, so this is now
##  the second and final stage of the live mosaic pipeline.)
##
## IN:  set = data.frame(date, file)   from step 1  (file = protocol-less key)
## OUT: a mosaic VRT whose time axis is the set, sources = local /rdsi paths.
##
## Step 0 proved mdim mosaic on /rdsi .nc paths is ~1.2x of the .vrt route --
## not worth leaf injection -- so we feed .nc paths straight in. The set is
## already date-ordered and one-per-day, so source order == time order.
## ===========================================================================

library(dplyr)

## `set` carried forward from step 1 (date, file). Re-derive here for a
## standalone run if needed:
# source("step1_define_set.R")

root        <- "/rdsi/PUBLIC/raad/data/"     # local prefix (read-only mount)
vsicurl_base<- "/vsicurl/https://"           # remote prefix (host is in `file`)

## --- render the set's keys to local source paths ----------------------------
## order matters: mosaic stacks in input order, and `set` is arrange(date)d,
## so the Nth source becomes the Nth time slice. Keep them aligned.
local_src <- paste0(root, set$file)

## sanity before we hand 16k paths to GDAL: they must actually exist locally,
## and be in strict date order (no surprise from a manifest vs mount mismatch)
miss <- !file.exists(local_src)
if (any(miss)) {
  message(sprintf("WARNING: %d of %d sources missing on %s",
                  sum(miss), length(local_src), root))
  print(utils::head(set$file[miss]))
}
stopifnot(!is.unsorted(set$date))            # date order == source order

## --- @filelist (confirmed working for `gdal mdim mosaic`) -------------------
## one source per line; avoids ARG_MAX and keeps the call legible.
flist <- tempfile("mosaic_src_", fileext = ".txt")
writeLines(local_src[!miss], flist)

out_local <- tempfile("oisst_local_", fileext = ".vrt")
status <- system2("gdal",
                  c("mdim", "mosaic", paste0("@", flist), out_local, "--overwrite"),
                  stdout = TRUE, stderr = TRUE)

if (!is.null(attr(status, "status")) && attr(status, "status") != 0L)
  stop("mdim mosaic failed:\n", paste(status, collapse = "\n"))

## --- confirm the mosaic matches the set we defined --------------------------
info <- system2("gdal", c("mdim", "info", out_local), stdout = TRUE)
cat(grep("/time|/lat|/lon|/zlev", info, value = TRUE), sep = "\n")
message(sprintf("\nmosaic: %s", out_local))
message(sprintf("expected time length: %d", sum(!miss)))
vrt <- readr::read_file(out_local)
vrt <- gsub("/rdsi/PUBLIC/raad/data", "/vsicurl/https://", vrt)
#readr::write_file(vrt, "/tmp/oisst_mdim.vrt")
