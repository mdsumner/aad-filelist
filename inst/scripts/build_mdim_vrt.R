#' Build a multidim VRT sidecar next to a source dataset
#'
#' Given a source dataset, create a sibling `<source>.vrt` multidimensional
#' VRT with `gdalraster::mdim_translate()`. No-ops if the source is missing
#' or the sidecar already exists. Fails gracefully (warning + invisible NULL)
#' instead of erroring, so it is safe to map over a vector of files.
#'
#' @param filename  source dataset path (e.g. a `.nc` file).
#' @param array     optional array name(s) to select (gdalmdimtranslate `-array`).
#' @param overwrite rebuild the `.vrt` even if it already exists.
#' @param quiet     suppress the GDAL progress bar.
#' @param error     if TRUE, re-raise on failure instead of warning (useful for
#'                  targets/crew where you want a hard error, not a NULL).
#' @return the sidecar `.vrt` path (invisibly) on success or if it already
#'   exists; invisible `NULL` on failure or if the source is missing.
#' @examples
#' #files <- raadtools::sstfiles()
#' #dofiles <- gsub("/path1", "/path2", files$fullname)
#' #mirai::daemons(24)
#' #system.time(result <- purrr::map(dofiles, build_mdim_vrt))

#'
build_mdim_vrt <- purrr::in_parallel(
  function(filename,
                           array = NULL,
                           overwrite = FALSE,
                           quiet = TRUE,
                           error = FALSE) {

  ## (1)+(2) source must exist, else no-op
  if (!file.exists(filename)) {
    msg <- paste0("source not found, skipping: ", filename)
    if (error) stop(msg, call. = FALSE)
    warning(msg, call. = FALSE)
    return(invisible(NULL))
  }

  ## (3) sidecar path: append ".vrt" to the *whole* name (foo.nc -> foo.nc.vrt).
  ##     deliberately paste0(), not fs::path_ext_set() / tools::file_path_sans_ext()
  ##     which would *replace* .nc and give foo.vrt.
  vrt <- paste0(filename, ".vrt")

  ## (4) sidecar already present -> no-op
  if (!overwrite && file.exists(vrt)) {
    return(invisible(vrt))
  }

  ## (5) convert, writing atomically: a temp file in the *same directory* (so any
  ##     relative source ref in the VRT resolves identically), promoted with
  ##     file.rename() only on success. A failed/interrupted run never leaves a
  ##     half-written .vrt behind.
  tmp <- tempfile(tmpdir = dirname(filename), fileext = ".vrt")
  #cl_arg <- c("-of", "VRT")
  #if (!is.null(array)) cl_arg <- c(cl_arg, as.vector(rbind("-array", array)))

  ok <- tryCatch({
    gdalraster::mdim_translate(filename, tmp, output_format = "VRT", quiet = quiet)
    TRUE
  }, error = function(e) {
    if (file.exists(tmp)) unlink(tmp)
    msg <- paste0("mdim_translate failed for ", filename, ": ", conditionMessage(e))
    if (error) stop(msg, call. = FALSE)
    warning(msg, call. = FALSE)
    FALSE
  })
  if (!ok) return(invisible(NULL))

  if (!file.rename(tmp, vrt)) {
    unlink(tmp)
    msg <- paste0("could not move temp VRT into place: ", vrt)
    if (error) stop(msg, call. = FALSE)
    warning(msg, call. = FALSE)
    return(invisible(NULL))
  }

  invisible(vrt)
})






