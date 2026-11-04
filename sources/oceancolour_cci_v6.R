## sources/oceancolour_cci_v6.R
## ESA Ocean Colour CCI v6.0 netCDF on the oceancolour.org THREDDS server,
## monthly and 5-day chlor_a (the files py/esacci_cog.py converts for the
## ausantarctic oceancolour group). THREDDS, not rget/S3: urls only, no HEAD
## (rules.tsv) until the THREDDS step of the plan. Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "ESA Ocean Colour CCI v6.0 chlorophyll-a, monthly and 5-day (THREDDS)",
  id = "oceancolour_cci_v6_chlor_a",
  description = "OC-CCI v6.0 merged-sensor geographic 4 km chlorophyll-a netCDF, monthly and 5-day composites.",
  doc_url = "https://climate.esa.int/en/projects/ocean-colour/",
  citation = "Sathyendranath, S., et al. (2019) An ocean-colour time series for use in climate studies: the experience of the Ocean-Colour Climate Change Initiative (OC-CCI). Sensors 19, 4285. doi:10.3390/s19194285",
  source_url = c("https://www.oceancolour.org/thredds/catalog/cci/v6.0-release/geographic/monthly/chlor_a/catalog.html",
                 "https://www.oceancolour.org/thredds/catalog/cci/v6.0-release/geographic/5day/chlor_a/catalog.html"),
  license = "CC-BY-4.0",
  method = list("bb_handler_thredds", level = 2, accept_download = "\\.nc$"),
  collection_size = 300,
  data_group = "Ocean colour")
