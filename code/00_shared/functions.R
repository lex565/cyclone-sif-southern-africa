# =============================================================================
# 00_shared/functions.R  —  Reusable extraction & analysis functions.
# Source AFTER config.R. Requires: sf, terra, ncdf4.
# =============================================================================
suppressMessages({library(sf); library(terra); library(ncdf4)})
sf::sf_use_s2(TRUE)

## ---- read one TROPOSIF day, QC-filter, return sounding-level data frame ----
## Returns data.frame(lon,lat,sif,nirvr,phif) for QC-passing soundings in bbox.
read_sif_day <- function(date, bbox, corridor = NULL) {
  f <- file.path(SIF_ROOT, format(date, "%Y"),
                 sprintf("TROPOSIF_L2B_%s.nc", format(date, "%Y-%m-%d")))
  if (!file.exists(f)) return(NULL)
  nc <- nc_open(f); on.exit(nc_close(nc))
  # Robust read: a corrupt/truncated NetCDF (C-level read error) must not crash
  # the whole pipeline — skip the day and REPORT the offending file by name.
  df <- tryCatch({
    lat <- ncvar_get(nc, "PRODUCT/latitude")
    lon <- ncvar_get(nc, "PRODUCT/longitude")
    keep <- which(lon >= bbox["xmin"] & lon <= bbox["xmax"] &
                  lat >= bbox["ymin"] & lat <= bbox["ymax"])
    if (!length(keep)) NULL else {
      g <- function(p) ncvar_get(nc, p)[keep]
      toa <- ncvar_get(nc, "PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/TOA_RFL")[, keep, drop = FALSE]
      data.frame(lon = lon[keep], lat = lat[keep],
                 sif = g("PRODUCT/SIF_Corr_743"),
                 cf  = g("PRODUCT/SUPPORT_DATA/INPUT_DATA/cloud_fraction_L2"),
                 sza = g("PRODUCT/SUPPORT_DATA/GEOLOCATIONS/solar_zenith_angle"),
                 nirrad = g("PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/Mean_TOA_RAD_743"),
                 red = toa[RED_I, ], nir = toa[NIR_I, ])
    }
  }, error = function(e) {
    message(sprintf("[read_sif_day] SKIPPED unreadable NetCDF: %s  (%s)",
                    basename(f), conditionMessage(e))); NULL
  })
  if (is.null(df) || !nrow(df)) return(NULL)
  if (!is.null(corridor)) {
    pin <- st_within(st_as_sf(df, coords = c("lon","lat"), crs = 4326),
                     corridor, sparse = FALSE)[, 1]
    df <- df[pin, , drop = FALSE]
  }
  if (!nrow(df)) return(NULL)
  ndvi  <- (df$nir - df$red) / (df$nir + df$red)
  nirvr <- ndvi * df$nirrad
  ok <- df$cf < CF_MAX & df$sza < SZA_MAX &
        df$nirrad >= TOA_LO & df$nirrad <= TOA_HI &
        is.finite(df$sif) & is.finite(nirvr) & nirvr > 0 & ndvi > NDVI_MIN
  if (!any(ok)) return(NULL)
  data.frame(lon = df$lon[ok], lat = df$lat[ok],
             sif = df$sif[ok], nirvr = nirvr[ok], phif = df$sif[ok] / nirvr[ok])
}

## ---- build storm corridor: track LINE buffered (equal-area) ∩ country ----
build_corridor <- function(sid, country_shp, buffer_km = BUFFER_KM) {
  pts <- st_read(IBTRACS_PTS, quiet = TRUE)
  s <- pts[pts$SID == sid, ]
  s$ISO_TIME <- as.POSIXct(s$ISO_TIME, tz = "UTC")
  s <- s[order(s$ISO_TIME), ]
  track <- st_cast(st_combine(s), "LINESTRING"); st_crs(track) <- 4326
  country <- st_union(st_make_valid(st_read(country_shp, quiet = TRUE)))
  ctr <- st_coordinates(st_centroid(st_union(s)))
  laea <- sprintf("+proj=laea +lat_0=%f +lon_0=%f +datum=WGS84 +units=m +no_defs",
                  ctr[2], ctr[1])
  corr <- st_intersection(st_buffer(st_transform(track, laea), buffer_km * 1000),
                          st_transform(country, laea)) |>
          st_transform(4326) |> st_union()
  list(corridor = corr, track = track, segment = st_intersection(track, country),
       points = s, country = country)
}

## ---- grid sounding points to a raster (mean) with coverage mask ----
grid_field <- function(pts, field, tmpl, vmask, min_n = MIN_N) {
  if (is.null(pts) || !nrow(pts)) return(NULL)
  v <- vect(pts, geom = c("lon","lat"), crs = "EPSG:4326")
  r <- rasterize(v, tmpl, field = field, fun = mean, na.rm = TRUE)
  n <- rasterize(v, tmpl, fun = "length")
  r[n < min_n] <- NA
  list(mean = mask(r, vmask), n = mask(n, vmask))
}

