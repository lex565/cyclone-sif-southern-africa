# =============================================================================
# 01_rebuild_series_dual.R    (2026-08-07)
# Rebuild the daily event series for ALL 21 event corridors carrying BOTH SIF
# variants in a single netCDF traverse:
#   variant A = PRODUCT/SIF_Corr_743  (daylength-corrected, what the paper uses)
#   variant B = PRODUCT/SIF_743       (instantaneous, Zeng-consistent)
#
# DESIGN NOTES (read before changing anything)
#  * Corridors and anchors are NOT rebuilt. The corridor .gpkg and the rel==0
#    date are taken from the stored per-event outputs, so geometry and anchor are
#    identical to the published run by construction. Any difference that shows up
#    is attributable to the SIF variable alone.
#  * rel range is -14..+27 (the WINDOWS span). The +45..+60 late-recovery window
#    is deliberately NOT extracted: Table 2/3 report RR_vs_clim, an event-over-
#    climatology ratio on the same calendar dates, so the daylength factor cancels
#    and recovery ratios are immune to the variant. That window was also the most
#    expensive extraction in the whole pipeline.
#  * corridor_day_mean is MEMOISED per event. Uncached this is ~1176 file reads
#    per event; cached it is ~192. That is the difference between ~14 h and ~2 h.
#  * Incremental and resumable: each event writes its own CSV plus a row appended
#    to the manifest. Completed events are skipped on restart.
#  * Self-check: every event's recomputed variant-A series is compared against its
#    stored event_vs_climatology.csv. A mismatch is REPORTED, not silently passed.
# =============================================================================
sd_ <- Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared")
source(file.path(sd_, "config.R")); source(file.path(sd_, "functions.R"))
suppressMessages({library(sf)})

OUT <- file.path(Sys.getenv("CYCLONE_SIF_RESULTS", "results"), "_dual_variant_2026_08_07")
SER <- file.path(OUT, "series"); dir.create(SER, recursive = TRUE, showWarnings = FALSE)
MANIFEST <- file.path(OUT, "manifest_series.csv")

## ---- discover the 21 events from disk (no hard-coded registry) --------------
root <- RESULTS_ROOT
events <- do.call(rbind, lapply(list.dirs(root, recursive = FALSE), function(cdir) {
  country <- basename(cdir)
  do.call(rbind, lapply(list.dirs(cdir, recursive = FALSE), function(evdir) {
    ec <- file.path(evdir, "event_vs_climatology.csv")
    cg <- corridor_path(evdir)
    if (!file.exists(ec) || !file.exists(cg)) return(NULL)
    s <- read.csv(ec); s$date <- as.Date(s$date)
    z <- s$date[s$rel == 0]
    if (!length(z) || is.na(z[1])) return(NULL)
    data.frame(country = country, event = basename(evdir), evdir = evdir,
               corridor = cg, entry = z[1],
               year = as.integer(format(z[1], "%Y")), stringsAsFactors = FALSE)
  }))
}))
events <- events[order(events$country, events$event), ]
cat(sprintf("[registry] %d event corridors discovered\n", nrow(events)))

done <- character(0)
if (file.exists(MANIFEST)) {
  done <- read.csv(MANIFEST)$key
  cat(sprintf("[resume] %d already complete, skipping them\n", length(done)))
}

## ---- memoised per-event day reader -----------------------------------------
make_cached_day_mean <- function(bbox, corridor) {
  cache <- new.env(parent = emptyenv())
  function(date) {
    k <- format(date, "%Y%m%d")
    if (!is.null(cache[[k]])) return(cache[[k]])
    v <- corridor_day_mean(date, bbox, corridor)
    assign(k, v, envir = cache); v
  }
}

## ---- dual-variant series for one event -------------------------------------
build_dual <- function(entry, event_year, clim_years, bbox, corridor,
                       windows = WINDOWS, pool = 4) {
  dayf <- make_cached_day_mean(bbox, corridor)
  rel_range <- min(sapply(windows, `[`, 1)):max(sapply(windows, `[`, 2))

  evt <- do.call(rbind, lapply(rel_range, function(r) {
    m <- dayf(entry + r)
    data.frame(rel = r, date = entry + r, n = unname(m["n"]),
               sif = unname(m["sif"]), nirvr = unname(m["nirvr"]),
               phif = unname(m["phif"]), sif_raw = unname(m["sif_raw"]),
               phif_raw = unname(m["phif_raw"]))
  }))

  clim <- do.call(rbind, lapply(rel_range, function(r) {
    acc <- list(sif = c(), nirvr = c(), phif = c(), sif_raw = c(), phif_raw = c())
    for (yr in clim_years) {
      anchor <- as.Date(sprintf("%d%s", yr, format(entry + r, "-%m-%d")), format = "%Y-%m-%d")
      if (is.na(anchor)) next            # Feb 29 has no match in a non-leap clim year
      for (off in -pool:pool) {
        m <- dayf(anchor + off)
        # gate on sif ONLY, exactly as the canonical pipeline does, so the pooled
        # climatology sample is the identical set of days under both variants
        if (is.finite(m["sif"])) {
          acc$sif      <- c(acc$sif,      unname(m["sif"]))
          acc$nirvr    <- c(acc$nirvr,    unname(m["nirvr"]))
          acc$phif     <- c(acc$phif,     unname(m["phif"]))
          acc$sif_raw  <- c(acc$sif_raw,  unname(m["sif_raw"]))
          acc$phif_raw <- c(acc$phif_raw, unname(m["phif_raw"]))
        }
      }
    }
    data.frame(rel = r, clim_n = length(acc$sif),
               sif.clim = mean(acc$sif), nirvr.clim = mean(acc$nirvr),
               phif.clim = mean(acc$phif), sif_raw.clim = mean(acc$sif_raw),
               phif_raw.clim = mean(acc$phif_raw))
  }))

  m <- merge(evt, clim, by = "rel"); m <- m[order(m$rel), ]
  m$sif_anom       <- m$sif       - m$sif.clim
  m$nirvr_anom     <- m$nirvr     - m$nirvr.clim
  m$phif_anom      <- m$phif      - m$phif.clim
  m$sif_raw_anom   <- m$sif_raw   - m$sif_raw.clim
  m$phif_raw_anom  <- m$phif_raw  - m$phif_raw.clim
  m$dcf            <- m$sif / m$sif_raw          # daylength factor, event days
  m$dcf.clim       <- m$sif.clim / m$sif_raw.clim
  m$window <- NA_character_
  for (w in names(windows)) m$window[m$rel >= windows[[w]][1] & m$rel <= windows[[w]][2]] <- w
  rownames(m) <- NULL
  m
}

