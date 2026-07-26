# MALAWI / Cyclone Idai (2019) — full replication.
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
EV_LABEL <- "MALAWI_IDAI_2019"
EV_NAME  <- "Idai"
EV_SID   <- "2019063S18038"
EV_ENTRY <- as.Date("2019-03-07")
EV_YEAR  <- 2019
COUNTRY  <- "Malawi"
EV_DIR   <- file.path(RESULTS_ROOT, EV_LABEL)
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "run_full_event.R"))
