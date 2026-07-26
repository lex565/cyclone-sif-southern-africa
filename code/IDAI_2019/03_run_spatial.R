# IDAI_2019 / 03_run_spatial.R  — spatial anomaly maps for IDAI (full Zim cartography).
# RUN IN RSTUDIO: source this file.
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
EV_LABEL <- "IDAI_2019"
EV_ENTRY <- as.Date("2019-03-15")
EV_YEAR  <- 2019
EV_DIR   <- file.path(RESULTS_ROOT, EV_LABEL)
EV_SEG   <- file.path(RESULTS_ROOT, "idai2019_zim_segment.gpkg")
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "run_spatial_for_event.R"))