## ---- main loop, one event at a time ----------------------------------------
t_all <- Sys.time()
for (i in seq_len(nrow(events))) {
  e <- events[i, ]
  key <- sprintf("%s/%s", e$country, e$event)
  if (key %in% done) { cat(sprintf("[%2d/%d] SKIP %s\n", i, nrow(events), key)); next }

  cat(sprintf("\n[%2d/%d] %s  entry %s  yr %d\n", i, nrow(events), key,
              format(e$entry), e$year)); flush.console()
  t0 <- Sys.time()

  corr <- st_union(st_read(e$corridor, quiet = TRUE))
  bb   <- st_bbox(corr)
  clim_years <- setdiff(SIF_YEARS, e$year)

  m <- build_dual(as.Date(e$entry), e$year, clim_years, bb, corr)

  # ---- self-check variant A against the stored published series ----
  st_ <- read.csv(file.path(e$evdir, "event_vs_climatology.csv"))
  cmp <- merge(m[, c("rel","sif","nirvr","n")],
               st_[, c("rel","sif","nirvr","n")], by = "rel", suffixes = c("", ".pub"))
  both <- is.finite(cmp$sif) & is.finite(cmp$sif.pub)
  dmax <- if (any(both)) max(abs(cmp$sif[both] - cmp$sif.pub[both])) else NA_real_
  nmis <- sum(cmp$n != cmp$n.pub, na.rm = TRUE)
  n_new <- sum(is.finite(cmp$sif)); n_pub <- sum(is.finite(cmp$sif.pub))
  # Three states, not two. An event with no cloud-free soundings at all in the
  # event year has nothing to compare -- that is AGREEMENT with the published
  # series, not a failure. But a count DISAGREEMENT (one side has days the other
  # lacks) is a genuine mismatch and must stay loud.
  verdict <-
    if (n_new != n_pub)                                  "MISMATCH"
    else if (n_new == 0 && nmis == 0)                    "NO_EVENT_DATA"
    else if (!is.na(dmax) && dmax < 1e-10 && nmis == 0)  "REPRODUCED"
    else                                                 "MISMATCH"
  cat(sprintf("   self-check: %s  (finite days new/pub = %d/%d, max|dSIF| = %.3e, count mismatches = %d)\n",
              verdict, n_new, n_pub, dmax, nmis))

  f <- file.path(SER, sprintf("series_%s_%s.csv", e$country, e$event))
  write.csv(m, f, row.names = FALSE)

  acute <- m[!is.na(m$window) & m$window == "acute", ]
  row <- data.frame(
    key = key, country = e$country, event = e$event,
    entry = format(e$entry), year = e$year,
    self_check = verdict, max_abs_dSIF = dmax, n_count_mismatch = nmis,
    finite_days_new = n_new, finite_days_pub = n_pub,
    usable_acute_days = sum(is.finite(acute$sif)),
    acute_soundings = sum(acute$n, na.rm = TRUE),
    minutes = round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 2),
    file = basename(f), stringsAsFactors = FALSE)
  write.table(row, MANIFEST, sep = ",", row.names = FALSE,
              col.names = !file.exists(MANIFEST), append = file.exists(MANIFEST))

  cat(sprintf("   acute usable days %d, soundings %d, %.1f min -> %s\n",
              row$usable_acute_days, row$acute_soundings, row$minutes, basename(f)))
  rm(m, corr, st_, cmp); gc(verbose = FALSE)
}

cat(sprintf("\n#### ALL DONE in %.1f min ####\n",
            as.numeric(difftime(Sys.time(), t_all, units = "mins"))))
mf <- read.csv(MANIFEST)
cat(sprintf("events: %d | REPRODUCED: %d | NO_EVENT_DATA: %d | MISMATCH: %d\n",
            nrow(mf), sum(mf$self_check == "REPRODUCED"),
            sum(mf$self_check == "NO_EVENT_DATA"), sum(mf$self_check == "MISMATCH")))
if (any(mf$self_check == "MISMATCH")) {
  cat("\n!! THESE EVENTS DID NOT REPRODUCE - investigate before using variant B:\n")
  print(mf[mf$self_check == "MISMATCH",
           c("key","finite_days_new","finite_days_pub","max_abs_dSIF","n_count_mismatch")])
} else {
  cat("\nAll events either reproduced the published series exactly or have no event-year data at all.\n")
}
