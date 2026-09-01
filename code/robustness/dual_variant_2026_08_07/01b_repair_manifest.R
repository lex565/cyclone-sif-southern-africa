# =============================================================================
# 01b_repair_manifest.R  (2026-08-07)
# Re-derive self-check verdicts for events ALREADY on disk, using the saved
# series CSVs. No netCDF is re-read, so this costs seconds instead of ~8 min per
# event. Needed because the first run's verdict logic labelled "no event-year
# data at all" as MISMATCH, which it is not.
# Rewrites manifest_series.csv in the new schema.
# =============================================================================
OUT <- file.path(Sys.getenv("CYCLONE_SIF_RESULTS", "results"), "_dual_variant_2026_08_07")
SER <- file.path(OUT, "series")
PUB <- Sys.getenv("CYCLONE_SIF_OUT", "derived_data")
MANIFEST <- file.path(OUT, "manifest_series.csv")

old <- read.csv(MANIFEST, stringsAsFactors = FALSE)
cat(sprintf("[repair] %d rows in existing manifest\n", nrow(old)))

rows <- lapply(seq_len(nrow(old)), function(i) {
  o <- old[i, ]
  new <- read.csv(file.path(SER, o$file))
  pub <- read.csv(file.path(PUB, o$country, o$event, "event_vs_climatology.csv"))
  cmp <- merge(new[, c("rel","sif","n")], pub[, c("rel","sif","n")],
               by = "rel", suffixes = c("", ".pub"))
  both  <- is.finite(cmp$sif) & is.finite(cmp$sif.pub)
  dmax  <- if (any(both)) max(abs(cmp$sif[both] - cmp$sif.pub[both])) else NA_real_
  nmis  <- sum(cmp$n != cmp$n.pub, na.rm = TRUE)
  n_new <- sum(is.finite(cmp$sif)); n_pub <- sum(is.finite(cmp$sif.pub))
  verdict <-
    if (n_new != n_pub)                                  "MISMATCH"
    else if (n_new == 0 && nmis == 0)                    "NO_EVENT_DATA"
    else if (!is.na(dmax) && dmax < 1e-10 && nmis == 0)  "REPRODUCED"
    else                                                 "MISMATCH"
  cat(sprintf("  %-28s %-14s -> %-14s (days new/pub %d/%d)\n",
              o$key, o$self_check, verdict, n_new, n_pub))
  data.frame(key = o$key, country = o$country, event = o$event,
             entry = o$entry, year = o$year,
             self_check = verdict, max_abs_dSIF = dmax, n_count_mismatch = nmis,
             finite_days_new = n_new, finite_days_pub = n_pub,
             usable_acute_days = o$usable_acute_days,
             acute_soundings = o$acute_soundings,
             minutes = o$minutes, file = o$file, stringsAsFactors = FALSE)
})
mf <- do.call(rbind, rows)
write.csv(mf, MANIFEST, row.names = FALSE)
cat(sprintf("\n[repair] manifest rewritten: REPRODUCED %d | NO_EVENT_DATA %d | MISMATCH %d\n",
            sum(mf$self_check == "REPRODUCED"), sum(mf$self_check == "NO_EVENT_DATA"),
            sum(mf$self_check == "MISMATCH")))
