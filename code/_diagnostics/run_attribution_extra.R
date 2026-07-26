# Run Eq9 attribution for the two ADDITIONAL feasible events:
#   Malawi/Idai 2019  (53 acute cells)  and  Chalane/Zimbabwe 2020 (58 acute cells).
# Idai/Zimbabwe already done (147 cells). Eloise x2 + Botswana/Chalane (4 cells)
# cannot support pixel attribution.
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "functions.R"))
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "attribution_engine.R"))

evroot <- RESULTS_ROOT

cat("\n###### EVENT 1 of 2 : MALAWI / IDAI 2019 ######\n")
run_attribution(country = "Malawi", event_year = 2019,
                entry = as.Date("2019-03-07"), sid = "2019063S18038",
                evdir = file.path(evroot, "MALAWI_IDAI_2019"))

cat("\n###### EVENT 2 of 2 : ZIMBABWE / CHALANE 2020 ######\n")
run_attribution(country = "Zimbabwe", event_year = 2020,
                entry = as.Date("2020-12-30"), sid = "2020355S11065",
                evdir = file.path(evroot, "CHALANE_2020"))

cat("\nALL EXTRA ATTRIBUTION RUNS COMPLETE.\n")
