# =============================================================================
# 00_shared/pub_panels.R — render text-free map panels for publication figures.
#
# Companion to clean_figures.R. That script bakes titles, a colour bar and the
# north arrow into every panel at a fixed 1850x1040 raster; stitching those into
# a multi-event figure is what clips the titles and blows up the legend. Here we
# emit ONLY the map content, cropped exactly to the corridor bbox, and leave all
# typography to the composer (compose_figures.py) which draws it once, as vector
# text, at the final figure size.
#
# Colour breaks / palette / smoothing are taken from clean_figures.R unchanged so
# the map interiors stay identical to the locked reference style.
#
# Usage:  Rscript pub_panels.R
# Output: <OUTROOT>/<LABEL>__<signal>__<window>.png   (+ manifest.csv)
# =============================================================================
suppressMessages({library(terra); library(sf)})
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))

OUTROOT <- file.path(Sys.getenv("CYCLONE_SIF_RESULTS", "results"), "_pub_build/panels")
dir.create(OUTROOT, recursive = TRUE, showWarnings = FALSE)

# ---- locked display options (verbatim from clean_figures.R) ----
.SMOOTH      <- TRUE
.SMOOTH_FACT <- 8
.BRK <- c(-200,-40,-20,-5,5,20,40,200)
.COL <- c("#8c2d04","#d95f0e","#f6a563","#f7f7f7","#a6d96a","#5aae61","#1a7e3f")

PX_PER_DEG <- 150   # render density; composer downsamples to final dpi

.parse_label <- function(evdir) {
  label <- basename(evdir); parent <- basename(dirname(evdir))
  parts <- strsplit(label, "_")[[1]]; n <- length(parts)
  year  <- if (grepl("^[0-9]{4}$", parts[n])) parts[n] else "?"
  list(country = parent, storm = parts[1], year = year)
}

.month_label <- function(evdir, year) {
  f <- file.path(evdir, "event_vs_climatology.csv")
  if (file.exists(f)) {
    d <- read.csv(f); z <- d[d$rel == 0, "date"][1]
    if (!is.na(z)) return(format(as.Date(z), "%b %Y"))
  }
  year
}

# Render one map, cropped to bbox with zero margin. Returns TRUE if data drawn.
.render_panel <- function(r, cbb, boundary, segment, outfile) {
  dx <- cbb["xmax"] - cbb["xmin"]; dy <- cbb["ymax"] - cbb["ymin"]
  w  <- max(round(dx * PX_PER_DEG), 200); h <- max(round(dy * PX_PER_DEG), 200)
  png(outfile, width = w, height = h, bg = "white")
  par(mar = c(0,0,0,0), xaxs = "i", yaxs = "i")
  plot(NA, xlim = c(cbb["xmin"], cbb["xmax"]), ylim = c(cbb["ymin"], cbb["ymax"]),
       xlab = "", ylab = "", axes = FALSE, asp = NA)
  if (!is.null(r)) {
    r <- clamp(r, min(.BRK), max(.BRK), values = TRUE)
    if (.SMOOTH) r <- disagg(r, .SMOOTH_FACT, method = "bilinear")
    image(r, breaks = .BRK, col = .COL, add = TRUE, maxcell = 5e6)
  }
  if (!is.null(boundary)) plot(st_geometry(boundary), add = TRUE, border = "grey25", lwd = 1.3)
  if (!is.null(segment))  plot(st_geometry(segment),  add = TRUE, col = "black", lwd = 3.2)
  dev.off()
  invisible(!is.null(r))
}

