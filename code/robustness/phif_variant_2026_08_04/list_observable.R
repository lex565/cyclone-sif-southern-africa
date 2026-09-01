## Which events are acute-observable? Read it off the stored canonical series.
root <- Sys.getenv("CYCLONE_SIF_OUT", "derived_data")
rows <- list()
for (cty in list.dirs(root, recursive = FALSE)) {
  if (basename(cty) %in% c(".claude", "_FIGURE_PROTOTYPES")) next
  for (ev in list.dirs(cty, recursive = FALSE)) {
    f <- file.path(ev, "event_vs_climatology.csv")
    if (!file.exists(f)) next
    m <- read.csv(f)
    ac <- m[m$window == "acute", ]
    bs <- m[m$window == "baseline", ]
    rows[[length(rows) + 1]] <- data.frame(
      country = basename(cty), event = basename(ev),
      acute_days = sum(ac$n > 0, na.rm = TRUE),
      acute_soundings = sum(ac$n, na.rm = TRUE),
      base_days = sum(bs$n > 0, na.rm = TRUE),
      entry = as.character(m$date[m$rel == 0]),
      corridor = basename(if (file.exists(file.path(ev, "corridor.gpkg")))
                            file.path(ev, "corridor.gpkg") else file.path(ev, "corridor_zim.gpkg")),
      has_corr = file.exists(file.path(ev, "corridor.gpkg")) ||
                 file.exists(file.path(ev, "corridor_zim.gpkg")))
  }
}
d <- do.call(rbind, rows)
d <- d[order(-d$acute_days, d$country), ]
print(d, row.names = FALSE)
cat("\nObservable (acute_days > 0):", sum(d$acute_days > 0), "of", nrow(d), "\n")
cat("Blackout (acute_days == 0)  :", sum(d$acute_days == 0), "\n")
cat("Missing corridor file       :", sum(!d$has_corr), "\n")
