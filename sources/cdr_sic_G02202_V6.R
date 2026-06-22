## sources/cdr_sic_G02202_V6.R
## NOAA/NSIDC DAILY Sea Ice Concentration CDR v6 (South and North)
## 
## Maintainer: Michael Sumner

src <- bowerbird::bb_source(
  name = "NOAA/NSIDC Sea Ice Concentration CDR v6 (South and North)",
  id = "cdr_sic_G02202_V6",
  doc_url = "https://nsidc.org/data/g02202/versions/6",
  license = "No constraints on data access or use",
  source_url = c("https://noaadata.apps.nsidc.org/NOAA/G02202_V6/north/daily/", "https://noaadata.apps.nsidc.org/NOAA/G02202_V6/south/daily/"),
  citation = "Comiso, J. C., and F. Nishio. 2008. Trends in the Sea Ice Cover Using Enhanced and Compatible AMSR-E, SSM/I, and SMMR Data. Journal of Geophysical Research 113, C02S07, doi:10.1029/2007JC0043257. ; Comiso, J. C., D. Cavalieri, C. Parkinson, and P. Gloersen. 1997. Passive Microwave Algorithms for Sea Ice Concentrations: A Comparison of Two Techniques. Remote Sensing of the Environment 60(3):357-84. ; Comiso, J. C. 1984. Characteristics of Winter Sea Ice from Satellite Multispectral Microwave Observations. Journal of Geophysical Research 91(C1):975-94. ; Cavalieri, D. J., P. Gloersen, and W. J. Campbell. 1984. Determination of Sea Ice Parameters with the NIMBUS-7 SMMR. Journal of Geophysical Research 89(D4):5355-5369. ; Cavalieri, D. J., C. l. Parkinson, P. Gloersen, J. C. Comiso, and H. J. Zwally. 1999. Deriving Long-term Time Series of Sea Ice Cover from Satellite Passive-Microwave Multisensor Data Sets. Journal of Geophysical Research 104(7): 15,803-15,814 ; Comiso, J.C., R.A. Gersten, L.V. Stock, J. Turner, G.J. Perez, and K. Cho. 2017. Positive Trend in the Antarctic Sea Ice Cover and Associated Changes in Surface Temperature. J. Climate, 30, 2251–2267, doi:10.1175/JCLI-D-16-0408.1",
  method = list("bb_handler_rget",
                level = 2,
                relative = TRUE,
                accept_download = "\\.nc$"),
  collection_size = 10, 
  data_group = "Sea ice"
)
