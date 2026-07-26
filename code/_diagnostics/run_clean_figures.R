# Generate the clean figure pair for events. Arg = specific labels; else all
# completed events (have event_vs_climatology.csv + *_original_metrics.md).
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "clean_figures.R"))
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  dirs <- file.path(RESULTS_ROOT, args)
} else {
  # recurse: an event folder has event_vs_climatology.csv + <name>_original_metrics.md (flat OR nested)
  all <- list.dirs(RESULTS_ROOT, recursive=TRUE)
  dirs <- Filter(function(d) file.exists(file.path(d,"event_vs_climatology.csv")) &&
                   length(list.files(d, pattern="_original_metrics\\.md$")) > 0, all)
}
cat(sprintf("Clean figures for %d event(s)...\n", length(dirs)))
for (d in dirs) tryCatch(clean_event_pair(d),
                         error=function(e) cat("  !! FAILED", basename(d), ":", conditionMessage(e), "\n"))
cat("DONE.\n")
