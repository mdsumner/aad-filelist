## sources/cdr_sic_G02202_V6.R
## NOAA/NSIDC DAILY and MONTHLY Sea Ice Concentration CDR v6 (South and North)
##
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "NOAA-NSIDC Climate Data Record of Passive Microwave Sea Ice Concentration Version 6",
  id = "cdr_sic_G02202_V6",
  description = "This data set provides a passive microwave sea ice concentration climate data record (CDR) based on gridded brightness temperatures (TBs) from the Nimbus-7 Scanning Multichannel Microwave Radiometer (SMMR) and the Defense Meteorological Satellite Program (DMSP) series of passive microwave radiometers: the Special Sensor Microwave Imager (SSM/I) and the Special Sensor Microwave Imager/Sounder (SSMIS). The sea ice concentration CDR is an estimate of sea ice concentration that is produced by combining concentration estimates from two algorithms developed at the NASA Goddard Space Flight Center (GSFC): the NASA Team (NT) algorithm and the Bootstrap (BT) algorithm. The individual algorithms are used to process and combine brightness temperature data at NSIDC. This product is designed to provide a consistent time series of sea ice concentrations (the fraction, or percentage, of ocean area covered by sea ice) from November 1978 to the present, which spans the coverage of several passive microwave instruments. The data are gridded on the NSIDC polar stereographic grid with 25 km x 25 km grid cells and are available in NetCDF file format. Each file contains a variable with the CDR concentration values as well as variables that hold the raw NT and BT processed concentrations for reference. Variables containing standard deviation, quality flags, and projection information are also included. Files that are from 2013 to the present also contain a prototype CDR sea ice concentration based on gridded TBs from the Advanced Microwave Scanning Radiometer 2 (AMSR2) onboard the GCOM-W1 satellite." ,
  doc_url = "https://nsidc.org/data/g02202/versions/6",
  license = "No constraints on data access or use",
  source_url = c("https://noaadata.apps.nsidc.org/NOAA/G02202_V6/north/daily/", "https://noaadata.apps.nsidc.org/NOAA/G02202_V6/south/daily/", "https://noaadata.apps.nsidc.org/NOAA/G02202_V6/north/monthly/", "https://noaadata.apps.nsidc.org/NOAA/G02202_V6/south/monthly/"),
  citation = "Comiso, J. C., and F. Nishio. 2008. Trends in the Sea Ice Cover Using Enhanced and Compatible AMSR-E, SSM/I, and SMMR Data. Journal of Geophysical Research 113, C02S07, doi:10.1029/2007JC0043257. ; Comiso, J. C., D. Cavalieri, C. Parkinson, and P. Gloersen. 1997. Passive Microwave Algorithms for Sea Ice Concentrations: A Comparison of Two Techniques. Remote Sensing of the Environment 60(3):357-84. ; Comiso, J. C. 1984. Characteristics of Winter Sea Ice from Satellite Multispectral Microwave Observations. Journal of Geophysical Research 91(C1):975-94. ; Cavalieri, D. J., P. Gloersen, and W. J. Campbell. 1984. Determination of Sea Ice Parameters with the NIMBUS-7 SMMR. Journal of Geophysical Research 89(D4):5355-5369. ; Cavalieri, D. J., C. l. Parkinson, P. Gloersen, J. C. Comiso, and H. J. Zwally. 1999. Deriving Long-term Time Series of Sea Ice Cover from Satellite Passive-Microwave Multisensor Data Sets. Journal of Geophysical Research 104(7): 15,803-15,814 ; Comiso, J.C., R.A. Gersten, L.V. Stock, J. Turner, G.J. Perez, and K. Cho. 2017. Positive Trend in the Antarctic Sea Ice Cover and Associated Changes in Surface Temperature. J. Climate, 30, 2251–2267, doi:10.1175/JCLI-D-16-0408.1",
  method = list("bb_handler_rget",
                level = 2,
                relative = TRUE,
                accept_download = "\\.nc$"),
  collection_size = 10,
  data_group = "Sea ice"
)