## ---- collect QC soundings across a set of rel-days x years ----
collect_soundings <- function(rels, years, entry, bbox, corridor) {
  out <- list()
  for (yr in years) {
    base <- as.Date(sprintf("%d-01-01", yr)) - 1 + as.integer(format(entry, "%j"))
    for (r in rels) {
      p <- read_sif_day(base + r, bbox, corridor)
      if (!is.null(p)) out[[length(out) + 1]] <- p
    }
  }
  if (!length(out)) return(NULL)
  do.call(rbind, out)
}

## ---- CHIRPS daily corridor-mean rainfall (mm) ----
chirps_corridor_mean <- function(date, vcorr) {
  f <- file.path(CHIRPS_ROOT, format(date, "%Y"),
                 sprintf("chirps-v2.0.%s.tif.gz", format(date, "%Y.%m.%d")))
  if (!file.exists(f)) return(NA)
  r <- tryCatch(rast(paste0("/vsigzip/", f)), error = function(e) NULL)
  if (is.null(r)) return(NA)
  r <- crop(r, vcorr); r[r < 0] <- NA
  as.numeric(terra::extract(r, vcorr, fun = mean, na.rm = TRUE, ID = FALSE)[1, 1])
}

## ---- daily corridor-mean triplet for one date (QC-filtered, clipped) ----
corridor_day_mean <- function(date, bbox, corridor) {
  p <- read_sif_day(date, bbox, corridor)
  if (is.null(p) || !nrow(p)) return(c(n = 0, sif = NA, nirvr = NA, phif = NA))
  c(n = nrow(p), sif = mean(p$sif), nirvr = mean(p$nirvr), phif = mean(p$phif))
}

## ---- daily event series + stabilized (+/-pool day) climatology -> data.frame ----
## Mirrors event_vs_climatology.csv: per rel-day event triplet, pooled-climatology
## triplet (clim years, +/-pool days), anomalies, and BER window label.
build_event_series <- function(entry, event_year, clim_years, bbox, corridor,
                               windows = WINDOWS, pool = 4) {
  rel_range <- min(sapply(windows, `[`, 1)):max(sapply(windows, `[`, 2))
  evt <- do.call(rbind, lapply(rel_range, function(r) {
    m <- corridor_day_mean(entry + r, bbox, corridor)
    data.frame(rel = r, date = entry + r, n = m["n"],
               sif = m["sif"], nirvr = m["nirvr"], phif = m["phif"])
  }))
  clim_for_rel <- function(r) {
    acc <- list(sif = c(), nirvr = c(), phif = c())
    for (yr in clim_years) {
      anchor <- as.Date(sprintf("%d%s", yr, format(entry + r, "-%m-%d")), format = "%Y-%m-%d")
      if (is.na(anchor)) next   # Feb 29 of a leap event-year has no match in a non-leap clim year
      for (off in -pool:pool) {
        m <- corridor_day_mean(anchor + off, bbox, corridor)
        if (is.finite(m["sif"])) { acc$sif <- c(acc$sif, m["sif"])
          acc$nirvr <- c(acc$nirvr, m["nirvr"]); acc$phif <- c(acc$phif, m["phif"]) }
      }
    }
    c(n = length(acc$sif), sif = mean(acc$sif), nirvr = mean(acc$nirvr), phif = mean(acc$phif))
  }
  clim <- do.call(rbind, lapply(rel_range, function(r) {
    cm <- clim_for_rel(r)
    data.frame(rel = r, clim_n = cm["n"], sif.clim = cm["sif"],
               nirvr.clim = cm["nirvr"], phif.clim = cm["phif"])
  }))
  m <- merge(evt, clim, by = "rel"); m <- m[order(m$rel), ]
  m$sif_anom <- m$sif - m$sif.clim
  m$nirvr_anom <- m$nirvr - m$nirvr.clim
  m$phif_anom <- m$phif - m$phif.clim
  m$window <- NA_character_
  for (w in names(windows)) m$window[m$rel >= windows[[w]][1] & m$rel <= windows[[w]][2]] <- w
  rownames(m) <- NULL
  m
}

## ---- horizontal color bar legend for terra maps ----
add_colorbar <- function(zmax, pal = DIV_PAL, n = 20, title = "anomaly") {
  fields_ok <- requireNamespace("fields", quietly = TRUE)
  if (fields_ok) {
    fields::image.plot(legend.only = TRUE, zlim = c(-zmax, zmax),
                       col = pal(n), horizontal = TRUE,
                       legend.lab = title, legend.line = 2.2)
  }
}

message("[functions] loaded: read_sif_day, build_corridor, grid_field, ",
        "collect_soundings, chirps_corridor_mean, add_colorbar")
