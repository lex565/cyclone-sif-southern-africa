# ELOISE_2021 / 06_redraw_figures.R — re-render figures with improved engine.
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
EV_LABEL <- "ELOISE_2021"
EV_ENTRY <- as.Date("2021-01-23")
EV_DIR   <- file.path(RESULTS_ROOT, EV_LABEL)
EV_SEG   <- NULL
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "redraw_figures.R"))
