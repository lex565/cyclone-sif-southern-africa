# =============================================================================
# 00_shared/run_spatial_for_event.R
# Parameterized spatial-map runner for ANY event. Define the 5 vars below then
# source this file (or set them via commandArgs). Produces de-meaned + raw maps
# for SIF/NIRvR/Phi_F, a coverage figure, GeoTIFFs, and a measurements CSV with
# full Zimbabwe cartography.
#
# REQUIRED before sourcing:
#   EV_LABEL    e.g. "IDAI_2019"
#   EV_ENTRY    as.Date("2019-03-15")
#   EV_YEAR     2019
#   EV_DIR      file.path(RESULTS_ROOT, EV_LABEL)   # holds corridor_zim.gpkg
#   EV_SEG      path to in-country track segment gpkg (or NULL)
# =============================================================================
this_dir <- Sys.getenv("CYCLONE_SIF_CODE", Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"))
source(file.path(this_dir, "config.R"))
source(file.path(this_dir, "functions.R"))
source(file.path(this_dir, "spatial_engine.R"))

if (!exists("EV_LABEL")) stop("Set EV_LABEL, EV_ENTRY, EV_YEAR, EV_DIR, EV_SEG before sourcing.")
if (!exists("COUNTRY")) COUNTRY <- "Zimbabwe"
CITIES <- COUNTRY_CITIES[[COUNTRY]]      # country-aware city labels

clim_years <- setdiff(SIF_YEARS, EV_YEAR)
mapdir <- file.path(EV_DIR, "spatial_maps"); dir.create(mapdir, showWarnings = FALSE, recursive = TRUE)

corridor <- st_read(corridor_path(EV_DIR), quiet = TRUE) |> st_union()
zim <- st_union(st_make_valid(st_read(country_shp(COUNTRY), quiet = TRUE)))  # 'zim' = country polygon (any country)
seg <- if (!is.null(EV_SEG) && file.exists(EV_SEG))
         st_read(EV_SEG, quiet = TRUE) else NULL

SIG_LAB <- c(sif   = "SIF anomaly (mW m-2 sr-1 nm-1)",
             nirvr = "NIRvR anomaly (canopy structure)",
             phif  = "Phi_F anomaly (physiology, SIF/NIRvR)")
SHORT_LAB <- c(sif = "SIF anomaly", nirvr = "NIRvR anomaly", phif = "Phi_F anomaly")

## clean, dated figure title: "Cyclone Idai (Mar 2019)"  (EV_NAME overrides)
ev_name <- if (exists("EV_NAME")) EV_NAME else tools::toTitleCase(tolower(sub("_.*$", "", EV_LABEL)))
EVENT_TITLE <- sprintf("Cyclone %s (%s)", ev_name, format(EV_ENTRY, "%b %Y"))

cat("=== Spatial analysis:", EV_LABEL, "| entry", format(EV_ENTRY),
    "| clim", paste(clim_years, collapse=","), "===\n")
res <- compute_event_anomalies(EV_DIR, corridor, EV_ENTRY, EV_YEAR, clim_years)

cat("Baseline offset removed:\n"); print(round(res$offset, 5))

## measurements from de-meaned grids
meas <- list()
for (w in names(WINDOWS)) for (s in c("sif","nirvr","phif")) {
  a <- res$anom[[paste(w,s)]]; ad <- res$anomd[[paste(w,s)]]
  if (is.null(ad)) next
  vr <- values(a);  vr <- vr[is.finite(vr)]
  vd <- values(ad); vd <- vd[is.finite(vd)]
  if (length(vd)) meas[[length(meas)+1]] <- data.frame(
    event = EV_LABEL, window = w, signal = s, n_cells = length(vd),
    raw_mean = round(mean(vr),5), demeaned_mean = round(mean(vd),5),
    demeaned_median = round(median(vd),5),
    pct_suppressed = round(100*mean(vd<0),1),
    min = round(min(vd),5), max = round(max(vd),5))
}
measdf <- do.call(rbind, meas)
if (!is.null(measdf)) {
  write.csv(measdf, file.path(mapdir, "spatial_measurements.csv"), row.names = FALSE)
  cat("\n=== MEASUREMENTS (de-meaned) ===\n"); print(measdf, row.names = FALSE)
} else cat("\n** No usable spatial data for", EV_LABEL, "(all windows empty) **\n")

## maps — ALWAYS draw the de-meaned triplet + coverage so every event has a
## figure on record. When all windows are empty (monsoon blackout, e.g. Eloise)
## the panels render an honest red "no data" tag instead of being skipped.
have_any <- length(res$anomd) > 0
for (s in c("sif","nirvr","phif")) {
  draw_event_maps(res, s, EV_LABEL, zim, corridor, seg, mapdir, SIG_LAB[s],
                  demeaned = TRUE, event_title = EVENT_TITLE, short_lab = SHORT_LAB[s])
  if (have_any)  # RAW maps only meaningful when there is observed signal
    draw_event_maps(res, s, EV_LABEL, zim, corridor, seg, mapdir, SIG_LAB[s],
                    demeaned = FALSE, event_title = EVENT_TITLE, short_lab = SHORT_LAB[s])
}
## combined triplet (both de-meaned and raw when data exist)
draw_triplet(res, EVENT_TITLE, EV_LABEL, zim, corridor, seg, mapdir, demeaned = TRUE)
if (have_any) draw_triplet(res, EVENT_TITLE, EV_LABEL, zim, corridor, seg, mapdir, demeaned = FALSE)
draw_coverage(res, EV_LABEL, zim, corridor, mapdir)
if (!have_any)
  cat("NOTE:", EV_LABEL, "— all windows empty; drew documented-blackout panels.\n")
cat("DONE", EV_LABEL, "->", mapdir, "\n")
