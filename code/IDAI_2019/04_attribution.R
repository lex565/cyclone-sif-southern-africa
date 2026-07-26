# =============================================================================
# IDAI_2019 / 04_attribution.R  —  SPATIAL attribution for Idai-Zimbabwe.
# Links per-pixel ACUTE SIF disruption to drivers at the SAME 0.1deg grid:
#   driver 1: WIND STRESS  — inverse distance to in-country track (IBTrACS local
#             wind attenuates with distance), = 1/(1 + d_km/50).
#   driver 2: ANTECEDENT MOISTURE — CHIRPS 60-day pre-event PRCPTOT per cell.
#   driver 3: ACUTE RAINFALL — CHIRPS acute-window PRCPTOT per cell (waterlogging).
# Model: dSIF_acute ~ wind*ante_moist + acute_rain, OLS + 5000-iter bootstrap CIs.
# RUN IN RSTUDIO: source this file.
# OUTPUTS -> RESULTS_ROOT/IDAI_2019/attribution/
# =============================================================================
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "functions.R"))

EVENT_YEAR <- 2019; ENTRY <- as.Date("2019-03-15")
evdir  <- file.path(RESULTS_ROOT, "IDAI_2019")
outdir <- file.path(evdir, "attribution"); dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

corridor <- st_read(file.path(evdir, "corridor_zim.gpkg"), quiet = TRUE) |> st_union()
vcorr <- vect(corridor); bb <- st_bbox(corridor)
seg <- st_read(file.path(RESULTS_ROOT, "idai2019_zim_segment.gpkg"), quiet = TRUE)

tmpl <- rast(xmin = floor(bb["xmin"]*10)/10, xmax = ceiling(bb["xmax"]*10)/10,
             ymin = floor(bb["ymin"]*10)/10, ymax = ceiling(bb["ymax"]*10)/10,
             resolution = GRID_DEG, crs = "EPSG:4326")

## ---- response: de-meaned acute SIF anomaly per cell ----
clim_years   <- setdiff(SIF_YEARS, EVENT_YEAR)
acute_rel    <- WINDOWS$acute[1]:WINDOWS$acute[2]
baseline_rel <- WINDOWS$baseline[1]:WINDOWS$baseline[2]
gmean <- function(rels, years, field) {
  pts <- collect_soundings(rels, years, ENTRY, bb, corridor)
  if (is.null(pts)) return(NULL)
  grid_field(pts, field, tmpl, vcorr)$mean
}
ev_acute <- gmean(acute_rel, EVENT_YEAR, "sif")
cl_acute <- gmean(acute_rel, clim_years, "sif")
ev_base  <- gmean(baseline_rel, EVENT_YEAR, "sif")
cl_base  <- gmean(baseline_rel, clim_years, "sif")
anom_acute <- ev_acute - cl_acute
offset <- { v <- values(ev_base - cl_base); mean(v[is.finite(v)], na.rm = TRUE) }
dSIF <- anom_acute - offset
names(dSIF) <- "dSIF"

## ---- driver 1: wind-stress proxy = inverse distance to in-country track ----
dist_km <- terra::distance(tmpl, vect(seg)) / 1000
wind_stress <- mask(1 / (1 + dist_km / 50), vcorr)
names(wind_stress) <- "wind_stress"

## ---- drivers 2 & 3: CHIRPS antecedent (60d) + acute-window rainfall per cell ----
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
ante_dates  <- seq(ENTRY - 15 - 59, ENTRY - 15, by = "day")
acute_dates <- seq(ENTRY + WINDOWS$acute[1], ENTRY + WINDOWS$acute[2], by = "day")
ante_moist <- chirps_window_grid(ante_dates);  names(ante_moist) <- "ante_moist"
acute_rain <- chirps_window_grid(acute_dates); names(acute_rain) <- "acute_rain"

## ---- assemble pixel table ----
stk <- c(dSIF, wind_stress, ante_moist, acute_rain)
names(stk) <- c("dSIF","wind_stress","ante_moist","acute_rain")
df <- as.data.frame(stk, na.rm = TRUE)
cat("Attribution pixels (complete cases):", nrow(df), "\n")
write.csv(df, file.path(outdir, "attribution_pixels.csv"), row.names = FALSE)

if (nrow(df) >= 20) {
  dsc <- df
  for (v in c("wind_stress","ante_moist","acute_rain"))
    dsc[[v]] <- as.numeric(scale(df[[v]]))
  m <- lm(dSIF ~ wind_stress * ante_moist + acute_rain, data = dsc)
  cat("\n=== OLS attribution (standardized predictors) ===\n"); print(summary(m))

  set.seed(1)
  B <- 5000; coefs <- matrix(NA, B, length(coef(m)))
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
  write.csv(out, file.path(outdir, "attribution_coefficients.csv"), row.names = FALSE)
  cat("\n=== Bootstrap 95% CIs ===\n"); print(out, row.names = FALSE)
  cat("\nR-squared:", round(summary(m)$r.squared, 3),
      "| adj:", round(summary(m)$adj.r.squared, 3), "\n")

  png(file.path(outdir, "IDAI_attribution_scatter.png"), width = 1600, height = 520, res = 150)
  par(mfrow = c(1, 3), mar = c(4, 4, 3, 1), oma = c(0, 0, 2, 0))
  for (v in c("wind_stress","ante_moist","acute_rain")) {
    plot(df[[v]], df$dSIF, pch = 19, col = "#1a6fc488", cex = .6,
         xlab = v, ylab = "de-meaned acute dSIF",
         main = sprintf("dSIF vs %s (r=%.2f)", v, cor(df[[v]], df$dSIF)))
    abline(lm(df$dSIF ~ df[[v]]), col = "red", lwd = 2)
  }
  mtext("IDAI 2019 — per-pixel SIF disruption attribution", outer = TRUE, font = 2)
  dev.off()
  cat("wrote attribution scatter + coefficient CSV ->", outdir, "\n")

  png(file.path(outdir, "IDAI_driver_maps.png"), width = 1700, height = 520, res = 150)
  par(mfrow = c(1, 4), mar = c(2, 2, 3, 4))
  plot(dSIF, main = "acute dSIF (response)", col = DIV_PAL(20)); plot(st_geometry(seg), add = TRUE, lwd = 2)
  plot(wind_stress, main = "wind stress (1/dist)", col = hcl.colors(20, "Reds", rev = TRUE)); plot(st_geometry(seg), add = TRUE)
  plot(ante_moist, main = "antecedent 60d rain (mm)", col = hcl.colors(20, "Blues", rev = TRUE)); plot(st_geometry(seg), add = TRUE)
  plot(acute_rain, main = "acute rain (mm)", col = hcl.colors(20, "Blues", rev = TRUE)); plot(st_geometry(seg), add = TRUE)
  dev.off()
  cat("wrote driver maps.\n")
} else {
  cat("** Too few pixels for attribution (", nrow(df), ") **\n")
}
cat("DONE attribution ->", outdir, "\n")
