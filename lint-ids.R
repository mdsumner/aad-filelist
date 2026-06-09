#!/usr/bin/env Rscript
## lint-ids.R
## Called by CI on PRs to ensure no two sources/*.R files share an `id`.
## Exit code 0 = ok, 1 = duplicate ids found.

library(bowerbird)

source_files <- list.files("sources", pattern = "\\.R$", full.names = TRUE)

ids <- vapply(source_files, function(f) {
  e <- new.env(parent = emptyenv())
  suppressPackageStartupMessages(source(f, local = e))
  if (!exists("src", envir = e)) stop("No `src` object found in ", f)
  e$src$id[[1]]
}, character(1))

dupes <- ids[duplicated(ids)]

if (length(dupes) > 0) {
  message("ERROR: duplicate source id(s) found:")
  for (d in dupes) {
    culprits <- names(ids)[ids == d]
    message("  id '", d, "' in: ", paste(culprits, collapse = ", "))
  }
  quit(status = 1)
}

message("OK: all ", length(ids), " source id(s) are unique")
for (f in names(ids)) message("  ", ids[[f]], "  <-  ", basename(f))
