## sources/ausantarctic_ibcso.R
## Our published product on source.coop (ausantarctic/ibcso/): every object,
## listed by S3 so size, etag and mtime come free. Catches a file rebuilt
## under the same key (stale byte offsets for anything indexing it).
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "IBCSO COGs, charts and virtual stores (source.coop ausantarctic/ibcso)",
  id = "ausantarctic-ibcso",
  description = "IBCSO v1, v2, 2024 and 2025 annual releases as COGs, charts and virtual stores, as published.",
  doc_url = "https://source.coop/ausantarctic/ibcso/",
  citation = "See the product README at https://data.source.coop/ausantarctic/ibcso/README.md",
  source_url = "s3://us-west-2.opendata.source.coop/ausantarctic/ibcso/",
  license = "See the product README",
  method = list("bb_handler_aws_s3",
                region = "us-west-2",
                base_url = "s3.amazonaws.com",
                bucket = "us-west-2.opendata.source.coop",
                prefix = "ausantarctic/ibcso/",
                accept_download = ".*"),
  collection_size = 5,
  data_group = "Published products (ausantarctic)")

engine <- list(
  type = "s3-list",
  endpoint = "https://s3.us-west-2.amazonaws.com",
  bucket = "us-west-2.opendata.source.coop",
  prefix = "ausantarctic/ibcso/",
  url_base = "https://data.source.coop/")
