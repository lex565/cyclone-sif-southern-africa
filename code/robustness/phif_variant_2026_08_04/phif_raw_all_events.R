# =============================================================================
# PhiF under the Zeng-consistent pairing (instantaneous SIF_743 / instantaneous
# NIRvR) versus the current pipeline (daylength-corrected SIF_Corr_743 / NIRvR),
# for all 12 acute-observable storm-country corridors.
#
# Method: the manuscript's own Eq 6 estimator, per-day anomalies against the
# +/-4-day pooled same-date climatology, run through the SAME corridors that
# produced the published tables (stored corridor .gpkg, no rebuild).
#
# SELF-CHECK per event: the recomputed SIF_Corr daily means and pooled
# climatology must reproduce the stored event_vs_climatology.csv.
#
# Incremental + resumable: one row appended per event as it completes.
# =============================================================================
suppressMessages({library(sf); library(ncdf4)})
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
sf::sf_use_s2(TRUE)

SP  <- file.path(Sys.getenv("CYCLONE_SIF_OUT", "derived_data"), "robustness", "phif_variant_2026_08_04")
OUT <- file.path(SP, "phif_raw_vs_corr_ALL.csv")
WIN  <- list(baseline = c(-14, -8), acute = c(0, 6))
POOL <- 4

## ---- the 12 acute-observable corridors (read off the stored series) ----
EVENTS <- list(
  c("Madagascar","Belna_2019"),     c("Mozambique","Idai_2019"),
  c("Madagascar","Diane_2020"),     c("Mozambique","Desmond_2019"),
  c("Madagascar","Chalane_2020"),   c("Madagascar","Francisco_2020"),
  c("Malawi","Idai_2019"),          c("Zimbabwe","Idai_2019"),
  c("Mozambique","Chalane_2020"),   c("Zimbabwe","Chalane_2020"),
  c("Botswana","Chalane_2020"),     c("Mozambique","Kenneth_2019"))

## ---- one day: corridor-mean of both SIF variants, NIRvR and both PhiF ----
read_day <- function(date, bbox, corridor) {
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
                 sif     = g("PRODUCT/SIF_Corr_743"),
                 sif_raw = g("PRODUCT/SIF_743"),
                 cf  = g("PRODUCT/SUPPORT_DATA/INPUT_DATA/cloud_fraction_L2"),
                 sza = g("PRODUCT/SUPPORT_DATA/GEOLOCATIONS/solar_zenith_angle"),
                 nirrad = g("PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/Mean_TOA_RAD_743"),
                 red = toa[RED_I, ], nir = toa[NIR_I, ])
    }
  }, error = function(e) { message("   SKIPPED unreadable: ", basename(f)); NULL })
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
  c(n = sum(ok),
    sif      = mean(df$sif[ok]),
    sif_raw  = mean(df$sif_raw[ok]),
    nirvr    = mean(nirvr[ok]),
    phif     = mean(df$sif[ok]     / nirvr[ok]),
    phif_raw = mean(df$sif_raw[ok] / nirvr[ok]))
}

NAV <- c(n = 0, sif = NA, sif_raw = NA, nirvr = NA, phif = NA, phif_raw = NA)

