# =============================================================================
# IDAI_2019 / 02_spatial_anomaly_maps.R
# Per-pixel BER anomaly maps for SIF / NIRvR / Phi_F, with:
#   (1) BASELINE DE-MEANING — subtract the pre-event (baseline) corridor-mean
#       offset so maps isolate the CYCLONE signal, not the 2019 year-level bias.
#   (2) Coverage masking (< MIN_N soundings/cell dropped) + honest coverage maps.
#   (3) Proper horizontal colorbar, track + boundary overlays, full labeling.
#
# RUN IN RSTUDIO:
#   setwd to anywhere; just source this file. It sources ../00_shared/*.
#
# INPUTS : corridor_zim.gpkg + idai2019_zim_segment.gpkg (from 01_track script)
# OUTPUTS (all under RESULTS_ROOT/IDAI_2019/spatial_maps/):
#   - IDAI_<SIGNAL>_anomaly_maps.png        (6-window row per signal)
#   - IDAI_<SIGNAL>_anomaly_maps_DEMEANED.png
#   - IDAI_coverage_per_window.png          (soundings/cell)
#   - anom_<signal>_<window>.tif            (raw anomaly GeoTIFFs)
#   - anomd_<signal>_<window>.tif           (de-meaned GeoTIFFs)
#   - spatial_measurements.csv              (numbers behind every panel)
# =============================================================================

## ---- locate & source shared code (robust to where you run from) ----
this_dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) NA)
if (is.na(this_dir)) this_dir <- file.path(Sys.getenv("CYCLONE_SIF_CODEROOT", "code"), "IDAI_2019")
shared <- file.path(dirname(this_dir), "00_shared")
source(file.path(shared, "config.R"))
source(file.path(shared, "functions.R"))

## ---- event constants ----
EVENT      <- "IDAI"; EVENT_YEAR <- 2019
ENTRY      <- as.Date("2019-03-15")
CLIM_YEARS <- setdiff(SIF_YEARS, EVENT_YEAR)         # 2018, 2020, 2021
evdir  <- file.path(RESULTS_ROOT, "IDAI_2019")
mapdir <- file.path(evdir, "spatial_maps")
dir.create(mapdir, showWarnings = FALSE, recursive = TRUE)

## ---- geometry ----
corridor <- st_read(file.path(evdir, "corridor_zim.gpkg"), quiet = TRUE) |> st_union()
vcorr <- vect(corridor); bb <- st_bbox(corridor)
zim   <- st_union(st_make_valid(st_read(file.path(ECO_BYCOUNTRY,
                  "Ecoregions2017_Zimbabwe.shp"), quiet = TRUE)))
seg   <- tryCatch(st_read(file.path(RESULTS_ROOT, "idai2019_zim_segment.gpkg"),
                  quiet = TRUE), error = function(e) NULL)

tmpl <- rast(xmin = floor(bb["xmin"]*10)/10, xmax = ceiling(bb["xmax"]*10)/10,
             ymin = floor(bb["ymin"]*10)/10, ymax = ceiling(bb["ymax"]*10)/10,
             resolution = GRID_DEG, crs = "EPSG:4326")

SIGNALS <- c("sif","nirvr","phif")
SIG_LAB <- c(sif   = "SIF anomaly (mW m-2 sr-1 nm-1)",
             nirvr = "NIRvR anomaly (canopy structure)",
             phif  = "Phi_F anomaly (physiology, SIF/NIRvR)")

## ---- 1. compute raw anomaly grids (event - climatology) per window/signal ----
anom <- list(); cover <- list(); meas <- list()
for (w in names(WINDOWS)) {
  rels <- WINDOWS[[w]][1]:WINDOWS[[w]][2]
  ev <- collect_soundings(rels, EVENT_YEAR, ENTRY, bb, corridor)
  cl <- collect_soundings(rels, CLIM_YEARS, ENTRY, bb, corridor)
  for (s in SIGNALS) {
    ge <- grid_field(ev, s, tmpl, vcorr); gc <- grid_field(cl, s, tmpl, vcorr)
    key <- paste(w, s)
    if (is.null(ge) || is.null(gc)) { anom[[key]] <- NULL; next }
    a <- ge$mean - gc$mean
    anom[[key]] <- a; if (s == "sif") cover[[w]] <- ge$n
    writeRaster(a, file.path(mapdir, sprintf("anom_%s_%s.tif", s, w)), overwrite = TRUE)
  }
}

## ---- 2. BASELINE DE-MEANING: offset = mean baseline anomaly per signal ----
## Subtract 2019's pre-event year-bias so windows show cyclone-driven change.
offset <- sapply(SIGNALS, function(s) {
  a <- anom[[paste("baseline", s)]]
  if (is.null(a)) return(0)
  v <- values(a); mean(v[is.finite(v)])
})
cat("=== Baseline year-offset removed (per signal) ===\n"); print(round(offset, 5))

