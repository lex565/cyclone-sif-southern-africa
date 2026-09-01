# =============================================================================
# Does it matter whether the pipeline uses raw SIF_743 or daylength-corrected
# SIF_Corr_743?  Recompute the Idai/Zimbabwe 200 km acute response BOTH ways
# through the manuscript's own estimator (Eq 6) and compare.
#
# Self-check: the SIF_Corr run must reproduce the published -37.8%.
# =============================================================================
suppressMessages({library(sf); library(terra); library(ncdf4)})
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
sf::sf_use_s2(TRUE)

EVENT <- "Idai_Zimbabwe"; SID <- "2019063S18038"
ENTRY <- as.Date("2019-03-15"); EV_YR <- 2019; CLIM_YRS <- c(2018, 2020, 2021)
WIN <- list(baseline = c(-14, -8), acute = c(0, 6)); POOL <- 4
OUT <- file.path(Sys.getenv("CYCLONE_SIF_OUT", "derived_data"), "robustness", "phif_variant_2026_08_04")

## ---- read one day, carrying BOTH SIF variants through identical QC ----
read_day_both <- function(date, bbox, corridor) {
  f <- file.path(SIF_ROOT, format(date, "%Y"),
                 sprintf("TROPOSIF_L2B_%s.nc", format(date, "%Y-%m-%d")))
  if (!file.exists(f)) return(NULL)
  nc <- nc_open(f); on.exit(nc_close(nc))
  df <- tryCatch({
    lat <- ncvar_get(nc, "PRODUCT/latitude"); lon <- ncvar_get(nc, "PRODUCT/longitude")
    keep <- which(lon >= bbox["xmin"] & lon <= bbox["xmax"] &
                  lat >= bbox["ymin"] & lat <= bbox["ymax"])
    if (!length(keep)) NULL else {
      g <- function(p) ncvar_get(nc, p)[keep]
      toa <- ncvar_get(nc, "PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/TOA_RFL")[, keep, drop = FALSE]
      data.frame(lon = lon[keep], lat = lat[keep],
                 sif     = g("PRODUCT/SIF_Corr_743"),   # what the pipeline uses
                 sif_raw = g("PRODUCT/SIF_743"),        # the instantaneous retrieval
                 cf  = g("PRODUCT/SUPPORT_DATA/INPUT_DATA/cloud_fraction_L2"),
                 sza = g("PRODUCT/SUPPORT_DATA/GEOLOCATIONS/solar_zenith_angle"),
                 nirrad = g("PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/Mean_TOA_RAD_743"),
                 red = toa[RED_I, ], nir = toa[NIR_I, ])
    }
  }, error = function(e) { message("  SKIPPED unreadable: ", basename(f)); NULL })
  if (is.null(df) || !nrow(df)) return(NULL)
  pin <- st_within(st_as_sf(df, coords = c("lon","lat"), crs = 4326),
                   corridor, sparse = FALSE)[, 1]
  df <- df[pin, , drop = FALSE]
  if (!nrow(df)) return(NULL)
  ndvi  <- (df$nir - df$red) / (df$nir + df$red)
  nirvr <- ndvi * df$nirrad
  ok <- df$cf < CF_MAX & df$sza < SZA_MAX & df$nirrad >= TOA_LO & df$nirrad <= TOA_HI &
        is.finite(df$sif) & is.finite(df$sif_raw) & is.finite(nirvr) & nirvr > 0 & ndvi > NDVI_MIN
  if (!any(ok)) return(NULL)
  data.frame(sif = df$sif[ok], sif_raw = df$sif_raw[ok], nirvr = nirvr[ok],
             phif = df$sif[ok] / nirvr[ok], phif_raw = df$sif_raw[ok] / nirvr[ok])
}

## ---- memoised corridor-day mean (the uncached version re-reads ~567 days) ----
CACHE <- new.env(hash = TRUE, parent = emptyenv())
day_mean <- function(date, bbox, corridor) {
  k <- format(date, "%Y-%m-%d")
  if (!is.null(CACHE[[k]])) return(CACHE[[k]])
  p <- read_day_both(date, bbox, corridor)
  v <- if (is.null(p) || !nrow(p))
         c(n = 0, sif = NA, sif_raw = NA, nirvr = NA, phif = NA, phif_raw = NA)
       else c(n = nrow(p), sif = mean(p$sif), sif_raw = mean(p$sif_raw),
              nirvr = mean(p$nirvr), phif = mean(p$phif), phif_raw = mean(p$phif_raw))
  CACHE[[k]] <- v; v
}

cat("[1/4] building 200 km corridor for", EVENT, "\n"); flush.console()
pts <- st_read(IBTRACS_PTS, quiet = TRUE)
s <- pts[pts$SID == SID, ]; s$ISO_TIME <- as.POSIXct(s$ISO_TIME, tz = "UTC")
s <- s[order(s$ISO_TIME), ]
track <- st_cast(st_combine(s), "LINESTRING"); st_crs(track) <- 4326
country <- st_union(st_make_valid(st_read(country_shp("Zimbabwe"), quiet = TRUE)))
ctr <- st_coordinates(st_centroid(st_union(s)))
laea <- sprintf("+proj=laea +lat_0=%f +lon_0=%f +datum=WGS84 +units=m +no_defs", ctr[2], ctr[1])
corr <- st_union(st_transform(st_intersection(
          st_buffer(st_transform(track, laea), BUFFER_KM * 1000),
          st_transform(country, laea)), 4326))
