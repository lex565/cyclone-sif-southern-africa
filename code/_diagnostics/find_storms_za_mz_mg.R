# Find SI-basin storms (2018-2021) whose track LINE intersects
# South Africa / Mozambique / Madagascar. Same logic as find_storms_bw_mw.R.
suppressMessages({library(sf)}); sf::sf_use_s2(TRUE)
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))

pts <- st_read(IBTRACS_PTS, quiet = TRUE)
pts$ISO_TIME <- as.POSIXct(pts$ISO_TIME, tz = "UTC")
pts$SEASON <- as.integer(as.character(pts$SEASON))
pts <- pts[!is.na(pts$SEASON) & pts$SEASON >= 2018 & pts$SEASON <= 2021, ]
wind_col <- intersect(c("USA_WIND","WMO_WIND"), names(pts))[1]
pts$WIND <- suppressWarnings(as.numeric(as.character(pts[[wind_col]])))

for (cn in c("South_Africa","Mozambique","Madagascar")) {
  shp <- file.path(ECO_BYCOUNTRY, sprintf("Ecoregions2017_%s.shp", cn))
  poly <- st_union(st_make_valid(st_read(shp, quiet = TRUE)))
  cat(sprintf("\n========== %s ==========\n", cn))
  hits <- 0
  for (sid in unique(pts$SID)) {
    s <- pts[pts$SID == sid, ]; s <- s[order(s$ISO_TIME), ]
    if (nrow(s) < 2) next
    track <- st_cast(st_combine(s), "LINESTRING"); st_crs(track) <- 4326
    if (!as.logical(st_intersects(track, poly, sparse = FALSE))) next
    inside <- st_within(s, poly, sparse = FALSE)[, 1]
    d_km <- as.numeric(min(st_distance(s, poly))) / 1000
    nm <- as.character(s$NAME[1]); seas <- s$SEASON[1]
    entry <- if (any(inside)) min(s$ISO_TIME[inside]) else s$ISO_TIME[which.min(st_distance(s, poly))]
    wmax <- suppressWarnings(max(s$WIND[inside], na.rm = TRUE))
    if (!is.finite(wmax)) wmax <- suppressWarnings(max(s$WIND, na.rm = TRUE))
    hits <- hits + 1
    cat(sprintf("  %-12s SID=%s season=%d | in-country fixes=%d | nearest=%.1f km | entry=%s | wind~%s kt\n",
                nm, sid, seas, sum(inside), d_km, format(entry, "%Y-%m-%d %H:%MZ"),
                ifelse(is.finite(wmax), round(wmax), "NA")))
  }
  if (hits == 0) cat("  (no SI track line intersects in 2018-2021)\n")
}
cat("\nDONE\n")
