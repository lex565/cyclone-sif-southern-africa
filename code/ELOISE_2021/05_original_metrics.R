# ELOISE_2021 / 05_original_metrics.R — original Section-3 metrics (additive).
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
EV_LABEL <- "ELOISE_2021"
EV_ENTRY <- as.Date("2021-01-23")
EV_YEAR  <- 2021
COUNTRY  <- "Zimbabwe"
EV_DIR   <- file.path(RESULTS_ROOT, EV_LABEL)
EV_SEG   <- NULL
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "run_metrics_for_event.R"))
