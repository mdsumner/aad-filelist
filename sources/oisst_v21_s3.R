## sources/oisst_v21_s3.R
## NOAA OISST v2.1 daily, the NOAA open-data bucket (the URLs the
## raad.virtualize OISST store reads). Lists finals and preliminaries alike:
## the store chooses. noaa_oisst_daily (oisst_daily.R) is the NCEI server
## crawl, kept as the RDSI-comparable listing.
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "NOAA OI 1/4 Degree Daily SST AVHRR v2.1 (NOAA open data bucket)",
  id = "noaa_oisst_v21_s3",
  description = "Sea surface temperature at 0.25 degree daily resolution, from 1-Sep-1981 to present, as served by the NOAA Open Data Dissemination bucket.",
  doc_url = "https://registry.opendata.aws/noaa-cdr-oceanic/",
  citation = "Richard W. Reynolds, Viva F. Banzon, and NOAA CDR Program (2008): NOAA Optimum Interpolation 1/4 Degree Daily Sea Surface Temperature (OISST) Analysis, Version 2.1. NOAA National Climatic Data Center. doi:10.7289/V5SQ8XB5",
  source_url = "s3://noaa-cdr-sea-surface-temp-optimum-interpolation-pds/data/v2.1/avhrr/",
  license = "Please cite",
  method = list("bb_handler_aws_s3",
                region = "us-east-1",
                base_url = "s3.amazonaws.com",
                bucket = "noaa-cdr-sea-surface-temp-optimum-interpolation-pds",
                prefix = "data/v2.1/avhrr/",
                accept_download = "\\.nc$"),
  collection_size = 25,
  data_group = "Sea surface temperature")

## corpus engine: S3 ListObjectsV2 gives size, etag and mtime with the listing
engine <- list(
  type = "s3-list",
  endpoint = "https://noaa-cdr-sea-surface-temp-optimum-interpolation-pds.s3.amazonaws.com",
  prefix = "data/v2.1/avhrr/",
  url_base = "https://noaa-cdr-sea-surface-temp-optimum-interpolation-pds.s3.amazonaws.com/",
  accept = "\\.nc$")
