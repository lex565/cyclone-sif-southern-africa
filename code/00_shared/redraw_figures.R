# =============================================================================
# 00_shared/redraw_figures.R
# Fast figure re-render using the IMPROVED engine, WITHOUT recomputing anomalies.
# Loads existing de-meaned GeoTIFFs (anomd_<signal>_<window>.tif) and redraws the
# single-signal grids + combined triplet. No SIF re-extraction.
#
# REQUIRED before sourcing:  EV_LABEL, EV_ENTRY, EV_DIR, EV_SEG (or NULL)
# =============================================================================
this_dir <- Sys.getenv("CYCLONE_SIF_CODE", Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"))
source(file.path(this_dir, "config.R"))
source(file.path(this_dir, "functions.R"))
source(file.path(this_dir, "spatial_engine.R"))

if (!exists("EV_LABEL")) stop("Set EV_LABEL, EV_ENTRY, EV_DIR, EV_SEG first.")
if (!exists("COUNTRY")) COUNTRY <- "Zimbabwe"
CITIES <- COUNTRY_CITIES[[COUNTRY]]
mapdir <- file.path(EV_DIR, "spatial_maps")

corridor <- st_read(corridor_path(EV_DIR), quiet = TRUE) |> st_union()
zim <- st_union(st_make_valid(st_read(country_shp(COUNTRY), quiet = TRUE)))  # country polygon (any country)
seg <- if (!is.null(EV_SEG) && file.exists(EV_SEG)) st_read(EV_SEG, quiet = TRUE) else NULL

## rebuild res$anomd from saved de-meaned tifs
anomd <- list()
for (w in names(WINDOWS)) for (s in c("sif","nirvr","phif")) {
  f <- file.path(mapdir, sprintf("anomd_%s_%s.tif", s, w))
  if (file.exists(f)) anomd[[paste(w, s)]] <- rast(f)
}
res <- list(anomd = anomd, anom = anomd)   # anom unused here (demeaned only)
cat("loaded", length(anomd), "de-meaned grids for", EV_LABEL, "\n")

SIG_LAB   <- c(sif="SIF anomaly (mW m-2 sr-1 nm-1)",
               nirvr="NIRvR anomaly (canopy structure)",
               phif="Phi_F anomaly (physiology, SIF/NIRvR)")
SHORT_LAB <- c(sif="SIF anomaly", nirvr="NIRvR anomaly", phif="Phi_F anomaly")
ev_name <- tools::toTitleCase(tolower(sub("_.*$", "", EV_LABEL)))
EVENT_TITLE <- sprintf("Cyclone %s (%s)", ev_name, format(EV_ENTRY, "%b %Y"))

for (s in c("sif","nirvr","phif"))
  draw_event_maps(res, s, EV_LABEL, zim, corridor, seg, mapdir, SIG_LAB[s],
                  demeaned = TRUE, event_title = EVENT_TITLE, short_lab = SHORT_LAB[s])
draw_triplet(res, EVENT_TITLE, EV_LABEL, zim, corridor, seg, mapdir, demeaned = TRUE)
cat("DONE redraw ->", mapdir, "\n")