run_event <- function(country, event) {
  evdir <- file.path(RESULTS_ROOT, country, event)
  stored <- read.csv(file.path(evdir, "event_vs_climatology.csv"))
  entry  <- as.Date(stored$date[stored$rel == 0])
  ev_yr  <- as.integer(format(entry, "%Y"))
  clim_yrs <- setdiff(SIF_YEARS, ev_yr)
  corridor <- st_union(st_geometry(st_read(corridor_path(evdir), quiet = TRUE)))
  bb <- st_bbox(corridor)
  bbox <- c(xmin = bb[["xmin"]] - .2, xmax = bb[["xmax"]] + .2,
            ymin = bb[["ymin"]] - .2, ymax = bb[["ymax"]] + .2)
  cat(sprintf("   entry %s | event yr %d | clim %s | corridor %s\n",
      format(entry), ev_yr, paste(clim_yrs, collapse=","), basename(corridor_path(evdir))))
  flush.console()

  CACHE <- new.env(hash = TRUE, parent = emptyenv())
  dm <- function(d) {
    k <- format(d, "%Y-%m-%d")
    if (!is.null(CACHE[[k]])) return(CACHE[[k]])
    v <- read_day(d, bbox, corridor); if (is.null(v)) v <- NAV
    CACHE[[k]] <- v; v
  }

  rels <- min(sapply(WIN, `[`, 1)):max(sapply(WIN, `[`, 2))
  evt <- do.call(rbind, lapply(rels, function(r) {
    m <- dm(entry + r); data.frame(rel = r, t(m))
  }))
  cat(sprintf("   event days read (%d), usable %d\n", length(rels), sum(evt$n > 0)))
  flush.console()

  clim <- do.call(rbind, lapply(rels, function(r) {
    acc <- NULL
    for (yr in clim_yrs) {
      anchor <- as.Date(sprintf("%d%s", yr, format(entry + r, "-%m-%d")))
      if (is.na(anchor)) next
      for (off in -POOL:POOL) {
        m <- dm(anchor + off)
        if (is.finite(m["sif"])) acc <- rbind(acc, m)
      }
    }
    if (is.null(acc)) return(data.frame(rel = r, clim_n = 0, sif.clim = NA,
        sif_raw.clim = NA, nirvr.clim = NA, phif.clim = NA, phif_raw.clim = NA))
    data.frame(rel = r, clim_n = nrow(acc),
               sif.clim = mean(acc[,"sif"]), sif_raw.clim = mean(acc[,"sif_raw"]),
               nirvr.clim = mean(acc[,"nirvr"]), phif.clim = mean(acc[,"phif"]),
               phif_raw.clim = mean(acc[,"phif_raw"]))
  }))
  cat("   climatology pooled\n"); flush.console()

  m <- merge(evt, clim, by = "rel"); m <- m[order(m$rel), ]
  m$window <- NA_character_
  for (w in names(WIN)) m$window[m$rel >= WIN[[w]][1] & m$rel <= WIN[[w]][2]] <- w
  m$sif_anom      <- m$sif      - m$sif.clim
  m$sif_raw_anom  <- m$sif_raw  - m$sif_raw.clim
  m$nirvr_anom    <- m$nirvr    - m$nirvr.clim
  m$phif_anom     <- m$phif     - m$phif.clim
  m$phif_raw_anom <- m$phif_raw - m$phif_raw.clim
  m$dcf <- m$sif / m$sif_raw
  write.csv(m, file.path(SP, sprintf("series_%s_%s.csv", country, event)), row.names = FALSE)

  ## ---- self-check against the stored canonical series ----
  s <- stored[stored$rel %in% rels, ]
  j <- merge(m[, c("rel","sif","phif")], s[, c("rel","sif","phif","sif.clim")],
             by = "rel", suffixes = c(".new", ".old"))
  d_sif  <- max(abs(j$sif.new  - j$sif.old),  na.rm = TRUE)
  d_phif <- max(abs(j$phif.new - j$phif.old), na.rm = TRUE)
  chk <- if (is.finite(d_sif) && d_sif < 1e-8 && d_phif < 1e-10) "REPRODUCED" else "MISMATCH"
  cat(sprintf("   self-check vs stored series: %s (max |dSIF|=%.2e, |dPhiF|=%.2e)\n",
              chk, d_sif, d_phif)); flush.console()

  W <- function(lbl) !is.na(m$window) & m$window == lbl
  pct <- function(anom, clim) {
    a <- mean(m[[anom]][W("acute")],    na.rm = TRUE)
    b <- mean(m[[anom]][W("baseline")], na.rm = TRUE)
    cb <- mean(m[[clim]][W("baseline")], na.rm = TRUE)
    100 * (a - b) / cb
  }
  dS_c <- pct("sif_anom", "sif.clim");     dS_r <- pct("sif_raw_anom", "sif_raw.clim")
  dN   <- pct("nirvr_anom", "nirvr.clim")
  dP_c <- pct("phif_anom", "phif.clim");   dP_r <- pct("phif_raw_anom", "phif_raw.clim")
  res  <- function(ds) 100 * ((1 + ds/100) / (1 + dN/100) - 1)
  dcfb <- mean(m$dcf[W("baseline") & is.finite(m$dcf)])
  dcfa <- mean(m$dcf[W("acute")    & is.finite(m$dcf)])

  data.frame(country, event, entry = format(entry),
             acute_days = sum(evt$n[W("acute")] > 0), acute_soundings = sum(evt$n[W("acute")]),
             self_check = chk,
             dSIF_corr = dS_c, dSIF_raw = dS_r,
             dNIRvR = dN,
             PhiF_direct_corr = dP_c, PhiF_direct_raw = dP_r,
             PhiF_resid_corr = res(dS_c), PhiF_resid_raw = res(dS_r),
             resid_diff_pp = res(dS_r) - res(dS_c),
             DCF_base = dcfb, DCF_acute = dcfa,
             DCF_drift_pct = 100 * (dcfa - dcfb) / dcfb)
}

done <- if (file.exists(OUT)) read.csv(OUT) else NULL
for (i in seq_along(EVENTS)) {
  cc <- EVENTS[[i]][1]; ee <- EVENTS[[i]][2]
  if (!is.null(done) && any(done$country == cc & done$event == ee)) {
    cat(sprintf("[%2d/12] %s / %s  ALREADY DONE, skipping\n", i, cc, ee)); next }
  cat(sprintf("\n[%2d/12] %s / %s   (%s)\n", i, cc, ee, format(Sys.time(), "%H:%M:%S")))
  flush.console()
  r <- try(run_event(cc, ee), silent = FALSE)
  if (inherits(r, "try-error")) { cat("   FAILED, continuing\n"); next }
  write.table(r, OUT, sep = ",", row.names = FALSE, col.names = !file.exists(OUT),
              append = file.exists(OUT))
  cat(sprintf("   -> dSIF %+.2f/%+.2f  PhiF resid %+.2f/%+.2f (%+.2f pp)\n",
      r$dSIF_corr, r$dSIF_raw, r$PhiF_resid_corr, r$PhiF_resid_raw, r$resid_diff_pp))
  flush.console(); gc(verbose = FALSE)
}

cat("\n\n=================== FINAL COMPARISON ===================\n")
d <- read.csv(OUT)
print(d[, c("country","event","acute_days","self_check","dSIF_corr","dSIF_raw",
            "dNIRvR","PhiF_resid_corr","PhiF_resid_raw","resid_diff_pp")],
      row.names = FALSE, digits = 4)
cat("\nDCF drift baseline -> acute (%):\n")
print(d[, c("country","event","DCF_base","DCF_acute","DCF_drift_pct")], row.names = FALSE, digits = 4)
cat(sprintf("\nmean |PhiF residual shift| = %.2f pp | max = %.2f pp | sign flips = %d\n",
    mean(abs(d$resid_diff_pp)), max(abs(d$resid_diff_pp)),
    sum(sign(d$PhiF_resid_corr) != sign(d$PhiF_resid_raw))))
cat("written:", OUT, "\n")
