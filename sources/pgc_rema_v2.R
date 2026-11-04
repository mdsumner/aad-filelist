## sources/pgc_rema_v2.R
## REMA v2.0 mosaics (Polar Geospatial Center) on the AWS open data bucket:
## 2 m, 10 m and 32 m tiles (dem, mad, count, countmt, mindate, maxdate,
## browse COGs, per-tile STAC json and metadata txt) plus PGC's tile VRTs
## and collection json. About 84,000 objects, 10.5 TB (listed 2026-11-04).
## The 100 m, 500 m and 1 km mosaics are not in this bucket.
## Listed ahead of any REMA index in raad.virtualize: tiles overlap their
## neighbours by 6 cells and start 3125 cells apart (not a multiple of
## their 512 blocks), so there is no single chunk grid over them.
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "Reference Elevation Model of Antarctica (REMA) v2.0 mosaics (AWS open data)",
  id = "pgc_rema_v2",
  description = "REMA v2.0 mosaic tiles at 2 m, 10 m and 32 m as Cloud Optimized GeoTIFFs (EPSG:3031), with STAC and tile VRTs, as served by the PGC open data bucket.",
  doc_url = "https://www.pgc.umn.edu/data/rema/",
  citation = "Howat, I., et al. (2022). The Reference Elevation Model of Antarctica - Mosaics, Version 2. Harvard Dataverse. doi:10.7910/DVN/EBW8UC",
  source_url = "s3://pgc-opendata-dems/rema/mosaics/v2.0/",
  license = "CC-BY-4.0",
  method = list("bb_handler_aws_s3",
                region = "us-west-2",
                base_url = "s3.amazonaws.com",
                bucket = "pgc-opendata-dems",
                prefix = "rema/mosaics/v2.0/",
                accept_download = ".*"),
  collection_size = 10500,
  data_group = "Topography")

## corpus engine: S3 ListObjectsV2 gives size, etag and mtime with the listing
engine <- list(
  type = "s3-list",
  endpoint = "https://pgc-opendata-dems.s3.us-west-2.amazonaws.com",
  prefix = "rema/mosaics/v2.0/",
  url_base = "https://pgc-opendata-dems.s3.us-west-2.amazonaws.com/")
