# ELOISE_2021 / 03_run_spatial.R  — spatial anomaly maps for Eloise.
# NOTE: Eloise is in PEAK monsoon (23 Jan) — ALL windows are cloud-blacked-out;
# expect every panel "no data". Run anyway to document the observability wall.
# RUN IN RSTUDIO: source this file.
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
EV_LABEL <- "ELOISE_2021"
EV_ENTRY <- as.Date("2021-01-23")   # closest-approach anchor (no interior center point)
EV_YEAR  <- 2021
EV_DIR   <- file.path(RESULTS_ROOT, EV_LABEL)
EV_SEG   <- NULL
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "run_spatial_for_event.R"))
