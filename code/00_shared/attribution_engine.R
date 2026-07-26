# =============================================================================
# 00_shared/attribution_engine.R  —  country-agnostic Eq 9 spatial attribution.
# Generalizes IDAI_2019/04_attribution.R. Links per-pixel ACUTE de-meaned SIF
# disruption to drivers on the same 0.1deg grid:
#   wind_stress  = 1 / (1 + d_km/50)      (inverse distance to in-country track)
#   ante_moist   = CHIRPS 60-day pre-baseline PRCPTOT per cell
#   acute_rain   = CHIRPS acute-window PRCPTOT per cell
# Model (methods Eq 9): dSIF ~ wind*ante_moist + acute_rain, OLS + 5000-boot CIs.
# Source config.R + functions.R first, then call run_attribution(...).
# =============================================================================

run_attribution <- function(country, event_year, entry, sid, evdir,
                             outdir = file.path(evdir, "attribution"),
                             min_pixels = 20) {
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  cat(sprintf("\n========== ATTRIBUTION : %s %d ==========\n", country, event_year))

  ## ---- corridor + in-country track segment -------------------------------
  cat("[1/6] corridor + segment ...\n")
  corridor <- st_read(corridor_path(evdir), quiet = TRUE) |> st_union()
  vcorr <- vect(corridor); bb <- st_bbox(corridor)
  segf <- file.path(evdir, "segment.gpkg")
  if (file.exists(segf)) {
    seg <- st_read(segf, quiet = TRUE)
  } else {
    cat("      segment.gpkg absent -> rebuilding track interception from IBTrACS\n")
    bc <- build_corridor(sid, country_shp(country))
    seg <- st_sf(geometry = st_geometry(bc$segment))
    st_write(seg, segf, quiet = TRUE, delete_dsn = TRUE)
  }

  tmpl <- rast(xmin = floor(bb["xmin"]*10)/10, xmax = ceiling(bb["xmax"]*10)/10,
               ymin = floor(bb["ymin"]*10)/10, ymax = ceiling(bb["ymax"]*10)/10,
               resolution = GRID_DEG, crs = "EPSG:4326")

  ## ---- response: de-meaned acute SIF anomaly per cell --------------------
  cat("[2/6] response grid (acute de-meaned dSIF) ...\n")
  clim_years   <- setdiff(SIF_YEARS, event_year)
  acute_rel    <- WINDOWS$acute[1]:WINDOWS$acute[2]
  baseline_rel <- WINDOWS$baseline[1]:WINDOWS$baseline[2]
  gmean <- function(rels, years, field) {
    pts <- collect_soundings(rels, years, entry, bb, corridor)
    if (is.null(pts)) return(NULL)
    grid_field(pts, field, tmpl, vcorr)$mean
  }
  ev_acute <- gmean(acute_rel, event_year, "sif")
  cl_acute <- gmean(acute_rel, clim_years, "sif")
  ev_base  <- gmean(baseline_rel, event_year, "sif")
  cl_base  <- gmean(baseline_rel, clim_years, "sif")
  if (is.null(ev_acute) || is.null(cl_acute)) {
    cat("** No acute SIF grid (blackout) — attribution not computable.\n")
    writeLines("Attribution not computable: acute window has no usable SIF grid (cloud blackout).",
               file.path(outdir, "ATTRIBUTION_NOT_COMPUTABLE.txt"))
    return(invisible(NULL))
  }
  anom_acute <- ev_acute - cl_acute
  offset <- if (!is.null(ev_base) && !is.null(cl_base)) {
    v <- values(ev_base - cl_base); mean(v[is.finite(v)], na.rm = TRUE)
  } else 0
  dSIF <- anom_acute - offset; names(dSIF) <- "dSIF"

  ## ---- driver 1: wind-stress proxy = inverse distance to track ------------
  cat("[3/6] wind-stress proxy ...\n")
  dist_km <- terra::distance(tmpl, vect(seg)) / 1000
  wind_stress <- mask(1 / (1 + dist_km / 50), vcorr); names(wind_stress) <- "wind_stress"

  ## ---- drivers 2 & 3: CHIRPS antecedent (60d) + acute-window rain ---------
  cat("[4/6] CHIRPS antecedent (60d) + acute rainfall grids ...\n")
  chirps_window_grid <- function(dates) {
    acc <- NULL
    for (i in seq_along(dates)) {
      d <- as.Date(dates[i])
      f <- file.path(CHIRPS_ROOT, format(d, "%Y"),
                     sprintf("chirps-v2.0.%s.tif.gz", format(d, "%Y.%m.%d")))
      if (!file.exists(f)) next
      r <- tryCatch(rast(paste0("/vsigzip/", f)), error = function(e) NULL)
      if (is.null(r)) next
      r <- crop(r, ext(tmpl) + 1); r[r < 0] <- NA
      r <- resample(r, tmpl, method = "bilinear")
      acc <- if (is.null(acc)) r else acc + r
    }
    if (is.null(acc)) return(NULL)
    mask(acc, vcorr)
  }
  ante_dates  <- seq(entry - 15 - 59, entry - 15, by = "day")
  acute_dates <- seq(entry + WINDOWS$acute[1], entry + WINDOWS$acute[2], by = "day")
  ante_moist <- chirps_window_grid(ante_dates);  names(ante_moist)  <- "ante_moist"
  acute_rain <- chirps_window_grid(acute_dates); names(acute_rain) <- "acute_rain"

  ## ---- assemble pixel table ----------------------------------------------
  cat("[5/6] assemble pixel table + OLS + bootstrap ...\n")
  stk <- c(dSIF, wind_stress, ante_moist, acute_rain)
  names(stk) <- c("dSIF","wind_stress","ante_moist","acute_rain")
  df <- as.data.frame(stk, na.rm = TRUE)
  cat("      complete-case pixels:", nrow(df), "\n")
  write.csv(df, file.path(outdir, "attribution_pixels.csv"), row.names = FALSE)

  if (nrow(df) < min_pixels) {
    cat(sprintf("** Too few pixels (%d < %d) — attribution NOT fitted.\n", nrow(df), min_pixels))
    writeLines(sprintf("Attribution not fitted: only %d complete-case acute pixels (< %d required).",
                       nrow(df), min_pixels),
               file.path(outdir, "ATTRIBUTION_TOO_FEW_PIXELS.txt"))
    return(invisible(list(n = nrow(df))))
  }

  dsc <- df
  for (v in c("wind_stress","ante_moist","acute_rain")) dsc[[v]] <- as.numeric(scale(df[[v]]))
  m <- lm(dSIF ~ wind_stress * ante_moist + acute_rain, data = dsc)
  cat("\n=== OLS (standardized predictors) ===\n"); print(summary(m))

  set.seed(1); B <- 5000; coefs <- matrix(NA, B, length(coef(m)))
  for (b in 1:B) {
    idx <- sample(nrow(dsc), replace = TRUE)
    cf <- tryCatch(coef(lm(dSIF ~ wind_stress * ante_moist + acute_rain, data = dsc[idx, ])),
                   error = function(e) rep(NA, length(coef(m))))
    coefs[b, ] <- cf
  }
  ci <- t(apply(coefs, 2, quantile, c(.025, .975), na.rm = TRUE))
  out <- data.frame(term = names(coef(m)), estimate = round(coef(m), 4),
                    lo = round(ci[, 1], 4), hi = round(ci[, 2], 4),
                    sig = ifelse(ci[, 1] * ci[, 2] > 0, "*", ""))
  out$R2 <- round(summary(m)$r.squared, 3); out$adjR2 <- round(summary(m)$adj.r.squared, 3)
  out$n_pix <- nrow(df)
  write.csv(out, file.path(outdir, "attribution_coefficients.csv"), row.names = FALSE)
  cat("\n=== Bootstrap 95% CIs ===\n"); print(out, row.names = FALSE)
  cat("\nR2:", out$R2[1], "| adj:", out$adjR2[1], "| n_pix:", nrow(df), "\n")

  ## ---- save driver grids (re-render figures later WITHOUT recompute) -------
  cat("[6/6] save driver grids + clean figures ...\n")
  tag <- toupper(gsub("[^A-Za-z0-9]","_", basename(evdir)))
  grids <- c(dSIF, wind_stress, ante_moist, acute_rain)
  names(grids) <- c("dSIF","wind_stress","ante_moist","acute_rain")
  writeRaster(grids, file.path(outdir, sprintf("%s_driver_grids.tif", tag)), overwrite = TRUE)

  ## ---- clean driver maps (serif, framed, per-panel legend) -----------------
  dpanel <- function(r, title, pal) {
    plot(r, col = pal, axes = FALSE, legend = TRUE, mar = c(0.5,0.5,2.4,3.4))
    plot(st_geometry(seg), add = TRUE, col = "black", lwd = 2)
    box(lwd = 1.4); title(main = title, font.main = 2, cex.main = 1.1, line = 0.5)
  }
  png(file.path(outdir, sprintf("%s_driver_maps.png", tag)), width = 1900, height = 620, res = 160)
  par(family = "serif", mfrow = c(1, 4), oma = c(0,0,2.2,0))
  dpanel(dSIF,        "Acute SIF anomaly (response)",      DIV_PAL(20))
  dpanel(wind_stress, "Wind exposure (proximity to track)", hcl.colors(20, "Reds",  rev = TRUE))
  dpanel(ante_moist,  "Antecedent 60-day rain (mm)",        hcl.colors(20, "Blues", rev = TRUE))
  dpanel(acute_rain,  "Storm-week rain (mm)",               hcl.colors(20, "Blues", rev = TRUE))
  mtext(sprintf("%s %d — attribution drivers (Eq 13, n = %d pixels)", country, event_year, nrow(df)),
        outer = TRUE, font = 2, cex = 1.25)
  dev.off()

  ## ---- clean scatter (serif, framed, regression + r) -----------------------
  png(file.path(outdir, sprintf("%s_attribution_scatter.png", tag)), width = 1850, height = 760, res = 160)
  par(family = "serif", mfrow = c(1, 3), mar = c(5.6,5.8,3.8,1.4), oma = c(0,0,2.8,0), cex.axis = 1.35)
  dlabs <- c(ante_moist = "Antecedent 60-day rainfall (mm)",
             acute_rain = "Storm-week rainfall (mm)",
             wind_stress = "Wind exposure (proximity to track)")
  for (v in names(dlabs)) {
    plot(df[[v]], df$dSIF, pch = 19, col = "#1a6fc466", cex = 0.95,
         xlab = "", ylab = "", cex.axis = 1.35)
    abline(h = 0, col = "grey75"); abline(lm(df$dSIF ~ df[[v]]), col = "#c0392b", lwd = 3)
    box(lwd = 1.6)
    title(xlab = dlabs[[v]], line = 3.6, cex.lab = 1.65)
    title(ylab = "Acute SIF anomaly (de-meaned)", line = 3.6, cex.lab = 1.65)
    title(main = sprintf("r = %.2f", cor(df[[v]], df$dSIF)), font.main = 2, cex.main = 1.75, line = 0.7)
  }
  mtext(sprintf("%s %d — vegetation response vs. drivers (Eq 13)", country, event_year),
        outer = TRUE, font = 2, cex = 1.7)
  dev.off()

  cat("DONE attribution ->", outdir, "\n")
  invisible(list(coef = out, n = nrow(df)))
}

message("[attribution_engine] loaded: run_attribution(country,event_year,entry,sid,evdir)")
