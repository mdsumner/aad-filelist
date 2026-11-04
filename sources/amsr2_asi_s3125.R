## sources/amsr2_asi_s3125.R
## University of Bremen ASI AMSR2 sea ice concentration, 3.125 km, south,
## daily netCDF (the URLs the raad.virtualize AMSR2 store reads). blueant's
## AMSR2_ASI_s3125 points at seaice.uni-bremen.de/data/amsr2/...; this lists
## data.seaice.uni-bremen.de, the host the store reads. The first runs settle
## whether the two hosts serve identical files (compare sizes).
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "ASI AMSR2 sea ice concentration 3.125 km, Antarctic (University of Bremen)",
  id = "amsr2_asi_s3125",
  description = "Daily sea ice concentration from AMSR2 with the ARTIST Sea Ice (ASI) algorithm, 3.125 km polar stereographic grid, southern hemisphere, netCDF.",
  doc_url = "https://seaice.uni-bremen.de/sea-ice-concentration/amsre-amsr2/",
  citation = "Spreen, G., L. Kaleschke, and G. Heygster (2008), Sea ice remote sensing using AMSR-E 89 GHz channels, J. Geophys. Res., 113, C02S03, doi:10.1029/2005JC003384",
  source_url = "https://data.seaice.uni-bremen.de/amsr2/asi_daygrid_swath/s3125/netcdf/",
  license = "Please cite",
  method = list("bb_handler_rget",
                level = 1,
                accept_follow = "/[0-9]{4}/$",
                accept_download = "asi-AMSR2-s3125-[0-9]{8}-v[0-9.]+\\.nc$"),
  collection_size = 110,
  data_group = "Sea ice")
