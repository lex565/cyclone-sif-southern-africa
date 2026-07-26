# =============================================================================
# 00_shared/run_metrics_for_event.R
# Event-parameterized ORIGINAL-METRICS runner (Eq 1/2/6/7/8 + §3.7), additive.
# Reads existing corridor + event_vs_climatology + de-meaned tifs, writes only
# into <EV_DIR>/metrics/ and an <EV_LABEL>_original_metrics.md. NA-safe for
# blacked-out events (empty windows render honest "NA" rows).
#
# REQUIRED before sourcing:
#   EV_LABEL  e.g. "CHALANE_2020"
#   EV_ENTRY  as.Date("2020-12-30")
#   EV_YEAR   2020
#   COUNTRY   "Zimbabwe"            (selects GPP folder)
#   EV_DIR    file.path(RESULTS_ROOT, EV_LABEL)
#   EV_SEG    path to in-country track segment gpkg, or NULL
# =============================================================================
sd_ <- Sys.getenv("CYCLONE_SIF_CODE", Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"))
source(file.path(sd_, "config.R"))
source(file.path(sd_, "functions.R"))
source(file.path(sd_, "spatial_engine.R"))
source(file.path(sd_, "original_metrics.R"))

if (!exists("EV_LABEL")) stop("Set EV_LABEL, EV_ENTRY, EV_YEAR, COUNTRY, EV_DIR, EV_SEG first.")
if (!exists("COUNTRY")) COUNTRY <- "Zimbabwe"
clim_years <- setdiff(SIF_YEARS, EV_YEAR)
metdir <- file.path(EV_DIR, "metrics"); dir.create(metdir, showWarnings = FALSE, recursive = TRUE)
fmt <- function(x, d = 1) ifelse(is.finite(x), sprintf(paste0("%.", d, "f"), x), "NA")

cat(sprintf("\n=================  ORIGINAL METRICS: %s  =================\n", EV_LABEL))
cat(sprintf("entry %s | event yr %d | clim %s | country %s\n",
            format(EV_ENTRY), EV_YEAR, paste(clim_years, collapse=","), COUNTRY))

## ---- geometry ----
cat("[1/5] loading geometry...\n"); flush.console()
CITIES <- COUNTRY_CITIES[[COUNTRY]]
corridor <- st_read(corridor_path(EV_DIR), quiet = TRUE) |> st_union()
zim <- st_union(st_make_valid(st_read(country_shp(COUNTRY), quiet = TRUE)))  # country polygon (any country)
seg <- if (exists("EV_SEG") && !is.null(EV_SEG) && file.exists(EV_SEG))
         st_read(EV_SEG, quiet = TRUE) else NULL

## ---- Eq 1 / Eq 2 ----
cat("[2/5] Eq 1/2  coverage fraction & dilution factor...\n"); flush.console()
cov <- coverage_dilution(corridor, zim)
write.csv(cov, file.path(metdir, "eq1_eq2_coverage_dilution.csv"), row.names = FALSE)
print(cov, row.names = FALSE)

## ---- Eq 6 / Eq 7 ----
cat("[3/5] Eq 6/7  %-change & recovery ratios (extracting recovery windows)...\n"); flush.console()
pr <- pct_and_recovery(EV_DIR, corridor, EV_ENTRY, EV_YEAR, clim_years, metdir,
                       baseline_win = WINDOWS$baseline)
cat(sprintf("  baseline: clim=%.3f observed=%.3f offset=%.3f\n",
            pr$clim_baseline, pr$obs_baseline, pr$offset))
print(pr$pct, row.names = FALSE); print(pr$recovery, row.names = FALSE)

## ---- Eq 8 ----
cat("[4/5] Eq 8  SIF-GPP correlation (PML-V2 8-day GPP)...\n"); flush.console()
e8 <- tryCatch(eq8_sif_gpp(EV_DIR, corridor, EV_ENTRY, EV_YEAR, clim_years, COUNTRY, metdir),
               error = function(e) { message("  [eq8] ", conditionMessage(e)); NULL })
if (!is.null(e8$result)) print(e8$result, row.names = FALSE) else if (isTRUE(e8$deferred)) cat("  [eq8] GPP not available — validation deferred\n") else cat("  [eq8] not computable (sparse/empty SIF)\n")

## ---- §3.7 ----
cat("[5/5] §3.7  response classification + Shannon entropy...\n"); flush.console()
btif <- file.path(EV_DIR, "spatial_maps", "anomd_sif_baseline.tif")
baseline_sd <- if (file.exists(btif)) { v <- values(rast(btif)); sd(v[is.finite(v)]) } else NA
cl <- if (is.finite(pr$clim_baseline)) {
        classify_response(EV_DIR, metdir, pr$clim_baseline, baseline_sd, EV_LABEL, zim, corridor, seg)
      } else NULL
if (!is.null(cl)) { print(cl$summary, row.names = FALSE)
  cat(sprintf("  Shannon H = %.3f (max %.3f)\n", cl$entropy, log(5))) } else
  cat("  [class] skipped (no acute grid — blacked-out window)\n")

## ---- markdown ----
ev_name <- if (exists("EV_NAME")) EV_NAME else tools::toTitleCase(tolower(sub("_.*$", "", EV_LABEL)))
EVENT_TITLE <- sprintf("Cyclone %s (%s)", ev_name, format(EV_ENTRY, "%b %Y"))
md <- file.path(EV_DIR, sprintf("%s_original_metrics.md", EV_LABEL))
L <- c(); add <- function(...) L[[length(L)+1]] <<- sprintf(...)
add("# %s — original manuscript metrics (Section 3)", EVENT_TITLE)
add("")
add("Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. Triplet / de-meaning / attribution outputs are unchanged.")
add("")
add("> **What \"de-meaning\" means (plain language).** The baseline (pre-storm) window measures how far the event year already sat from a normal year. De-meaning subtracts that constant offset from every window, so the baseline reads 0 and each window measures only the cyclone-attributable departure, not the background year bias. Full note: `../METHODS_NOTES.md`.")
add("")
add("## Eq 1 / Eq 2 — Coverage fraction & dilution factor")
add("| A_footprint (km2) | A_national (km2) | CF | DF |")
add("|---|---|---|---|")
add("| %s | %s | %.3f | %.1f |", format(cov$A_footprint_km2, big.mark=","),
    format(cov$A_national_km2, big.mark=","), cov$CF, cov$DF)
add("")
add("Only %.0f%% of %s lies inside the 200 km storm footprint; a national mean would dilute the signal ~%.0fx (DF).", 100*cov$CF, COUNTRY, cov$DF)
add("")
add("## Eq 6 — %% change vs baseline (naive vs corrected)")
add("Naive uses the depressed *observed* baseline; corrected anchors to the climatological baseline level (%s) on de-meaned anomalies.", fmt(pr$clim_baseline,3))
add("| Window | n days | %% naive | %% corrected |")
add("|---|---|---|---|")
for (i in seq_len(nrow(pr$pct))) add("| %s | %d | %s | %s |",
    pr$pct$window[i], pr$pct$n_days[i], fmt(pr$pct$pct_naive[i]), fmt(pr$pct$pct_corrected[i]))
add("")
add("## Eq 7 — Recovery ratios")
add("**RR_naive/corrected** divide by the *pre-event baseline* (Eq 7 literal; seasonally confounded for the late window). **RR_vs_clim** divides by the *same-date climatology* — \"recovered to normal for the season\" (=1 means full seasonal recovery).")
add("| Phase | rel days | n obs | RR naive | RR corrected | RR vs climatology |")
add("|---|---|---|---|---|---|")
for (i in seq_len(nrow(pr$recovery))) add("| %s | %+d..%+d | %d | %s | %s | %s |",
    pr$recovery$phase[i], pr$recovery$rel_lo[i], pr$recovery$rel_hi[i], pr$recovery$n_event_obs[i],
    fmt(pr$recovery$RR_naive[i],3), fmt(pr$recovery$RR_corrected[i],3), fmt(pr$recovery$RR_vs_clim[i],3))
add("")
if (!is.null(e8$result)) {
  add("## Eq 8 — SIF-GPP agreement (PML-V2 8-day)")
  add("- Pearson r = **%.2f** (p = %.3f), Spearman rho = %.2f (p = %.3f), n = %d composites.",
      e8$result$pearson_r, e8$result$pearson_p, e8$result$spearman_rho, e8$result$spearman_p, e8$result$n_pairs)
  if (e8$result$n_pairs < 5)
    add("- **Caveat: n = %d is too few to interpret** — reported for completeness only; not a usable validation (monsoon blackout limits paired composites).", e8$result$n_pairs)
  add("- Figure: `metrics/eq8_sif_gpp_scatter.png`")
} else if (isTRUE(e8$deferred)) {
  add("## Eq 8 — SIF-GPP agreement (PML-V2 8-day)")
  add("- **Validation deferred — GPP not yet downloaded for %s.** The SIF disruption analysis (Eq 1/2/5/6/7, §3.7, attribution Eq 9) is complete and fully independent of GPP. Eq 8 will be added once the PML-V2 tiles arrive, as an additive re-run with no SIF recomputation.", COUNTRY)
} else { add("## Eq 8 — SIF-GPP agreement"); add("- Not computable: too few paired 8-day composites with valid SIF (monsoon blackout).") }
add("")
if (!is.null(cl)) {
  add("## §3.7 — Functional response classification (acute)")
  add("| Class | n cells | proportion |"); add("|---|---|---|")
  for (i in seq_len(nrow(cl$summary))) add("| %s | %d | %.3f |",
      cl$summary$class[i], cl$summary$n_cells[i], cl$summary$proportion[i])
  add("- Shannon entropy H = **%.2f** (max %.2f; evenness %.2f).",
      cl$entropy, log(5), cl$entropy/log(5))
  add("- Figure: `metrics/%s_response_classes_acute.png`", EV_LABEL)
} else { add("## §3.7 — Functional response classification"); add("- Skipped: acute window has no usable per-pixel grid (blacked out).") }
add("")
writeLines(unlist(L), md)
cat("\nwrote:", md, "\nDONE", EV_LABEL, "->", metdir, "\n")
