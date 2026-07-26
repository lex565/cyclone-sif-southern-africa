# BOTSWANA / Cyclone Chalane (2020 remnant) — full replication.
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
EV_LABEL <- "BOTSWANA_CHALANE_2020"
EV_NAME  <- "Chalane"
EV_SID   <- "2020355S11065"
EV_ENTRY <- as.Date("2020-12-31")
EV_YEAR  <- 2020
COUNTRY  <- "Botswana"
EV_DIR   <- file.path(RESULTS_ROOT, EV_LABEL)
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "run_full_event.R"))
