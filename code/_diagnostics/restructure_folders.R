# =============================================================================
# restructure_folders.R — reorganize the FLAT event folders into a country
# hierarchy:  <RESULTS_ROOT>/<Country>/<Storm>_<Year>/...
#   IDAI_2019            -> Zimbabwe/Idai_2019
#   MALAWI_IDAI_2019     -> Malawi/Idai_2019
#   MOZAMBIQUE_KENNETH_2019 -> Mozambique/Kenneth_2019
#   SOUTH_AFRICA_ELOISE_2021 -> South_Africa/Eloise_2021   ... etc
# Only moves event folders (those with window_anomalies.csv). Idempotent: skips
# anything already nested. RUN ONLY AFTER all pipeline batches have finished.
# =============================================================================
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))

titlecase <- function(s) paste0(toupper(substr(s,1,1)), tolower(substr(s,2,nchar(s))))
parse_flat <- function(label) {
  p <- strsplit(label,"_")[[1]]; n <- length(p); year <- p[n]
  if (p[1]=="SOUTH" && length(p)>=3 && p[2]=="AFRICA") { country<-"South_Africa"; storm<-p[3] }
  else if (p[1] %in% c("MOZAMBIQUE","MADAGASCAR","BOTSWANA","MALAWI")) { country<-titlecase(p[1]); storm<-p[2] }
  else { country<-"Zimbabwe"; storm<-p[1] }
  list(country=country, sub=paste0(titlecase(storm), "_", year))
}

tops <- list.dirs(RESULTS_ROOT, recursive=FALSE)
known <- c("Zimbabwe","Malawi","Botswana","Mozambique","Madagascar","South_Africa")
moved <- 0; skipped <- 0
for (d in tops) {
  lab <- basename(d)
  if (lab %in% known || startsWith(lab, "_")) { next }                 # already a country dir or special
  if (!file.exists(file.path(d, paste0(lab, "_original_metrics.md")))) { next }  # only move COMPLETE events
  m <- parse_flat(lab)
  cdir <- file.path(RESULTS_ROOT, m$country); dir.create(cdir, showWarnings=FALSE)
  target <- file.path(cdir, m$sub)
  if (dir.exists(target)) { cat("  exists, skip:", lab, "->", m$country, "/", m$sub, "\n"); skipped<-skipped+1; next }
  ok <- file.rename(d, target)
  cat(sprintf("  %s  %-26s -> %s/%s\n", ifelse(ok,"moved","FAIL "), lab, m$country, m$sub)); if(ok) moved<-moved+1
}
cat(sprintf("\nDONE. moved=%d skipped=%d\n", moved, skipped))
cat("Event folders now live under <country>/<Storm>_<Year>/. Re-run generators\n",
    "(run_clean_figures.R / generate_explainer.py / clean_attribution.R) — they recurse.\n")
