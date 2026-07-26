# CHALANE_2020 / 03_run_spatial.R  — spatial anomaly maps for Chalane.
# NOTE: recovery windows are cloud-blacked-out (wet season) — maps will show
# "no data" panels honestly. RUN IN RSTUDIO: source this file.
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
EV_LABEL <- "CHALANE_2020"
EV_ENTRY <- as.Date("2020-12-30")
EV_YEAR  <- 2020
EV_DIR   <- file.path(RESULTS_ROOT, EV_LABEL)
EV_SEG   <- NULL   # generated inline if needed
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "run_spatial_for_event.R"))
