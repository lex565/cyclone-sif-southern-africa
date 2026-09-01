# Build the side-by-side comparison CSV: current pairing vs Zeng-consistent pairing.
sp  <- file.path(Sys.getenv("CYCLONE_SIF_OUT", "derived_data"), "robustness", "phif_variant_2026_08_04")
d   <- read.csv(file.path(sp, "phif_raw_vs_corr_ALL.csv"))
OUT <- file.path(Sys.getenv("CYCLONE_SIF_RESULTS", "results"), "PhiF_SIF_variant_comparison_2026-08-04.csv")

d <- d[order(-d$acute_days, d$country), ]
d$storm <- sub("_[0-9]{4}$", "", d$event)
d$yr    <- sub("^.*_", "", d$event)
f2 <- function(x) sprintf("%.2f", x)
f4 <- function(x) sprintf("%.4f", x)
yn <- function(a, b) ifelse(sign(a) != sign(b), "YES", "no")

## ---- banner: group headers sitting above the columns they span ----
grp <- c("EVENT IDENTIFICATION","","","","","",
         "CHECK",
         "SAME IN BOTH",
         "METHOD A: CURRENT PIPELINE (daylength-corrected SIF_Corr_743)","","",
         "METHOD B: ZENG-CONSISTENT (instantaneous SIF_743)","","",
         "DIFFERENCE (B minus A), percentage points","","","","",
         "DAYLENGTH FACTOR DIAGNOSTIC","","")

hdr <- c("Country","Storm","Event_year","Anchor_date_day0","Usable_acute_days","Acute_soundings",
         "Reproduces_published_series",
         "NIRvR_structure_change_pct",
         "A_SIF_change_pct","A_PhiF_residual_pct","A_PhiF_direct_pct",
         "B_SIF_change_pct","B_PhiF_residual_pct","B_PhiF_direct_pct",
         "Diff_SIF_pp","Diff_PhiF_residual_pp","Diff_PhiF_direct_pp",
         "SIF_sign_changed","PhiF_sign_changed",
         "DCF_baseline_window","DCF_acute_window","DCF_drift_pct")

body <- data.frame(
  d$country, d$storm, d$yr, d$entry, d$acute_days, d$acute_soundings,
  d$self_check,
  f2(d$dNIRvR),
  f2(d$dSIF_corr), f2(d$PhiF_resid_corr), f2(d$PhiF_direct_corr),
  f2(d$dSIF_raw),  f2(d$PhiF_resid_raw),  f2(d$PhiF_direct_raw),
  f2(d$dSIF_raw - d$dSIF_corr), f2(d$resid_diff_pp),
  f2(d$PhiF_direct_raw - d$PhiF_direct_corr),
  yn(d$dSIF_corr, d$dSIF_raw), yn(d$PhiF_resid_corr, d$PhiF_resid_raw),
  f4(d$DCF_base), f4(d$DCF_acute), f2(d$DCF_drift_pct),
  stringsAsFactors = FALSE)

## quote any field containing a comma or a quote, so Excel keeps it in one cell
q <- function(x) {
  x <- trimws(as.character(x))
  ifelse(grepl('[",]', x), paste0('"', gsub('"', '""', x), '"'), x)
}
pad <- function(v) paste(q(c(v, rep("", length(hdr) - length(v)))), collapse = ",")
L <- c(pad(grp), paste(q(hdr), collapse = ","),
       apply(body, 1, function(r) paste(q(r), collapse = ",")))

## ---- summary block ----
well <- d[d$acute_days >= 4, ]; spar <- d[d$acute_days <= 2, ]
s <- function(k, v) pad(c("", k, v))
L <- c(L, pad(""), pad(c("SUMMARY")),
  pad(c("", "Metric", "Value")),
  s("Corridors compared", nrow(d)),
  s("Corridors reproducing the published series", sum(d$self_check == "REPRODUCED")),
  s("Events changing sign (SIF)", sum(sign(d$dSIF_corr) != sign(d$dSIF_raw))),
  s("Events changing sign (PhiF residual)", sum(sign(d$PhiF_resid_corr) != sign(d$PhiF_resid_raw))),
  s("Rank correlation A vs B (SIF, Spearman)", f4(cor(d$dSIF_corr, d$dSIF_raw, method="spearman"))),
  s("Rank correlation A vs B (PhiF, Spearman)", f4(cor(d$PhiF_resid_corr, d$PhiF_resid_raw, method="spearman"))),
  s("Mean absolute PhiF shift (pp)", f2(mean(abs(d$resid_diff_pp)))),
  s("Largest absolute PhiF shift (pp)", f2(max(abs(d$resid_diff_pp)))),
  s("Mean absolute PhiF shift, well-sampled (>=4 acute days)", f2(mean(abs(well$resid_diff_pp)))),
  s("Mean absolute PhiF shift, sparse (<=2 acute days)", f2(mean(abs(spar$resid_diff_pp)))),
  s("Correlation of shift with daylength drift (Pearson r)",
    f4(cor(d$resid_diff_pp, d$DCF_drift_pct))),
  s("SIF range under Method A", sprintf("%+.1f%% to %+.1f%%", max(d$dSIF_corr), min(d$dSIF_corr))),
  s("SIF range under Method B", sprintf("%+.1f%% to %+.1f%%", max(d$dSIF_raw), min(d$dSIF_raw))))

## ---- notes block ----
n <- function(t) pad(c("", t))
L <- c(L, pad(""), pad(c("NOTES")),
  n("Method A is what the manuscript currently uses: PhiF = SIF_Corr_743 / NIRvR."),
  n("Method B pairs the instantaneous retrieval with the instantaneous normaliser: PhiF = SIF_743 / NIRvR."),
  n("SIF_Corr_743 is SIF_743 rescaled to a whole-day average. NIRvR is never daylength-corrected,"),
  n("so under Method A a residual solar-geometry term survives in the ratio. Method B removes it."),
  n("NIRvR contains no SIF, so its change is identical under both methods. This is a consistency check."),
  n("PhiF_residual is the Table 3 form, the derived residual (1+dSIF)/(1+dNIRvR)-1."),
  n("PhiF_direct is the direct de-meaned anomaly of PhiF, shown for completeness, not used in Table 3."),
  n("All percentages use Equation 6: baseline-de-meaned acute anomaly over pre-storm climatological SIF."),
  n("Windows: baseline days -14 to -8, acute days 0 to +6. Climatology pooled +/-4 days, other years."),
  n("Corridors: the stored 200 km corridor .gpkg used for the published tables. Geometry and QC unchanged."),
  n("Reproduces_published_series compares recomputed daily means against each event's"),
  n("event_vs_climatology.csv. All 12 matched to machine precision (max abs difference ~5e-16)."),
  n("DCF is the daylength correction factor, measured here as mean(SIF_Corr_743)/mean(SIF_743)."),
  n("Caveat: the three quantities are one decomposition of a single retrieval, not three"),
  n("independent measurements, so agreement between them is not independent confirmation."),
  n("Caveat: switching only PhiF to Method B breaks the identity 1+dSIF = (1+dNIRvR)(1+dPhiF)"),
  n("stated in Methods section 3.4. The change is all three quantities or none."),
  pad(""),
  n("Generated 2026-08-04 from G:/Alex/Data Sets/TROPOSIF Level-2B by phif_raw_all_events.R"),
  n("Run time 55 minutes, 12 corridors, one at a time. Per-event daily series saved alongside."))

writeLines(L, OUT)
cat("written:", OUT, "\n", length(L), "lines\n")
