# BOTSWANA / Cyclone Eloise (2021 remnant) — full replication.
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
EV_LABEL <- "BOTSWANA_ELOISE_2021"
EV_NAME  <- "Eloise"
EV_SID   <- "2021012S12086"
EV_ENTRY <- as.Date("2021-01-25")
EV_YEAR  <- 2021
COUNTRY  <- "Botswana"
EV_DIR   <- file.path(RESULTS_ROOT, EV_LABEL)
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "run_full_event.R"))
