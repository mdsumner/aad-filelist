## sources/oisst_daily.R
## OISST optimally interpolated sea surface temperature — global, daily
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "NOAA OI 1/4 Degree Daily SST AVHRR",
  id = "noaa_oisst_daily",
  description = "Sea surface temperature at 0.25 degree daily resolution, from 1-Sep-1981 to present",
  doc_url = "https://www.ncei.noaa.gov/metadata/geoportal/rest/metadata/item/gov.noaa.ncdc:C00844/html",
  citation = "Richard W. Reynolds, Viva F. Banzon, and NOAA CDR Program (2008): NOAA Optimum Interpolation 1/4 Degree Daily Sea Surface Temperature (OISST) Analysis, Version 2.1. [indicate subset used]. NOAA National Climatic Data Center. doi:10.7289/V5SQ8XB5 [access date]",
  source_url = "https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr",
  license = "Please cite",
  method = list("bb_handler_rget", level = 2,
                accept_follow = "[[:digit:]]{6}",
                accept_download = function(urls) {
                  ## don't download preliminary files if the final file is available
                  ## each file's date
                  file_date <- stringr::str_match(sub("_preliminary\\.nc$", ".nc", urls), "([[:digit:]]{8})\\.nc")[, 2]
                  ## dates of final files
                  finals <- stats::na.omit(stringr::str_match(urls, "([[:digit:]]{8})\\.nc")[, 2])
                  out <- grepl("\\.nc$", urls) & (!grepl("_preliminary\\.nc$", urls) | (nzchar(file_date) & !file_date %in% finals))
                  out[!grepl("\\.nc$", urls)] <- NA ## non-download links
                  out
                }),
  collection_size = 25,
  data_group = "Sea surface temperature")
