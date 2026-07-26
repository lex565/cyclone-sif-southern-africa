# =============================================================================
# IDAI_2019/05_original_metrics.R
# Re-implements the manuscript's ORIGINAL Section-3 metrics for Cyclone Idai,
# ADDITIVELY: reads existing corridor + event_vs_climatology + de-meaned tifs,
# writes only into  Sample Result/IDAI_2019/metrics/ . Nothing else is touched.
#
#   Eq 1/2  coverage fraction & dilution factor
#   Eq 6    %-change vs baseline (naive vs corrected)
#   Eq 7    early (+1..+10 d) & late (+45..+60 d) recovery ratios
#   Eq 8    SIF-GPP Pearson via PML-V2 8-day GPP
#   §3.7    5-class response + Shannon entropy
#
# Run in RStudio (source) or:  Rscript IDAI_2019/05_original_metrics.R
# =============================================================================
this_dir <- Sys.getenv("CYCLONE_SIF_CODE", Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"))
source(file.path(this_dir, "config.R"))
source(file.path(this_dir, "functions.R"))
source(file.path(this_dir, "spatial_engine.R"))
source(file.path(this_dir, "original_metrics.R"))

## ---- event parameters ----
EV_LABEL   <- "IDAI_2019"
EV_ENTRY   <- as.Date("2019-03-15")
EV_YEAR    <- 2019
COUNTRY    <- "Zimbabwe"
EV_DIR     <- file.path(RESULTS_ROOT, EV_LABEL)
clim_years <- setdiff(SIF_YEARS, EV_YEAR)
metdir     <- file.path(EV_DIR, "metrics"); dir.create(metdir, showWarnings = FALSE, recursive = TRUE)

## ---- geometry ----
corridor <- st_read(file.path(EV_DIR, "corridor_zim.gpkg"), quiet = TRUE) |> st_union()
zim <- st_union(st_make_valid(st_read(file.path(ECO_BYCOUNTRY,
        "Ecoregions2017_Zimbabwe.shp"), quiet = TRUE)))
seg_path <- file.path(RESULTS_ROOT, "idai2019_zim_segment.gpkg")
seg <- if (file.exists(seg_path)) st_read(seg_path, quiet = TRUE) else NULL

cat("=== ORIGINAL METRICS:", EV_LABEL, "===\n")

## ---- Eq 1 / Eq 2 : coverage fraction & dilution factor ----
cov <- coverage_dilution(corridor, zim)
write.csv(cov, file.path(metdir, "eq1_eq2_coverage_dilution.csv"), row.names = FALSE)
cat("\n[Eq1/2] coverage & dilution:\n"); print(cov, row.names = FALSE)

## ---- Eq 6 / Eq 7 : %-change & recovery ratios ----
pr <- pct_and_recovery(EV_DIR, corridor, EV_ENTRY, EV_YEAR, clim_years, metdir,
                       baseline_win = WINDOWS$baseline)
cat(sprintf("\n[baseline] clim level=%.3f  observed=%.3f  year-offset=%.3f\n",
            pr$clim_baseline, pr$obs_baseline, pr$offset))
cat("\n[Eq6] %-change per window (naive vs corrected):\n"); print(pr$pct, row.names = FALSE)
cat("\n[Eq7] recovery ratios:\n"); print(pr$recovery, row.names = FALSE)

## ---- Eq 8 : SIF-GPP correlation (PML-V2 8-day) ----
cat("\n[Eq8] extracting PML-V2 8-day GPP and correlating...\n")
e8 <- eq8_sif_gpp(EV_DIR, corridor, EV_ENTRY, EV_YEAR, clim_years, COUNTRY, metdir)
if (!is.null(e8$result)) { cat("[Eq8] result:\n"); print(e8$result, row.names = FALSE) }

## ---- §3.7 : functional response classification + Shannon entropy ----
## baseline per-pixel variability from the de-meaned baseline grid
btif <- file.path(EV_DIR, "spatial_maps", "anomd_sif_baseline.tif")
baseline_sd <- if (file.exists(btif)) {
  v <- values(rast(btif)); sd(v[is.finite(v)]) } else 0.05
cat(sprintf("\n[§3.7] baseline per-pixel SD = %.4f  (CI band = +/- %.4f)\n",
            baseline_sd, 1.96*baseline_sd))
cl <- classify_response(EV_DIR, metdir, pr$clim_baseline, baseline_sd,
                        EV_LABEL, zim, corridor, seg)
if (!is.null(cl)) { cat("[§3.7] class summary:\n"); print(cl$summary, row.names = FALSE)
  cat(sprintf("[§3.7] Shannon entropy H = %.3f (max %.3f)\n", cl$entropy, log(5))) }

## ---- write metrics markdown ----
md <- file.path(EV_DIR, "IDAI_2019_original_metrics.md")
L <- c()
add <- function(...) L[[length(L)+1]] <<- sprintf(...)
add("# Cyclone Idai — original manuscript metrics (Section 3)")
add("")
add("Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. The")
add("triplet / de-meaning / attribution outputs are unchanged.")
add("")
add("## Eq 1 / Eq 2 — Coverage fraction & dilution factor")
add("| A_footprint (km2) | A_national (km2) | CF | DF |")
add("|---|---|---|---|")
add("| %s | %s | %.3f | %.1f |", format(cov$A_footprint_km2, big.mark=","),
    format(cov$A_national_km2, big.mark=","), cov$CF, cov$DF)
add("")
add("Only %.0f%% of Zimbabwe lies inside the 200 km storm footprint; a national mean would dilute the signal ~%.0fx (DF).", 100*cov$CF, cov$DF)
add("")
add("## Eq 6 — %% change vs baseline (naive vs corrected)")
add("Naive uses the depressed *observed* baseline (manufactures enhancement); corrected anchors to the climatological baseline level (%.3f) on de-meaned anomalies.", pr$clim_baseline)
add("| Window | n days | %% naive | %% corrected |")
add("|---|---|---|---|")
for (i in seq_len(nrow(pr$pct))) add("| %s | %d | %+.1f | %+.1f |",
    pr$pct$window[i], pr$pct$n_days[i], pr$pct$pct_naive[i], pr$pct$pct_corrected[i])
add("")
add("## Eq 7 — Recovery ratios")
add("RR = window level / reference level. **RR_naive/corrected** divide by the *pre-event baseline* (methods Eq 7 literal) — these are confounded by seasonal phenology for the late window (mid-May senescence vs March baseline). **RR_vs_clim** divides by the *same-date climatology*, removing phenology: it answers \"did SIF return to normal *for that time of year*\" (=1 means fully recovered to seasonal normal).")
add("| Phase | rel days | n obs | RR naive | RR corrected | RR vs climatology |")
add("|---|---|---|---|---|---|")
for (i in seq_len(nrow(pr$recovery))) add("| %s | %+d..%+d | %d | %s | %s | %s |",
    pr$recovery$phase[i], pr$recovery$rel_lo[i], pr$recovery$rel_hi[i],
    pr$recovery$n_event_obs[i],
    ifelse(is.na(pr$recovery$RR_naive[i]),"NA",sprintf("%.3f",pr$recovery$RR_naive[i])),
    ifelse(is.na(pr$recovery$RR_corrected[i]),"NA",sprintf("%.3f",pr$recovery$RR_corrected[i])),
    ifelse(is.na(pr$recovery$RR_vs_clim[i]),"NA",sprintf("%.3f",pr$recovery$RR_vs_clim[i])))
add("")
if (!is.null(e8$result)) {
  add("## Eq 8 — SIF-GPP agreement (PML-V2 8-day)")
  add("SIF anomaly aggregated to the 8-day GPP composite grid, paired with GPP anomaly (event - climatology).")
  add("- Pearson r = **%.2f** (p = %.3f), Spearman rho = %.2f (p = %.3f), n = %d composites.",
      e8$result$pearson_r, e8$result$pearson_p, e8$result$spearman_rho,
      e8$result$spearman_p, e8$result$n_pairs)
  add("- Figure: `metrics/eq8_sif_gpp_scatter.png`")
  add("")
}
if (!is.null(cl)) {
  add("## §3.7 — Functional response classification (acute)")
  add("| Class | n cells | proportion |")
  add("|---|---|---|")
  for (i in seq_len(nrow(cl$summary))) add("| %s | %d | %.3f |",
      cl$summary$class[i], cl$summary$n_cells[i], cl$summary$proportion[i])
  add("- Shannon entropy H = **%.2f** (max %.2f; evenness %.2f) — within-corridor response heterogeneity.",
      cl$entropy, log(5), cl$entropy/log(5))
  add("- Figure: `metrics/%s_response_classes_acute.png`", EV_LABEL)
  add("")
}
writeLines(unlist(L), md)
cat("\nwrote metrics markdown:", md, "\n")
cat("DONE — original metrics ->", metdir, "\n")
