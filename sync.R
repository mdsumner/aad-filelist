#!/usr/bin/env Rscript
## sync.R
## Usage: Rscript sync.R sources/hclim_dmi.R [--dry-run]
##
## Sources one sources/*.R file (which must define a single `src` object),
## runs bb_sync, and writes a Parquet file named <id>.parquet.
##
## Environment variables:
##   MIRROR_ROOT   local file root for bowerbird (default: tempdir())
##   DRY_RUN       "TRUE" to enumerate without downloading (default: "FALSE")

library(bowerbird)
library(arrow)
library(dplyr)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) stop("Usage: Rscript sync.R sources/<name>.R")

source_file <- args[1]
dry_run <- TRUE

if (!file.exists(source_file))
  stop("Source file not found: ", source_file)

e <- new.env(parent = baseenv())
source(source_file, local = e)
src <- e$src

stopifnot(inherits(src, "data.frame"), "id" %in% names(src))
id <- src$id[[1]]
message("Source id: ", id)
message("Dry run:   ", dry_run)

mirror_root <- Sys.getenv("MIRROR_ROOT", unset = tempdir())
message("Mirror root: ", mirror_root)

cf <- bb_config(local_file_root = mirror_root) |>
  bb_add(src)

status <- bb_sync(cf, verbose = TRUE, dry_run = dry_run, create_root = TRUE)

## Build per-source Parquet manifest ----------------------------------------
## status$files is a list (one element per source) of data frames with
## columns: file, url, size, was_downloaded, ...
## We normalise to a tidy tibble and write <id>.parquet.

file_df <- status$files[[1]]

## bb_sync returns different column sets depending on version; be defensive
manifest <- tibble(
  id             = id,
  path           = if ("file"             %in% names(file_df)) file_df$file             else NA_character_,
  url            = if ("url"              %in% names(file_df)) file_df$url              else NA_character_,
  size           = if ("size"             %in% names(file_df)) file_df$size             else NA_real_,
  was_downloaded = if ("was_downloaded"   %in% names(file_df)) file_df$was_downloaded   else NA,
  ok             = if ("ok"              %in% names(file_df)) file_df$ok               else NA,
  sync_time      = Sys.time(),
  dry_run        = dry_run
)

out_file <- paste0(id, ".parquet")
write_parquet(manifest, out_file)
message("Wrote ", nrow(manifest), " rows to ", out_file)
