## sources/ausantarctic_scratch.R
## Our published product on source.coop (ausantarctic/ausantarctic-scratch/): every object,
## listed by S3 so size, etag and mtime come free. Catches a file rebuilt
## under the same key (stale byte offsets for anything indexing it).
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "Draft virtual stores (source.coop ausantarctic/ausantarctic-scratch)",
  id = "ausantarctic-scratch",
  description = "Every object of the draft virtual stores (kerchunk, Icechunk, mdim VRT, flat refs, STAC, grist catalogs) for all scratch groups.",
  doc_url = "https://source.coop/ausantarctic/ausantarctic-scratch/",
  citation = "See the product README at https://data.source.coop/ausantarctic/ausantarctic-scratch/README.md",
  source_url = "s3://us-west-2.opendata.source.coop/ausantarctic/ausantarctic-scratch/",
  license = "See the product README",
  method = list("bb_handler_aws_s3",
                region = "us-west-2",
                base_url = "s3.amazonaws.com",
                bucket = "us-west-2.opendata.source.coop",
                prefix = "ausantarctic/ausantarctic-scratch/",
                accept_download = ".*"),
  collection_size = 5,
  data_group = "Published products (ausantarctic)")

engine <- list(
  type = "s3-list",
  endpoint = "https://s3.us-west-2.amazonaws.com",
  bucket = "us-west-2.opendata.source.coop",
  prefix = "ausantarctic/ausantarctic-scratch/",
  url_base = "https://data.source.coop/")
