# IDAI_2019 / 06_redraw_figures.R — fast re-render with improved engine (no recompute).
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
EV_LABEL <- "IDAI_2019"
EV_ENTRY <- as.Date("2019-03-15")
EV_DIR   <- file.path(RESULTS_ROOT, EV_LABEL)
EV_SEG   <- file.path(RESULTS_ROOT, "idai2019_zim_segment.gpkg")
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "redraw_figures.R"))
