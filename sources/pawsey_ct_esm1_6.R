## sources/pawsey_ct_esm1_6.R
## ACCESS-ESM1.6 historical run, native payu output (not CMORised), on the
## Pawsey Acacia pilot bucket ct-esm1-6 (Charles Turner, ACCESS-NRI; public,
## anonymous). output000/ .. output171/ = model years 1850 .. 2021, each with
## ocean/ (one variable per file), atmosphere/netCDF/ and ice/; restart*/
## every 10 years. Listed whole: about 53,000 objects, 2.6 TiB.
## The bucket is a pilot and is expected to move: stores keep the verbatim
## URL and carry the new location as a remap rule only.
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "ACCESS-ESM1.6 historical native output (Pawsey ct-esm1-6 pilot)",
  id = "pawsey_ct_esm1_6",
  description = "ACCESS-ESM1.6 historical simulation, 1850-2021, native model output (MOM ocean, UM atmosphere converted to netCDF, CICE ice) and restarts, one folder per model year, as staged by ACCESS-NRI on Pawsey Acacia.",
  doc_url = "https://projects.pawsey.org.au/ct-esm1-6/",
  citation = "ACCESS-NRI ACCESS-ESM1.6 historical simulation (pilot copy, Pawsey ct-esm1-6). Citation to be confirmed with ACCESS-NRI.",
  source_url = "https://projects.pawsey.org.au/ct-esm1-6/",
  license = "To be confirmed with ACCESS-NRI",
  method = list("bb_handler_aws_s3",
                base_url = "projects.pawsey.org.au",
                bucket = "ct-esm1-6",
                prefix = "",
                accept_download = ".*"),
  collection_size = 2900,
  data_group = "Climate model output")

## path-style S3 on Pawsey Acacia (Ceph), as pawsey_esacci_oc_cog
engine <- list(
  type = "s3-list",
  endpoint = "https://projects.pawsey.org.au",
  bucket = "ct-esm1-6",
  prefix = "",
  url_base = "https://projects.pawsey.org.au/ct-esm1-6/")