pub_event_panels <- function(evdir, rows) {
  label <- basename(evdir); meta <- .parse_label(evdir)
  sm    <- file.path(evdir, "spatial_maps")
  dlab  <- .month_label(evdir, meta$year)
  cat(sprintf("  panels: %s (%s, %s)\n", label, meta$country, dlab))

  cpath <- corridor_path(evdir)
  corr  <- tryCatch(st_union(st_read(cpath, quiet = TRUE)), error = function(e) NULL)
  if (is.null(corr)) { cat("   !! no corridor; skip\n"); return(rows) }
  cbb <- st_bbox(corr)
  boundary <- tryCatch(st_union(st_make_valid(st_read(country_shp(meta$country), quiet = TRUE))),
                       error = function(e) NULL)
  segf <- file.path(evdir, "segment.gpkg")
  if (!file.exists(segf) && label == "IDAI_2019") segf <- file.path(RESULTS_ROOT, "idai2019_zim_segment.gpkg")
  segment <- if (file.exists(segf)) tryCatch(st_read(segf, quiet = TRUE), error = function(e) NULL) else NULL

  evc <- tryCatch(read.csv(file.path(evdir, "event_vs_climatology.csv")), error = function(e) NULL)
  if (is.null(evc)) { cat("   !! no event_vs_climatology; skip\n"); return(rows) }
  br  <- evc[evc$rel >= -14 & evc$rel <= -8, ]
  lvl <- c(sif   = mean(br$sif.clim,   na.rm = TRUE),
           nirvr = mean(br$nirvr.clim, na.rm = TRUE),
           phif  = mean(br$phif.clim,  na.rm = TRUE))
  evc$date <- as.Date(evc$date)
  drange <- function(lo, hi) {
    s <- evc$date[evc$rel >= lo & evc$rel <= hi]; s <- s[!is.na(s)]
    if (!length(s)) "" else sprintf("%s - %s", format(min(s), "%d %b"), format(max(s), "%d %b %Y"))
  }
  pct <- function(sig, win) {
    f <- file.path(sm, sprintf("anomd_%s_%s.tif", sig, win))
    if (!file.exists(f) || !is.finite(lvl[[sig]]) || lvl[[sig]] == 0) return(NULL)
    rast(f) / lvl[[sig]] * 100
  }

  jobs <- rbind(
    data.frame(sig = "sif",   win = "pre7",   sub = drange(-7, -1),  stringsAsFactors = FALSE),
    data.frame(sig = "sif",   win = "acute",  sub = drange(0, 6),    stringsAsFactors = FALSE),
    data.frame(sig = "sif",   win = "recov3", sub = drange(21, 27),  stringsAsFactors = FALSE),
    data.frame(sig = "nirvr", win = "acute",  sub = drange(0, 6),    stringsAsFactors = FALSE),
    data.frame(sig = "phif",  win = "acute",  sub = drange(0, 6),    stringsAsFactors = FALSE)
  )

  for (i in seq_len(nrow(jobs))) {
    sig <- jobs$sig[i]; win <- jobs$win[i]
    key <- sprintf("%s__%s__%s__%s", meta$country, label, sig, win)
    out <- file.path(OUTROOT, paste0(key, ".png"))
    r   <- pct(sig, win)
    ok  <- .render_panel(r, cbb, boundary, segment, out)
    rows[[length(rows) + 1]] <- data.frame(
      key = key, country = meta$country, label = label, storm = meta$storm,
      date_label = dlab, signal = sig, window = win, subtitle = jobs$sub[i],
      has_data = ok, file = if (ok) out else NA_character_,
      xmin = cbb["xmin"], xmax = cbb["xmax"], ymin = cbb["ymin"], ymax = cbb["ymax"],
      stringsAsFactors = FALSE)
    if (!ok) unlink(out)
  }
  rows
}

# ---- events used by combined Figures 3-8 ----
EVENTS <- file.path(RESULTS_ROOT, c(
  "Zimbabwe/Idai_2019", "Mozambique/Idai_2019", "Malawi/Idai_2019",
  "Mozambique/Kenneth_2019", "Mozambique/Desmond_2019", "Mozambique/Chalane_2020",
  "Madagascar/Belna_2019", "Madagascar/Chalane_2020",
  "Madagascar/Diane_2020", "Madagascar/Francisco_2020",
  "Zimbabwe/Chalane_2020", "Botswana/Chalane_2020"))

rows <- list()
for (ev in EVENTS) {
  if (!dir.exists(ev)) { cat(sprintf("  !! missing: %s\n", ev)); next }
  rows <- pub_event_panels(ev, rows)
}
man <- do.call(rbind, rows)
write.csv(man, file.path(dirname(OUTROOT), "manifest.csv"), row.names = FALSE)
cat(sprintf("\n[pub_panels] %d panels, %d with data -> %s\n",
            nrow(man), sum(man$has_data), OUTROOT))
