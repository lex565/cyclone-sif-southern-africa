# CHALANE_2020 / 06_redraw_figures.R — re-render figures with improved engine.
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
EV_LABEL <- "CHALANE_2020"
EV_ENTRY <- as.Date("2020-12-30")
EV_DIR   <- file.path(RESULTS_ROOT, EV_LABEL)
EV_SEG   <- NULL
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "redraw_figures.R"))
