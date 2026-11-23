## sources/imos_meop_ctd.R
## IMOS Animal Tracking Facility (AATAMS) satellite-relay tag CTD profiles,
## MEOP quality controlled: one classic netCDF file per tag on the IMOS
## public bucket (ap-southeast-2), in two releases under one prefix
## (MEOP-CTD_2017-10-01, other *_prof.nc; IMOS-CTD_2024, *_hr1_prof.nc).
## About 560 files. The files are rewritten in place (299 last written in
## 2017, 135 in 2024, 130 in 2025), so the ETag is the stale signal for the
## raad.virtualize imos-tracking stores, which reference them by byte range.
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "IMOS AATAMS MEOP-QC CTD profiles (IMOS public bucket)",
  id = "imos_aatams_meop_ctd",
  description = "CTD profiles from satellite-relay tags (SMRU SRDL) on southern elephant seals, Weddell seals, fur seals and turtles, MEOP quality controlled, one netCDF file (Argo profile format) per tag.",
  doc_url = "https://imos.org.au/facility/animal-tracking",
  citation = "IMOS Animal Tracking Facility; MEOP consortium (https://www.meop.net). Cite per the files' citation and license attributes.",
  source_url = "s3://imos-data/IMOS/AATAMS/satellite_tagging/MEOP_QC_CTD/",
  license = "CC-BY-4.0 (IMOS-CTD_2024 files); MEOP data policy (MEOP-CTD_2017-10-01 files)",
  method = list("bb_handler_aws_s3",
                region = "ap-southeast-2",
                base_url = "s3.amazonaws.com",
                bucket = "imos-data",
                prefix = "IMOS/AATAMS/satellite_tagging/MEOP_QC_CTD/",
                accept_download = "\\.nc$"),
  collection_size = 1,
  data_group = "Animal tracking")

## corpus engine: S3 ListObjectsV2 gives size, etag and mtime with the listing
engine <- list(
  type = "s3-list",
  endpoint = "https://imos-data.s3.ap-southeast-2.amazonaws.com",
  prefix = "IMOS/AATAMS/satellite_tagging/MEOP_QC_CTD/",
  url_base = "https://imos-data.s3.ap-southeast-2.amazonaws.com/",
  accept = "\\.nc$")
