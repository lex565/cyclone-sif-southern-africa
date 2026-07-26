# =============================================================================
# 00_shared/run_full_event.R
# FULL pipeline for a NEW event/country from scratch: corridor -> temporal
# event_vs_climatology -> spatial triplet figures -> original metrics + md.
# Reuses the tested spatial & metrics runners. Foreground, staged progress.
#
# REQUIRED before sourcing:
#   EV_LABEL  e.g. "MALAWI_IDAI_2019"   (used for folder + filenames)
#   EV_NAME   e.g. "Idai"               (storm name for figure titles)
#   EV_SID    IBTrACS SID e.g. "2019063S18038"
#   EV_ENTRY  as.Date("2019-03-07")     (first in-country fix / anchor)
#   EV_YEAR   2019                       (event calendar year; excluded from clim)
#   COUNTRY   "Malawi"                   (selects shapefile, cities, GPP folder)
#   EV_DIR    file.path(RESULTS_ROOT, EV_LABEL)
# =============================================================================
sd_ <- Sys.getenv("CYCLONE_SIF_CODE", Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"))
source(file.path(sd_, "config.R"))
source(file.path(sd_, "functions.R"))

stopifnot(exists("EV_LABEL"), exists("EV_SID"), exists("EV_ENTRY"),
          exists("EV_YEAR"), exists("COUNTRY"), exists("EV_DIR"))
dir.create(EV_DIR, showWarnings = FALSE, recursive = TRUE)
clim_years <- setdiff(SIF_YEARS, EV_YEAR)

cat(sprintf("\n############  FULL EVENT: %s  (%s, %s)  ############\n",
            EV_LABEL, EV_NAME, COUNTRY))
cat(sprintf("SID %s | entry %s | event yr %d | clim %s\n",
            EV_SID, format(EV_ENTRY), EV_YEAR, paste(clim_years, collapse=",")))

## ---- A. corridor: track LINE buffered (equal-area) ∩ country ----
cat("[A] building corridor (track ∩ country, 200 km)...\n"); flush.console()
bc <- build_corridor(EV_SID, country_shp(COUNTRY), buffer_km = BUFFER_KM)
st_write(st_sf(geometry = st_union(bc$corridor)), file.path(EV_DIR, "corridor.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)
seg_ok <- !is.null(bc$segment) && length(bc$segment) > 0 &&
          as.numeric(sum(st_length(st_sf(geometry = bc$segment)))) > 0
EV_SEG <- file.path(EV_DIR, "segment.gpkg")
if (seg_ok) st_write(st_sf(geometry = bc$segment), EV_SEG, delete_dsn = TRUE, quiet = TRUE) else EV_SEG <- NULL
bb <- st_bbox(st_union(bc$corridor))
cat(sprintf("  corridor bbox lon %.2f..%.2f lat %.2f..%.2f\n",
            bb["xmin"], bb["xmax"], bb["ymin"], bb["ymax"]))

## ---- B. temporal series -> event_vs_climatology.csv (+ window summary) ----
cat("[B] daily series + stabilized climatology (extracting SIF)...\n"); flush.console()
corr <- st_union(bc$corridor)
m <- build_event_series(EV_ENTRY, EV_YEAR, clim_years, bb, corr)
write.csv(m, file.path(EV_DIR, "event_vs_climatology.csv"), row.names = FALSE)
wsum <- do.call(rbind, lapply(names(WINDOWS), function(w) {
  s <- m[which(m$window == w), ]
  data.frame(window = w, days = sum(is.finite(s$sif)), clim_n = round(mean(s$clim_n)),
             sif_anom = mean(s$sif_anom, na.rm = TRUE),
             nirvr_anom = mean(s$nirvr_anom, na.rm = TRUE),
             phif_anom = mean(s$phif_anom, na.rm = TRUE)) }))
write.csv(wsum, file.path(EV_DIR, "window_anomalies.csv"), row.names = FALSE)
cat("  window valid-day counts:\n"); print(wsum[, c("window","days","clim_n")], row.names = FALSE)

## ---- C. spatial anomalies + figures (reuse spatial runner) ----
cat("[C] spatial anomalies + figures...\n"); flush.console()
source(file.path(sd_, "run_spatial_for_event.R"))

## ---- D. original metrics + md (reuse metrics runner) ----
cat("[D] original metrics (Eq 1/2/6/7/8 + §3.7)...\n"); flush.console()
source(file.path(sd_, "run_metrics_for_event.R"))

cat(sprintf("\n############  DONE %s -> %s  ############\n", EV_LABEL, EV_DIR))
