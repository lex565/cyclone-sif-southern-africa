# =============================================================================
# 00_shared/original_metrics.R
# Re-implements the manuscript's ORIGINAL Section-3 metrics, country-agnostic.
# Additive: reads existing corridor / event_vs_climatology / de-meaned tifs and
# writes only into <evdir>/metrics/. Nothing in spatial_maps/ is touched.
#
#   Eq 1  Coverage Fraction  CF = A_footprint / A_national
#   Eq 2  Dilution Factor    DF = A_national / A_footprint   (= 1/CF)
#   Eq 5  Pre-event anomaly  (handled upstream; reused here)
#   Eq 6  %-change vs baseline  ΔSIF% = anom_demeaned / clim_baseline * 100
#   Eq 7  Recovery ratios    early (+1..+10 d) & late (+45..+60 d)
#   Eq 8  SIF–GPP Pearson    PML-V2 8-day GPP, SIF aggregated to 8-day grid
#   §3.7  5-class response classification + Shannon entropy (acute window)
#
# Source AFTER config.R + functions.R.
# =============================================================================
suppressMessages({library(sf); library(terra)})

GPP_ROOT <- file.path(DATA_ROOT, "GPP/GPP download Quarters")
# folder name differs per country (note the Zimbabwe typo "Quaters-Zim")
GPP_DIR <- list(Zimbabwe = "Quaters-Zim", Botswana = "Quarters-Botswana",
                Malawi   = "Quarters-Malawi",
                Mozambique = "Quarters-Mozambique",
                South_Africa = "Quarters-South_Africa")

# ---- Eq 1 / Eq 2 : coverage fraction & dilution factor -----------------------
# Areas computed in an equal-area projection centred on the corridor.
coverage_dilution <- function(corridor, country) {
  ctr <- st_coordinates(st_centroid(st_union(corridor)))
  laea <- sprintf("+proj=laea +lat_0=%f +lon_0=%f +datum=WGS84 +units=m +no_defs",
                  ctr[2], ctr[1])
  a_fp  <- as.numeric(sum(st_area(st_transform(st_union(corridor), laea))))
  a_nat <- as.numeric(sum(st_area(st_transform(st_union(country),  laea))))
  CF <- a_fp / a_nat
  data.frame(A_footprint_km2 = round(a_fp/1e6, 1),
             A_national_km2   = round(a_nat/1e6, 1),
             CF = round(CF, 4), DF = round(1/CF, 2))
}

# ---- PML-V2 8-day GPP helpers ------------------------------------------------
# Canonical 8-day grid (resets at year start): start DOY = 8*floor((doy-1)/8)+1.
# Folder layout: <GPP_DIR>/<year>/Q{q}/PML_<Country>_<year>_Q{q}_{NNN}.tif
# Q1 holds composites 1..12 (DOY 1..89), Q2 13..24 (DOY 97..185), etc.
gpp_start_doy <- function(doy) 8L * ((doy - 1L) %/% 8L) + 1L

gpp_path <- function(country, year, start_doy) {
  seqidx <- (start_doy - 1L) %/% 8L + 1L          # 1..46 across the year
  q   <- (seqidx - 1L) %/% 12L + 1L               # quarter 1..4
  idx <- (seqidx - 1L) %% 12L + 1L                # 1..12 within quarter
  file.path(GPP_ROOT, GPP_DIR[[country]], year, sprintf("Q%d", q),
            sprintf("PML_%s_%d_Q%d_%03d.tif", country, year, q, idx))
}

gpp_composite_mean <- function(country, year, start_doy, vcorr) {
  f <- gpp_path(country, year, start_doy)
  if (!file.exists(f)) return(NA_real_)
  r <- tryCatch(rast(f), error = function(e) NULL); if (is.null(r)) return(NA_real_)
  r <- crop(r, vcorr); r[r < 0] <- NA
  as.numeric(terra::extract(r, vcorr, fun = mean, na.rm = TRUE, ID = FALSE)[1, 1])
}

