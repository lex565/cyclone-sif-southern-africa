# =============================================================================
# run_expansion.R — full SIF pipeline for the country expansion (GPP deferred).
# Adds Mozambique (6) + Madagascar (8) + South Africa (1) = 15 storm-country
# events. Eq 8 (GPP) is auto-deferred by the guard in original_metrics.R.
#
# Usage:  Rscript run_expansion.R [Country]   # filter to one country; omit = all
# Resumable: skips any event whose *_original_metrics.md already exists.
# Foreground, staged [n/N] progress per event.
# =============================================================================
sd_ <- Sys.getenv("CYCLONE_SIF_CODE", Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"))
source(file.path(sd_, "config.R"))

EV <- read.csv(text = "label,name,sid,entry,year,country
MOZAMBIQUE_IDAI_2019,Idai,2019063S18038,2019-03-04,2019,Mozambique
MOZAMBIQUE_KENNETH_2019,Kenneth,2019112S10053,2019-04-25,2019,Mozambique
MOZAMBIQUE_ELOISE_2021,Eloise,2021012S12086,2021-01-23,2021,Mozambique
MOZAMBIQUE_CHALANE_2020,Chalane,2020355S11065,2020-12-30,2020,Mozambique
MOZAMBIQUE_DESMOND_2019,Desmond,2019018S24033,2019-01-17,2019,Mozambique
MOZAMBIQUE_GUAMBE_2021,Guambe,2021042S23040,2021-02-12,2021,Mozambique
MADAGASCAR_AVA_2018,Ava,2017364S12065,2018-01-05,2018,Madagascar
MADAGASCAR_ELIAKIM_2018,Eliakim,2018073S12057,2018-03-16,2018,Madagascar
MADAGASCAR_BELNA_2019,Belna,2019336S06055,2019-12-09,2019,Madagascar
MADAGASCAR_DIANE_2020,Diane,2020022S17043,2020-01-22,2020,Madagascar
MADAGASCAR_FRANCISCO_2020,Francisco,2020034S13063,2020-02-15,2020,Madagascar
MADAGASCAR_CHALANE_2020,Chalane,2020355S11065,2020-12-26,2020,Madagascar
MADAGASCAR_ELOISE_2021,Eloise,2021012S12086,2021-01-19,2021,Madagascar
MADAGASCAR_IMAN_2021,Iman,2021062S18040,2021-03-05,2021,Madagascar
SOUTH_AFRICA_ELOISE_2021,Eloise,2021012S12086,2021-01-24,2021,South_Africa
", stringsAsFactors = FALSE, strip.white = TRUE)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1 && nzchar(args[1])) {
  EV <- EV[EV$country == args[1], , drop = FALSE]
  cat(sprintf(">> filtered to country: %s (%d events)\n", args[1], nrow(EV)))
}

N <- nrow(EV)
ok <- 0; skipped <- 0; failed <- character(0)
t0 <- Sys.time()
for (i in seq_len(N)) {
  e <- EV[i, ]
  EV_DIR <- file.path(RESULTS_ROOT, e$label)
  donemark <- file.path(EV_DIR, paste0(e$label, "_original_metrics.md"))
  cat(sprintf("\n==================== [%d/%d] %s ====================\n", i, N, e$label))
  if (file.exists(donemark)) {
    cat("   already complete (metrics md present) — skipping.\n"); skipped <- skipped + 1; next
  }
  te <- Sys.time()
  res <- tryCatch({
    EV_LABEL <- e$label; EV_NAME <- e$name; EV_SID <- e$sid
    EV_ENTRY <- as.Date(e$entry); EV_YEAR <- as.integer(e$year); COUNTRY <- e$country
    EV_DIR <- EV_DIR
    sys.source(file.path(sd_, "run_full_event.R"), envir = environment())
    TRUE
  }, error = function(err) { message("   !! FAILED: ", conditionMessage(err)); FALSE })
  if (isTRUE(res)) { ok <- ok + 1
    cat(sprintf("   [%d/%d] done in %.1f min\n", i, N, as.numeric(difftime(Sys.time(), te, units="mins"))))
  } else failed <- c(failed, e$label)
}
cat(sprintf("\n######## EXPANSION BATCH COMPLETE ########\n"))
cat(sprintf("  done=%d  skipped(existing)=%d  failed=%d  | total %.1f min\n",
            ok, skipped, length(failed), as.numeric(difftime(Sys.time(), t0, units="mins"))))
if (length(failed)) cat("  FAILED:", paste(failed, collapse=", "), "\n")
