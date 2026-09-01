# =============================================================================
# 02_eq6_triplet_dual.R   (2026-08-07)
# Eq 6 percentage change + the Table 3 triplet, for EVERY window and EVERY event,
# under both SIF variants. Pure arithmetic over the saved dual-variant series --
# no netCDF is opened, so this runs in seconds.
#
# Eq 6 exactly as original_metrics.R::pct_and_recovery implements it:
#     clim_baseline = mean(sif.clim over baseline days -14..-8)
#     offset        = mean(sif_anom  over baseline days)
#     pct(window)   = 100 * (mean(sif_anom over window) - offset) / clim_baseline
# The de-meaning term (offset) is the part the composite-figure bug once omitted.
#
# PhiF is reported BOTH ways, as in the published work:
#   residual = (1+dSIF)/(1+dNIRvR) - 1   <- the Table 3 form
#   direct   = Eq 6 applied to phif_anom <- blows up for Desmond (+139%)
#
# ACCEPTANCE TEST: variant A must reproduce each event's PUBLISHED
# metrics/eq6_pct_change.csv (pct_corrected). That file is the manuscript's own
# output, so this checks against the paper, not against my earlier rerun.
# =============================================================================
SER <- file.path(Sys.getenv("CYCLONE_SIF_RESULTS", "results"), "_dual_variant_2026_08_07", "series")
PUB <- Sys.getenv("CYCLONE_SIF_OUT", "derived_data")
OUT <- file.path(Sys.getenv("CYCLONE_SIF_RESULTS", "results"), "_dual_variant_2026_08_07")
BASE <- c(-14, -8)

mf <- read.csv(file.path(OUT, "manifest_series.csv"), stringsAsFactors = FALSE)

# Eq 6 for one anomaly/climatology pair over one window
eq6 <- function(d, wsel, bsel, anom_col, clim_col) {
  clim_baseline <- mean(d[[clim_col]][bsel], na.rm = TRUE)
  offset        <- mean(d[[anom_col]][bsel], na.rm = TRUE)
  anom_w        <- mean(d[[anom_col]][wsel], na.rm = TRUE)
  if (!is.finite(clim_baseline) || !is.finite(anom_w) || !is.finite(offset)) return(NA_real_)
  100 * (anom_w - offset) / clim_baseline
}

rows <- list(); checks <- list()
for (i in seq_len(nrow(mf))) {
  m <- mf[i, ]
  d <- read.csv(file.path(SER, m$file))
  bsel <- d$rel >= BASE[1] & d$rel <= BASE[2]
  pubf <- file.path(PUB, m$country, m$event, "metrics", "eq6_pct_change.csv")
  pub  <- if (file.exists(pubf)) read.csv(pubf) else NULL

  for (w in unique(d$window[!is.na(d$window)])) {
    wsel <- !is.na(d$window) & d$window == w
    n_days <- sum(is.finite(d$sif[wsel]))

    A_sif   <- eq6(d, wsel, bsel, "sif_anom",      "sif.clim")
    B_sif   <- eq6(d, wsel, bsel, "sif_raw_anom",  "sif_raw.clim")
    nirvr   <- eq6(d, wsel, bsel, "nirvr_anom",    "nirvr.clim")
    A_dir   <- eq6(d, wsel, bsel, "phif_anom",     "phif.clim")
    B_dir   <- eq6(d, wsel, bsel, "phif_raw_anom", "phif_raw.clim")
    # derived residual, the Table 3 form
    res <- function(s) if (is.finite(s) && is.finite(nirvr))
      100 * ((1 + s/100) / (1 + nirvr/100) - 1) else NA_real_
    A_res <- res(A_sif); B_res <- res(B_sif)

    rows[[length(rows)+1]] <- data.frame(
      country = m$country, event = m$event, window = w, n_days = n_days,
      acute_soundings = if (w == "acute") m$acute_soundings else NA_integer_,
      NIRvR_pct = nirvr,
      A_SIF_pct = A_sif, A_PhiF_residual_pct = A_res, A_PhiF_direct_pct = A_dir,
      B_SIF_pct = B_sif, B_PhiF_residual_pct = B_res, B_PhiF_direct_pct = B_dir,
      Diff_SIF_pp = B_sif - A_sif,
      Diff_PhiF_residual_pp = B_res - A_res,
      Diff_PhiF_direct_pp = B_dir - A_dir,
      SIF_sign_changed = if (is.finite(A_sif) && is.finite(B_sif))
        ifelse(sign(A_sif) != sign(B_sif), "YES", "no") else NA_character_,
      PhiF_sign_changed = if (is.finite(A_res) && is.finite(B_res))
        ifelse(sign(A_res) != sign(B_res), "YES", "no") else NA_character_,
      stringsAsFactors = FALSE)

    if (!is.null(pub)) {
      pr <- pub[pub$window == w, ]
      if (nrow(pr) == 1) {
        pv <- pr$pct_corrected[1]
        checks[[length(checks)+1]] <- data.frame(
          country = m$country, event = m$event, window = w,
          published = pv, recomputed_A = round(A_sif, 1),
          diff = round(A_sif, 1) - pv,
          verdict = if (is.na(pv) && is.na(A_sif)) "BOTH_NA"
                    else if (is.na(pv) || is.na(A_sif)) "ONE_NA"
                    else if (abs(round(A_sif,1) - pv) <= 0.1) "MATCH" else "DIFFER",
          stringsAsFactors = FALSE)
      }
    }
  }
}
res_all <- do.call(rbind, rows)
chk <- do.call(rbind, checks)

