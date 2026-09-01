sp <- file.path(Sys.getenv("CYCLONE_SIF_OUT", "derived_data"), "robustness", "phif_variant_2026_08_04")
d <- read.csv(file.path(sp, "phif_raw_vs_corr_ALL.csv"))
cat("n events:", nrow(d), " all REPRODUCED:", all(d$self_check == "REPRODUCED"), "\n\n")
cat("SIF headline range  corrected : ", sprintf("%+.1f%% to %+.1f%%\n",
    max(d$dSIF_corr), min(d$dSIF_corr)))
cat("SIF headline range  raw       : ", sprintf("%+.1f%% to %+.1f%%\n",
    max(d$dSIF_raw), min(d$dSIF_raw)))
cat("\nsign flips  dSIF :", sum(sign(d$dSIF_corr) != sign(d$dSIF_raw)),
    " | PhiF resid :", sum(sign(d$PhiF_resid_corr) != sign(d$PhiF_resid_raw)), "\n")
cat("rank change dSIF (Spearman corr vs raw):",
    sprintf("%.4f", cor(d$dSIF_corr, d$dSIF_raw, method = "spearman")), "\n")
cat("rank change PhiF (Spearman corr vs raw):",
    sprintf("%.4f", cor(d$PhiF_resid_corr, d$PhiF_resid_raw, method = "spearman")), "\n")
cat("\nshift vs DCF drift, Pearson r =",
    sprintf("%.3f", cor(d$resid_diff_pp, d$DCF_drift_pct)), "\n")
cat("|shift| vs |DCF drift|, r      =",
    sprintf("%.3f", cor(abs(d$resid_diff_pp), abs(d$DCF_drift_pct))), "\n")
well <- d[d$acute_days >= 4, ]; spar <- d[d$acute_days <= 2, ]
cat(sprintf("\nwell-sampled (>=4 acute days, n=%d): mean |shift| %.2f pp, max %.2f\n",
    nrow(well), mean(abs(well$resid_diff_pp)), max(abs(well$resid_diff_pp))))
cat(sprintf("sparse       (<=2 acute days, n=%d): mean |shift| %.2f pp, max %.2f\n",
    nrow(spar), mean(abs(spar$resid_diff_pp)), max(abs(spar$resid_diff_pp))))
cat(sprintf("|shift| vs acute_days, r = %.3f\n", cor(abs(d$resid_diff_pp), d$acute_days)))
cat(sprintf("|DCF drift| vs acute_days, r = %.3f\n", cor(abs(d$DCF_drift_pct), d$acute_days)))
cat("\nbiggest movers by |dSIF| change:\n")
d$dSIF_shift <- d$dSIF_raw - d$dSIF_corr
print(d[order(-abs(d$dSIF_shift)), c("country","event","acute_days","dSIF_corr","dSIF_raw","dSIF_shift")],
      row.names = FALSE, digits = 4)
