## GHRSST Level 4 MUR Global Foundation Sea Surface Temperature Analysis (converted to COGs with STAC metadata).
## Served via source.coop
## Maintainer: <Michael Sumner>


src <- bowerbird::bb_source(
  name        = "GHRSST Level 4 MUR Global Foundation SST v4.1 (COGs)",
  id          = "ausantarctic-ghrsst-mur-v2",
  description = "	A Group for High Resolution Sea Surface Temperature (GHRSST) Level 4 sea surface temperature, SST anomaly, analysis error, sea ice fraction, and mask. ",
  doc_url     = "https://source.coop/ausantarctic/ghrsst-mur-v2/",
  citation    = "US NASA; JPL PO.DAAC (2002)...",
  license     = "Please cite",
  source_url  = "s3://ausantarctic/ghrsst-mur-v2/",
  method = list(
    "bb_handler_aws_s3",
    region          = "us-west-2",
    base_url        = "s3.amazonaws.com",
    bucket          = "us-west-2.opendata.source.coop",
    prefix          = "ausantarctic/ghrsst-mur-v2/",
    accept_download = "\\.tif$",
    max             = Inf
  ),
  collection_size = 2000,
  data_group      = "Sea surface temperature"
)