rm(pts); gc(verbose = FALSE)
bb <- st_bbox(corr); bb <- c(xmin = bb[["xmin"]] - .2, xmax = bb[["xmax"]] + .2,
                             ymin = bb[["ymin"]] - .2, ymax = bb[["ymax"]] + .2)
cat("    corridor bbox:", sprintf("%.2f %.2f %.2f %.2f", bb["xmin"], bb["xmax"], bb["ymin"], bb["ymax"]), "\n")

rels <- min(sapply(WIN, `[`, 1)):max(sapply(WIN, `[`, 2))
cat("[2/4] event-year daily means, rel", min(rels), "to", max(rels), "\n"); flush.console()
evt <- do.call(rbind, lapply(rels, function(r) {
  m <- day_mean(ENTRY + r, bb, corr)
  cat(sprintf("    rel %+3d  %s  n=%5d\n", r, format(ENTRY + r), m["n"])); flush.console()
  data.frame(rel = r, n = m["n"], sif = m["sif"], sif_raw = m["sif_raw"],
             nirvr = m["nirvr"], phif = m["phif"], phif_raw = m["phif_raw"])
}))

cat("[3/4] pooled climatology (+/-", POOL, "d, years ", paste(CLIM_YRS, collapse=","), ")\n", sep=""); flush.console()
clim <- do.call(rbind, lapply(rels, function(r) {
  acc <- list(sif = c(), sif_raw = c(), nirvr = c(), phif = c(), phif_raw = c())
  for (yr in CLIM_YRS) {
    anchor <- as.Date(sprintf("%d%s", yr, format(ENTRY + r, "-%m-%d")))
    if (is.na(anchor)) next
    for (off in -POOL:POOL) {
      m <- day_mean(anchor + off, bb, corr)
      if (is.finite(m["sif"])) for (v in names(acc)) acc[[v]] <- c(acc[[v]], m[v])
    }
  }
  cat(sprintf("    rel %+3d  clim_n=%2d\n", r, length(acc$sif))); flush.console()
  data.frame(rel = r, clim_n = length(acc$sif),
             sif.clim = mean(acc$sif), sif_raw.clim = mean(acc$sif_raw),
             nirvr.clim = mean(acc$nirvr), phif.clim = mean(acc$phif),
             phif_raw.clim = mean(acc$phif_raw))
}))

m <- merge(evt, clim, by = "rel"); m <- m[order(m$rel), ]
m$sif_anom      <- m$sif - m$sif.clim
m$sif_raw_anom  <- m$sif_raw - m$sif_raw.clim
m$phif_anom     <- m$phif - m$phif.clim
m$phif_raw_anom <- m$phif_raw - m$phif_raw.clim
m$dcf <- m$sif / m$sif_raw
m$window <- NA_character_
for (w in names(WIN)) m$window[m$rel >= WIN[[w]][1] & m$rel <= WIN[[w]][2]] <- w
write.csv(m, file.path(OUT, "raw_vs_corr_series.csv"), row.names = FALSE)

## ---- Eq 6: baseline-de-meaned acute % change ----
pct <- function(anom, climcol) {
  a <- mean(m[[anom]][m$window == "acute"], na.rm = TRUE)
  b <- mean(m[[anom]][m$window == "baseline"], na.rm = TRUE)
  cb <- mean(m[[climcol]][m$window == "baseline"], na.rm = TRUE)
  100 * (a - b) / cb
}
cat("\n[4/4] RESULTS -", EVENT, "200 km\n")
cat("=================================================================\n")
cat(sprintf("  SIF  using SIF_Corr_743 (published pipeline) : %+7.2f %%   <- published -37.8\n",
            pct("sif_anom", "sif.clim")))
cat(sprintf("  SIF  using SIF_743 (raw / instantaneous)     : %+7.2f %%\n",
            pct("sif_raw_anom", "sif_raw.clim")))
cat(sprintf("  PhiF using SIF_Corr_743 / NIRvR             : %+7.2f %%\n",
            pct("phif_anom", "phif.clim")))
cat(sprintf("  PhiF using SIF_743 / NIRvR                  : %+7.2f %%\n",
            pct("phif_raw_anom", "phif_raw.clim")))
cat("-----------------------------------------------------------------\n")
d <- m$dcf[is.finite(m$dcf)]
cat(sprintf("  DCF over all used days: mean %.4f  sd %.5f  range %.4f-%.4f\n",
            mean(d), sd(d), min(d), max(d)))
for (w in names(WIN)) {
  dw <- m$dcf[m$window == w & is.finite(m$dcf)]
  if (length(dw)) cat(sprintf("  DCF %-8s window : mean %.4f  (n=%d days)\n", w, mean(dw), length(dw)))
}
r <- cor(m$sif[is.finite(m$sif)], m$sif_raw[is.finite(m$sif_raw)])
cat(sprintf("  r(daily corridor-mean corrected, raw) = %.6f\n", r))
cat("=================================================================\n")
cat("series written to", file.path(OUT, "raw_vs_corr_series.csv"), "\n")