write.csv(res_all, file.path(OUT, "eq6_triplet_all_windows_dual.csv"), row.names = FALSE)
write.csv(chk,     file.path(OUT, "eq6_acceptance_check.csv"),        row.names = FALSE)

cat("\n===== ACCEPTANCE: variant A vs the PUBLISHED eq6_pct_change.csv =====\n")
print(table(chk$verdict))
bad <- chk[chk$verdict == "DIFFER", ]
if (nrow(bad)) { cat("\n!! DISAGREEMENTS:\n"); print(bad, row.names = FALSE) } else
  cat("\nNo disagreements. Variant A reproduces the published Eq 6 for every window of every event.\n")

cat("\n\n===== ACUTE WINDOW, the Table 3 comparison =====\n")
a <- res_all[res_all$window == "acute" & is.finite(res_all$A_SIF_pct), ]
a <- a[order(-a$n_days), ]
p <- data.frame(Corridor = paste(a$country, a$event, sep = "/"),
                d = a$n_days, snd = a$acute_soundings,
                NIRvR = round(a$NIRvR_pct, 2),
                A_SIF = round(a$A_SIF_pct, 2), B_SIF = round(a$B_SIF_pct, 2),
                dSIF = round(a$Diff_SIF_pp, 2),
                A_PhiF = round(a$A_PhiF_residual_pct, 2),
                B_PhiF = round(a$B_PhiF_residual_pct, 2),
                dPhiF = round(a$Diff_PhiF_residual_pp, 2),
                flip = a$SIF_sign_changed)
print(p, row.names = FALSE)

cat(sprintf("\ncorridors with an acute value : %d\n", nrow(a)))
cat(sprintf("SIF sign changes              : %d\n", sum(a$SIF_sign_changed == "YES", na.rm = TRUE)))
cat(sprintf("PhiF sign changes             : %d\n", sum(a$PhiF_sign_changed == "YES", na.rm = TRUE)))
cat(sprintf("mean |PhiF shift|             : %.2f pp\n", mean(abs(a$Diff_PhiF_residual_pp), na.rm = TRUE)))
cat(sprintf("max  |PhiF shift|             : %.2f pp\n", max(abs(a$Diff_PhiF_residual_pp), na.rm = TRUE)))
cat(sprintf("Spearman A vs B (SIF)         : %.4f\n",
            cor(a$A_SIF_pct, a$B_SIF_pct, method = "spearman")))
cat(sprintf("Spearman A vs B (PhiF)        : %.4f\n",
            cor(a$A_PhiF_residual_pct, a$B_PhiF_residual_pct, method = "spearman")))
cat(sprintf("headline range A              : %+.1f%% to %+.1f%%\n",
            max(a$A_SIF_pct), min(a$A_SIF_pct)))
cat(sprintf("headline range B              : %+.1f%% to %+.1f%%\n",
            max(a$B_SIF_pct), min(a$B_SIF_pct)))
cat("\nwrote:\n  eq6_triplet_all_windows_dual.csv\n  eq6_acceptance_check.csv\n")