anomd <- list()
for (w in names(WINDOWS)) for (s in SIGNALS) {
  key <- paste(w, s); a <- anom[[key]]; if (is.null(a)) next
  ad <- a - offset[s]
  anomd[[key]] <- ad
  writeRaster(ad, file.path(mapdir, sprintf("anomd_%s_%s.tif", s, w)), overwrite = TRUE)
  # measurements: from de-meaned grid (the honest cyclone signal)
  vraw <- values(a);  vraw <- vraw[is.finite(vraw)]
  vd   <- values(ad); vd   <- vd[is.finite(vd)]
  if (length(vd)) meas[[length(meas)+1]] <- data.frame(
    window = w, signal = s, n_cells = length(vd),
    raw_mean_anom = round(mean(vraw), 5),
    demeaned_mean_anom = round(mean(vd), 5),
    demeaned_median = round(median(vd), 5),
    pct_suppressed = round(100 * mean(vd < 0), 1),
    min = round(min(vd), 5), max = round(max(vd), 5))
}
measdf <- do.call(rbind, meas)
write.csv(measdf, file.path(mapdir, "spatial_measurements.csv"), row.names = FALSE)
cat("\n=== SPATIAL MEASUREMENTS (de-meaned = cyclone signal) ===\n")
print(measdf, row.names = FALSE)

## ---- 3. map drawing helper ----
draw_signal_maps <- function(store, s, tag) {
  wins <- names(WINDOWS)
  zmax <- max(abs(unlist(lapply(wins, function(w){
    a <- store[[paste(w, s)]]; if (is.null(a)) return(NA)
    v <- values(a); max(abs(v[is.finite(v)]), na.rm = TRUE) }))), na.rm = TRUE)
  brks <- seq(-zmax, zmax, length.out = 21)
  fn <- file.path(mapdir, sprintf("IDAI_%s_anomaly_maps%s.png", toupper(s), tag))
  png(fn, width = 2400, height = 600, res = 150)
  layout(matrix(c(1:6, 7,7,7,7,7,7), nrow = 2, byrow = TRUE), heights = c(4,1))
  par(mar = c(2,2,3,1), oma = c(0,0,3,0))
  for (w in wins) {
    a <- store[[paste(w, s)]]
    plot(st_geometry(zim), border = "grey55", lwd = 1,
         main = sprintf("%s (%+d..%+d d)", w, WINDOWS[[w]][1], WINDOWS[[w]][2]),
         xlim = c(bb["xmin"], bb["xmax"]), ylim = c(bb["ymin"], bb["ymax"]))
    plot(st_geometry(corridor), border = "grey35", lwd = 1, add = TRUE)
    if (!is.null(a)) {
      plot(a, col = DIV_PAL(20), breaks = brks, add = TRUE, legend = FALSE)
      plot(st_geometry(corridor), border = "grey35", add = TRUE)
      plot(st_geometry(zim), border = "grey55", add = TRUE)
    } else text(mean(bb[c("xmin","xmax")]), mean(bb[c("ymin","ymax")]),
                "no data", col = "red", cex = 1.2)
    if (!is.null(seg)) plot(st_geometry(seg), col = "black", lwd = 3, add = TRUE)
  }
  ## colorbar panel
  par(mar = c(3,4,1,4))
  z <- seq(-zmax, zmax, length.out = 200)
  image(z, 1, matrix(z, ncol = 1), col = DIV_PAL(200), axes = FALSE,
        xlab = "", ylab = "")
  axis(1); box()
  mtext(sprintf("%s   (red = suppression, green = enhancement)", SIG_LAB[s]),
        side = 1, line = 2.2, cex = 0.85)
  ttl <- if (tag == "_DEMEANED")
    sprintf("IDAI 2019 — %s | DE-MEANED (cyclone signal, baseline offset removed) | grid %.2f deg, min %d/cell | black = in-country track", SIG_LAB[s], GRID_DEG, MIN_N)
  else
    sprintf("IDAI 2019 — %s | RAW (event - climatology) | grid %.2f deg, min %d/cell | black = in-country track", SIG_LAB[s], GRID_DEG, MIN_N)
  mtext(ttl, outer = TRUE, cex = 0.95, font = 2)
  dev.off()
  cat("wrote:", fn, "\n")
}

for (s in SIGNALS) {
  draw_signal_maps(anom,  s, "")           # raw
  draw_signal_maps(anomd, s, "_DEMEANED")  # cyclone signal
}

## ---- 4. coverage figure ----
png(file.path(mapdir, "IDAI_coverage_per_window.png"), width = 2400, height = 520, res = 150)
par(mfrow = c(1, 6), mar = c(2,2,3,3), oma = c(0,0,3,0))
for (w in names(WINDOWS)) {
  plot(st_geometry(zim), border = "grey55", main = w,
       xlim = c(bb["xmin"], bb["xmax"]), ylim = c(bb["ymin"], bb["ymax"]))
  plot(st_geometry(corridor), border = "grey35", add = TRUE)
  if (!is.null(cover[[w]])) { plot(cover[[w]], add = TRUE, legend = TRUE)
    plot(st_geometry(corridor), border = "grey35", add = TRUE) }
  else text(mean(bb[c("xmin","xmax")]), mean(bb[c("ymin","ymax")]), "no data", col = "red")
}
mtext("IDAI 2019 — event SIF soundings per 0.1 deg cell (coverage honesty)",
      outer = TRUE, cex = 1.0, font = 2)
dev.off()
cat("wrote coverage map.\nDONE. All outputs ->", mapdir, "\n")
