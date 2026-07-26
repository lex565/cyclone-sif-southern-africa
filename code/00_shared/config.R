# =============================================================================
# 00_shared/config.R  —  Paths, constants, QC thresholds, BER windows.
# Sourced by every analysis script. Edit paths here ONCE if data moves.
# Project: My Manuscript (cyclone-vegetation SIF, Southern Africa)
# =============================================================================

## ---- root paths ----
DATA_ROOT   <- Sys.getenv("CYCLONE_SIF_DATA", Sys.getenv("CYCLONE_SIF_DATA", "data_raw"))
RESULTS_ROOT<- Sys.getenv("CYCLONE_SIF_OUT", Sys.getenv("CYCLONE_SIF_OUT", "derived_data"))
SIF_ROOT    <- file.path(DATA_ROOT, "TROPOSIF")
CHIRPS_ROOT <- file.path(DATA_ROOT, "CHIRPS")
IBTRACS_PTS <- file.path(DATA_ROOT, "IBTracs/Extracted/IBTrACS.SI.list.v04r01.points.shp")
ECO_BYCOUNTRY <- file.path(DATA_ROOT, "Ecological Regions/By_Country")

## ---- TROPOSIF QC thresholds (methods 3.4) ----
CF_MAX  <- 0.02     # cloud fraction
SZA_MAX <- 85       # solar zenith angle (deg)
TOA_LO  <- 20       # NIR radiance lower bound
TOA_HI  <- 200      # NIR radiance upper bound
NDVI_MIN<- 0.10     # drop non-veg / water
RED_I   <- 1        # WVL_RFL index for 665 nm (red)
NIR_I   <- 7        # WVL_RFL index for 781 nm (NIR)

## ---- SIF data coverage ----
SIF_YEARS <- 2018:2021   # NO 2022 on disk

## ---- analysis design ----
BUFFER_KM <- 200
GRID_DEG  <- 0.1         # spatial grid resolution (deg)
MIN_N     <- 2           # min soundings per cell to keep (coverage mask)

## ---- 7-day BER windows (days relative to entry/anchor) ----
WINDOWS <- list(
  baseline = c(-14, -8),  # pre-event reference
  pre7     = c(-7, -1),
  acute    = c(0, 6),     # storm window (expect cloud gaps)
  early    = c(7, 13),
  recov2   = c(14, 20),
  recov3   = c(21, 27)
)

## ---- diverging palette: red=suppression -> white -> green=enhancement ----
DIV_PAL <- colorRampPalette(c("#8c2d04","#d95f0e","#fee08b","#ffffff",
                              "#a6d96a","#1a9850"))

## ---- per-country reference cities (lon, lat; label = drawn name vs dot-only) ----
COUNTRY_CITIES <- list(
  Zimbabwe = data.frame(
    name = c("Harare","Mutare","Chimanimani","Chipinge","Nyanga","Masvingo","Bulawayo"),
    lon  = c(31.0522,32.6709,32.8700,32.6236,32.7500,30.8277,28.5833),
    lat  = c(-17.8292,-18.9707,-19.8004,-20.1883,-18.2167,-20.0637,-20.1500),
    label= c(TRUE,TRUE,TRUE,FALSE,FALSE,TRUE,TRUE), stringsAsFactors = FALSE),
  Botswana = data.frame(
    name = c("Gaborone","Francistown","Maun","Kasane","Selebi-Phikwe","Ghanzi"),
    lon  = c(25.9231,27.5167,23.4167,25.1500,27.8333,21.6500),
    lat  = c(-24.6282,-21.1667,-19.9833,-17.8000,-22.0000,-21.7000),
    label= c(TRUE,TRUE,TRUE,TRUE,FALSE,TRUE), stringsAsFactors = FALSE),
  Malawi = data.frame(
    name = c("Lilongwe","Blantyre","Mzuzu","Zomba","Karonga","Kasungu"),
    lon  = c(33.7833,35.0000,34.0167,35.3188,33.9333,33.4833),
    lat  = c(-13.9833,-15.7861,-11.4667,-15.3833,-9.9333,-13.0333),
    label= c(TRUE,TRUE,TRUE,FALSE,TRUE,FALSE), stringsAsFactors = FALSE),
  Mozambique = data.frame(
    name = c("Maputo","Beira","Nampula","Quelimane","Pemba","Tete","Chimoio"),
    lon  = c(32.5732,34.8389,39.2666,36.8883,40.5173,33.5867,33.4833),
    lat  = c(-25.9692,-19.8436,-15.1165,-17.8786,-12.9740,-16.1564,-19.1164),
    label= c(TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,FALSE), stringsAsFactors = FALSE),
  Madagascar = data.frame(
    name = c("Antananarivo","Toamasina","Mahajanga","Antsiranana","Toliara","Fianarantsoa"),
    lon  = c(47.5079,49.4023,46.3127,49.2917,43.6856,47.0833),
    lat  = c(-18.8792,-18.1492,-15.7167,-12.2787,-23.3568,-21.4536),
    label= c(TRUE,TRUE,TRUE,TRUE,TRUE,FALSE), stringsAsFactors = FALSE),
  South_Africa = data.frame(
    name = c("Pretoria","Johannesburg","Polokwane","Musina","Mbombela","Durban"),
    lon  = c(28.1879,28.0473,29.4689,30.0411,30.9700,31.0218),
    lat  = c(-25.7461,-26.2041,-23.9045,-22.3517,-25.4753,-29.8587),
    label= c(TRUE,TRUE,TRUE,TRUE,TRUE,FALSE), stringsAsFactors = FALSE)
)

## ---- country Ecoregions polygon path ----
country_shp <- function(country)
  file.path(ECO_BYCOUNTRY, sprintf("Ecoregions2017_%s.shp", country))

## ---- locate an event's corridor gpkg (new generic name, fallback to ZW name) ----
corridor_path <- function(evdir) {
  g <- file.path(evdir, "corridor.gpkg")
  if (file.exists(g)) g else file.path(evdir, "corridor_zim.gpkg")
}

message("[config] loaded. SIF years ", paste(range(SIF_YEARS), collapse="-"),
        " | grid ", GRID_DEG, " deg | QC cloud<", CF_MAX)
