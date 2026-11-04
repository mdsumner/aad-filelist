## sources/ausantarctic_gebco.R
## Our published product on source.coop (ausantarctic/gebco/): every object,
## listed by S3 so size, etag and mtime come free. Catches a file rebuilt
## under the same key (stale byte offsets for anything indexing it).
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "GEBCO COGs (source.coop ausantarctic/gebco)",
  id = "ausantarctic-gebco",
  description = "GEBCO 2024, 2025 and 2026 global grids as COGs with STAC items, as published.",
  doc_url = "https://source.coop/ausantarctic/gebco/",
  citation = "See the product README at https://data.source.coop/ausantarctic/gebco/README.md",
  source_url = "s3://us-west-2.opendata.source.coop/ausantarctic/gebco/",
  license = "See the product README",
  method = list("bb_handler_aws_s3",
                region = "us-west-2",
                base_url = "s3.amazonaws.com",
                bucket = "us-west-2.opendata.source.coop",
                prefix = "ausantarctic/gebco/",
                accept_download = ".*"),
  collection_size = 5,
  data_group = "Published products (ausantarctic)")

engine <- list(
  type = "s3-list",
  endpoint = "https://s3.us-west-2.amazonaws.com",
  bucket = "us-west-2.opendata.source.coop",
  prefix = "ausantarctic/gebco/",
  url_base = "https://data.source.coop/")