# ---- Eq 8 : SIF–GPP Pearson correlation (8-day matched) ----------------------
# Aggregates the daily SIF anomaly (event_vs_climatology.csv) to each 8-day GPP
# composite period, pairs with the GPP anomaly (event minus clim-year mean),
# then Pearson + Spearman across composites spanning the BER record.
eq8_sif_gpp <- function(evdir, corridor, entry, event_year, clim_years,
                        country, metdir) {
  evcsv <- file.path(evdir, "event_vs_climatology.csv")
  if (!file.exists(evcsv)) { message("[eq8] no event_vs_climatology.csv"); return(NULL) }
  # GPP-absent guard: if this country has no GPP tiles on disk, defer Eq 8 cleanly
  # (the SIF analysis is fully independent of GPP). Slot GPP in later via re-run.
  gpp_dir <- GPP_DIR[[country]]
  if (is.null(gpp_dir) || !dir.exists(file.path(GPP_ROOT, gpp_dir))) {
    message(sprintf("[eq8] GPP not available for %s — validation deferred", country))
    return(list(deferred = TRUE))
  }
  ev <- read.csv(evcsv); ev$date <- as.Date(ev$date)
  vcorr <- vect(st_union(corridor))

  ev$doy   <- as.integer(format(ev$date, "%j"))
  ev$cstart<- gpp_start_doy(ev$doy)
  # SIF anomaly aggregated to composite period
  agg <- aggregate(sif_anom ~ cstart, data = ev[is.finite(ev$sif_anom), ],
                   FUN = mean)
  names(agg)[2] <- "dSIF"

  # GPP anomaly per composite: event-year minus mean(clim years)
  rows <- lapply(agg$cstart, function(cs) {
    g_ev <- gpp_composite_mean(country, event_year, cs, vcorr)
    g_cl <- mean(sapply(clim_years, function(y) gpp_composite_mean(country, y, cs, vcorr)),
                 na.rm = TRUE)
    data.frame(cstart = cs, gpp_ev = g_ev, gpp_clim = g_cl, dGPP = g_ev - g_cl)
  })
  g <- do.call(rbind, rows)
  d <- merge(agg, g, by = "cstart")
  d <- d[is.finite(d$dSIF) & is.finite(d$dGPP), ]
  write.csv(d, file.path(metdir, "eq8_sif_gpp_pairs.csv"), row.names = FALSE)
  if (nrow(d) < 3) { message("[eq8] <3 paired composites; corr not computed"); return(d) }

  pe <- cor.test(d$dSIF, d$dGPP, method = "pearson")
  sp <- suppressWarnings(cor.test(d$dSIF, d$dGPP, method = "spearman"))
  res <- data.frame(n_pairs = nrow(d),
                    pearson_r = round(unname(pe$estimate), 3),
                    pearson_p = signif(pe$p.value, 3),
                    spearman_rho = round(unname(sp$estimate), 3),
                    spearman_p = signif(sp$p.value, 3))
  write.csv(res, file.path(metdir, "eq8_sif_gpp_correlation.csv"), row.names = FALSE)

  png(file.path(metdir, "eq8_sif_gpp_scatter.png"), width = 1500, height = 1300, res = 200)
  par(mar = c(4.5, 4.8, 3.2, 1.2))
  plot(d$dGPP, d$dSIF, pch = 19, col = "#1a6fc4", cex = 1.4,
       xlab = expression(Delta*"GPP  (event - climatology, gC m"^-2*" d"^-1*")"),
       ylab = expression(Delta*"SIF  (event - climatology)"),
       main = sprintf("Eq 8  SIF-GPP agreement  (r = %.2f, p = %.3f, n = %d)",
                      res$pearson_r, res$pearson_p, res$n_pairs))
  abline(lm(dSIF ~ dGPP, data = d), col = "grey30", lwd = 2, lty = 2)
  abline(h = 0, v = 0, col = "grey80")
  dev.off()
  message(sprintf("[eq8] Pearson r=%.2f p=%.3f (n=%d composites)",
                  res$pearson_r, res$pearson_p, res$n_pairs))
  list(pairs = d, result = res)
}

# ---- Eq 6 / Eq 7 : %-change and recovery ratios (de-meaned, clim-anchored) ---
# Naive (draft) version uses the OBSERVED pre-event baseline -> artifact when the
# baseline is depressed. Corrected version anchors to the climatological baseline
# level and uses de-meaned anomalies, so apparent "enhancement" cannot be
# manufactured by a low baseline. Both are reported side by side for honesty.
pct_and_recovery <- function(evdir, corridor, entry, event_year, clim_years,
                             metdir, baseline_win = c(-14, -8)) {
  evcsv <- file.path(evdir, "event_vs_climatology.csv")
  ev <- read.csv(evcsv); ev$date <- as.Date(ev$date)
  bsel <- ev$rel >= baseline_win[1] & ev$rel <= baseline_win[2]
  clim_baseline <- mean(ev$sif.clim[bsel], na.rm = TRUE)   # true seasonal level
  obs_baseline  <- mean(ev$sif[bsel],      na.rm = TRUE)   # depressed observed level
  offset        <- mean(ev$sif_anom[bsel], na.rm = TRUE)   # year offset (de-mean)

  # Eq 6 : per-window % change, naive vs corrected
  wtab <- do.call(rbind, lapply(names(WINDOWS), function(w) {
    s <- ev[ev$window == w & !is.na(ev$window), ]
    if (!nrow(s)) return(NULL)
    obs_w  <- mean(s$sif, na.rm = TRUE)
    anom_w <- mean(s$sif_anom, na.rm = TRUE)
    data.frame(window = w, n_days = sum(is.finite(s$sif)),
               pct_naive    = round(100 * (obs_w - obs_baseline) / obs_baseline, 1),
               pct_corrected = round(100 * (anom_w - offset) / clim_baseline, 1))
  }))
  write.csv(wtab, file.path(metdir, "eq6_pct_change.csv"), row.names = FALSE)

  # Eq 7 : recovery ratios. early = +1..+10, late = +45..+60. Freshly extracted
  # because the standard BER grid stops at +27.
  bb <- st_bbox(corridor); corr <- st_union(corridor)
  win_mean <- function(rels, years) {
    pts <- collect_soundings(rels, years, entry, bb, corr)
    if (is.null(pts) || !nrow(pts)) return(c(n = 0, sif = NA))
    c(n = nrow(pts), sif = mean(pts$sif, na.rm = TRUE))
  }
  rr_one <- function(lab, rels) {
    e <- win_mean(rels, event_year); c <- win_mean(rels, clim_years)
    # corrected level removes the year offset before ratioing to clim baseline
    corr_level <- if (is.finite(e["sif"])) e["sif"] - offset else NA
    data.frame(phase = lab, rel_lo = rels[1], rel_hi = rels[length(rels)],
               n_event_obs = unname(e["n"]),
               # RR vs PRE-EVENT baseline (methods Eq 7 literal) — seasonally confounded
               RR_naive     = round(unname(e["sif"]) / obs_baseline, 3),
               RR_corrected = round(unname(corr_level) / clim_baseline, 3),
               # RR vs SAME-DATE climatology — phenology-removed "recovery to normal"
               RR_vs_clim   = round(unname(e["sif"]) / unname(c["sif"]), 3))
  }
  rr <- rbind(rr_one("early_recovery", 1:10),
              rr_one("late_recovery", 45:60))
  write.csv(rr, file.path(metdir, "eq7_recovery_ratios.csv"), row.names = FALSE)

  list(clim_baseline = clim_baseline, obs_baseline = obs_baseline,
       offset = offset, pct = wtab, recovery = rr)
}

