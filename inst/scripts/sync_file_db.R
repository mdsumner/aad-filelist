#!/usr/bin/env Rscript
## sync_file_db.R
## Reads the raad file database (.tab), writes it as Parquet, and uploads it
## to the 'latest' release of mdsumner/aad-filelist via piggyback.
## Intended to be run from cron. Auth: GITHUB_PAT in the cron user's ~/.Renviron.
 
suppressPackageStartupMessages(library(piggyback))
 
src  <- Sys.getenv("RAAD_FILE_DB") 

if (nchar(src) < 2) {
  message("no file db found!")
  quit(status = 1L)
}

repo <- "mdsumner/aad-filelist"
tag  <- "file_db"                                   # the established data bucket
out  <- file.path(tempdir(), "raad_file_db.parquet")
 
tryCatch({
  d <- readr::read_table(src, show_col_types = FALSE)
 
  nanoparquet::write_parquet(d, out)               # or: arrow::write_parquet(d, out)
 
  ## upload to the EXISTING release; never the create-on-the-fly path
  pb_upload(out, repo = repo, tag = tag, overwrite = TRUE)
 
  message(sprintf("[%s] OK: uploaded %d rows -> %s/%s",
                  format(Sys.time(), tz = "UTC", usetz = TRUE),
                  nrow(d), repo, tag))
}, error = function(e) {
  message(sprintf("[%s] FAILED: %s",
                  format(Sys.time(), tz = "UTC", usetz = TRUE),
                  conditionMessage(e)))
  quit(status = 1L)                                # so cron/monitoring sees a failure
})
 
