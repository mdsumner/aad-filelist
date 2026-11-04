## sources/esacci_oc_cog.R
## ESA Ocean Colour CCI v6.0 COGs (monthly and 5-day chlor_a, log10 bias and
## RMSD), converted by raad.virtualize py/esacci_cog.py and held on Pawsey
## Acacia (public, anonymous). Our own output: listing it catches a COG
## rebuilt under the same key, the stale-offset case for the indexes.
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "ESA Ocean Colour CCI v6.0 COGs (Pawsey aad-derived)",
  id = "pawsey_esacci_oc_cog",
  description = "Cloud-optimised GeoTIFFs of ESA OC-CCI v6.0 merged-sensor chlorophyll-a and its log10 bias and RMSD, monthly and 5-day, 4 km global, converted from the CCI netCDF.",
  doc_url = "https://climate.esa.int/en/projects/ocean-colour/",
  citation = "Sathyendranath, S., et al. (2019) An ocean-colour time series for use in climate studies: the experience of the Ocean-Colour Climate Change Initiative (OC-CCI). Sensors 19, 4285. doi:10.3390/s19194285",
  source_url = "https://projects.pawsey.org.au/aad-derived/esacci-oc/",
  license = "CC-BY-4.0",
  method = list("bb_handler_aws_s3",
                base_url = "projects.pawsey.org.au",
                bucket = "aad-derived",
                prefix = "esacci-oc/",
                accept_download = "\\.tif$"),
  collection_size = 300,
  data_group = "Ocean colour")

## path-style S3 on Pawsey Acacia (Ceph); untested from GitHub Actions
engine <- list(
  type = "s3-list",
  endpoint = "https://projects.pawsey.org.au",
  bucket = "aad-derived",
  prefix = "esacci-oc/",
  url_base = "https://projects.pawsey.org.au/aad-derived/",
  accept = "\\.tif$")
