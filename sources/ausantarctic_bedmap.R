## sources/ausantarctic_bedmap.R
## Our published product on source.coop (ausantarctic/bedmap/): every object,
## listed by S3 so size, etag and mtime come free. Catches a file rebuilt
## under the same key (stale byte offsets for anything indexing it).
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "Bedmap COGs and virtual store (source.coop ausantarctic/bedmap)",
  id = "ausantarctic-bedmap",
  description = "Bedmap3 COGs (one per layer) and the Bedmap3 virtual store, as published.",
  doc_url = "https://source.coop/ausantarctic/bedmap/",
  citation = "See the product README at https://data.source.coop/ausantarctic/bedmap/README.md",
  source_url = "s3://us-west-2.opendata.source.coop/ausantarctic/bedmap/",
  license = "See the product README",
  method = list("bb_handler_aws_s3",
                region = "us-west-2",
                base_url = "s3.amazonaws.com",
                bucket = "us-west-2.opendata.source.coop",
                prefix = "ausantarctic/bedmap/",
                accept_download = ".*"),
  collection_size = 5,
  data_group = "Published products (ausantarctic)")

engine <- list(
  type = "s3-list",
  endpoint = "https://s3.us-west-2.amazonaws.com",
  bucket = "us-west-2.opendata.source.coop",
  prefix = "ausantarctic/bedmap/",
  url_base = "https://data.source.coop/")