# ---- §3.7 : 5-class functional response + Shannon entropy --------------------
# Classifies the per-pixel de-meaned acute SIF anomaly (anomd_sif_acute.tif).
# Symmetric thresholds RELATIVE TO the climatological baseline level: +/-5% =
# negligible band, +/-20% = strong cut (the methods' "20% below baseline" rule).
# (baseline_sd is retained in the signature for reference but no longer drives a
#  CI band — the spatial scatter is canopy heterogeneity, not measurement noise.)
classify_response <- function(evdir, metdir, clim_baseline, baseline_sd,
                              event_label, zim, corridor, seg) {
  tif <- file.path(evdir, "spatial_maps", "anomd_sif_acute.tif")
  if (!file.exists(tif)) { message("[class] no acute tif"); return(NULL) }
  a  <- rast(tif)
  neg <- 0.05 * clim_baseline   # +/-5%  negligible band
  big <- 0.20 * clim_baseline   # +/-20% strong cut
  cls <- a
  v <- values(a); out <- rep(NA_integer_, length(v)); fin <- is.finite(v)
  out[fin & v <= -big]                <- 1  # strong suppression  (>20% below)
  out[fin & v > -big & v <= -neg]     <- 2  # moderate suppression (5-20% below)
  out[fin & v > -neg & v <  neg]      <- 3  # negligible          (within +/-5%)
  out[fin & v >= neg & v < big]       <- 4  # moderate enhancement (5-20% above)
  out[fin & v >= big]                 <- 5  # strong enhancement   (>20% above)
  values(cls) <- out
  cnames <- c("Strong suppression","Moderate suppression","Negligible",
              "Moderate enhancement","Strong enhancement")
  levels(cls) <- data.frame(value = 1:5, class = cnames)
  writeRaster(cls, file.path(metdir, "response_classes_acute.tif"), overwrite = TRUE)

  props <- table(factor(out[fin], levels = 1:5)) / sum(fin)
  H <- -sum(ifelse(props > 0, props * log(props), 0))           # Shannon entropy
  ctab <- data.frame(class = cnames,
                     n_cells = as.integer(table(factor(out[fin], levels = 1:5))),
                     proportion = round(as.numeric(props), 3))
  write.csv(ctab, file.path(metdir, "response_class_summary.csv"), row.names = FALSE)
  write.csv(data.frame(shannon_entropy = round(H, 3),
                       max_entropy = round(log(5), 3),
                       evenness = round(H / log(5), 3)),
            file.path(metdir, "shannon_entropy.csv"), row.names = FALSE)

  cmap <- c("#b2182b","#ef8a62","#f7f7f7","#a6d96a","#1a9850")
  png(file.path(metdir, sprintf("%s_response_classes_acute.png", event_label)),
      width = 1500, height = 1500, res = 200)
  par(mar = c(1,1,3.5,1))
  plot(st_geometry(zim), col = "grey94", border = "grey45", axes = FALSE,
       main = sprintf("Acute SIF response classes  (Shannon H = %.2f / %.2f)", H, log(5)))
  plot(st_geometry(st_union(corridor)), col = "white", border = "steelblue", add = TRUE)
  plot(cls, col = cmap, add = TRUE, legend = FALSE)
  plot(st_geometry(st_union(corridor)), border = "steelblue", add = TRUE)
  if (!is.null(seg)) plot(st_geometry(seg), col = "black", lwd = 3, add = TRUE)
  legend("bottomleft", legend = cnames, fill = cmap, bty = "n", cex = 0.8, inset = 0.02)
  dev.off()
  list(summary = ctab, entropy = H)
}

message("[original_metrics] loaded: coverage_dilution, eq8_sif_gpp, ",
        "pct_and_recovery, classify_response")
