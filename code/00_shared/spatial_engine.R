# =============================================================================
# 00_shared/spatial_engine.R  —  Reusable per-event spatial anomaly engine.
# Defines: compute_event_anomalies(), draw_event_maps() with full Zimbabwe
# cartography (country outline, key cities, corridor, track, scale bar).
# Source AFTER config.R + functions.R. Set EVENT vars then call.
# =============================================================================

## ---- reference cities (lon, lat) for geographic context ----
## `label` curates which names are drawn; all points plotted, only flagged ones
## get a text label. Defaults to Zimbabwe; a runner overrides via:
##   CITIES <- COUNTRY_CITIES[[COUNTRY]]   (set before calling the draw_* funcs)
CITIES <- COUNTRY_CITIES[["Zimbabwe"]]

## ---- pretty window heading: "Baseline  (-14 to -8 d)" ----
pretty_window <- function(w) {
  nm <- c(baseline="Baseline", pre7="Pre-event", acute="Acute (storm)",
          early="Early recovery", recov2="Recovery 2", recov3="Recovery 3")
  sprintf("%s  (%+d to %+d d)", ifelse(is.na(nm[w]), w, nm[w]),
          WINDOWS[[w]][1], WINDOWS[[w]][2])
}

## ---- compute (or load cached) de-meaned anomaly grids for one event ----
## Returns list(anomd=named rasters "window signal", cover=named by window,
##              offset=per-signal baseline offset, tmpl=grid template)
compute_event_anomalies <- function(evdir, corridor, entry, event_year,
                                     clim_years, signals = c("sif","nirvr","phif"),
                                     recompute = FALSE) {
  mapdir <- file.path(evdir, "spatial_maps"); dir.create(mapdir, showWarnings = FALSE, recursive = TRUE)
  vcorr <- vect(corridor); bb <- st_bbox(corridor)
  tmpl <- rast(xmin = floor(bb["xmin"]*10)/10, xmax = ceiling(bb["xmax"]*10)/10,
               ymin = floor(bb["ymin"]*10)/10, ymax = ceiling(bb["ymax"]*10)/10,
               resolution = GRID_DEG, crs = "EPSG:4326")

  anom <- list(); cover <- list()
  for (w in names(WINDOWS)) {
    rels <- WINDOWS[[w]][1]:WINDOWS[[w]][2]
    ev <- collect_soundings(rels, event_year, entry, bb, corridor)
    cl <- collect_soundings(rels, clim_years, entry, bb, corridor)
    for (s in signals) {
      ge <- grid_field(ev, s, tmpl, vcorr); gc <- grid_field(cl, s, tmpl, vcorr)
      key <- paste(w, s)
      if (is.null(ge) || is.null(gc)) { anom[[key]] <- NULL; next }
      anom[[key]] <- ge$mean - gc$mean
      if (s == "sif") cover[[w]] <- ge$n
    }
  }
  ## baseline de-meaning
  offset <- sapply(signals, function(s) {
    a <- anom[[paste("baseline", s)]]; if (is.null(a)) return(0)
    v <- values(a); mean(v[is.finite(v)]) })
  anomd <- list()
  for (w in names(WINDOWS)) for (s in signals) {
    key <- paste(w, s); a <- anom[[key]]; if (is.null(a)) next
    ad <- a - offset[s]; anomd[[key]] <- ad
    writeRaster(ad, file.path(mapdir, sprintf("anomd_%s_%s.tif", s, w)), overwrite = TRUE)
  }
  list(anom = anom, anomd = anomd, cover = cover, offset = offset, tmpl = tmpl,
       bb = bb, vcorr = vcorr)
}

## ---- draw the 6 BER windows for one signal as a legible 2x3 grid ----
## Larger panels (vs the old 1x6 strip) so the anomaly field is actually
## visible; decluttered city labels; one wide colorbar beneath.
draw_event_maps <- function(res, signal, event_label, zim, corridor, seg,
                            mapdir, sig_lab, demeaned = TRUE,
                            event_title = event_label, short_lab = sig_lab) {
  store <- if (demeaned) res$anomd else res$anom
  wins <- names(WINDOWS)
  zext <- ext(vect(zim))                       # FULL country extent (shows location)
  xpad <- 0.05 * (zext[2] - zext[1]); ypad <- 0.04 * (zext[4] - zext[3])
  xlim <- c(zext[1] - xpad*0.3, zext[2] + xpad*1.4)
  ylim <- c(zext[3] - ypad, zext[4] + ypad)
  xmid <- mean(c(zext[1], zext[2]))
  lab_pos <- ifelse(CITIES$lon > xmid, 2, 4)   # E names left, W names right
  zmax <- max(abs(unlist(lapply(wins, function(w){
    a <- store[[paste(w, signal)]]; if (is.null(a)) return(NA)
    v <- values(a); max(abs(v[is.finite(v)]), na.rm = TRUE) }))), na.rm = TRUE)
  if (!is.finite(zmax) || zmax == 0) zmax <- 1
  brks <- seq(-zmax, zmax, length.out = 21)
  tag <- if (demeaned) "demeaned" else "raw"
  fn <- file.path(mapdir, sprintf("%s_%s_%s.png", event_label, toupper(signal), tag))
  png(fn, width = 1900, height = 1550, res = 170)
  ## 2 rows x 3 maps, then a full-width colorbar strip
  layout(matrix(c(1,2,3, 4,5,6, 7,7,7), nrow = 3, byrow = TRUE),
         heights = c(5, 5, 1.15))
  par(oma = c(0, 0, 4, 0))
  for (w in wins) {
    a <- store[[paste(w, signal)]]
    par(mar = c(1.2, 1.2, 2.6, 1.0))
    plot(st_geometry(zim), col = "grey94", border = "grey45", lwd = 1.3,
         main = pretty_window(w), cex.main = 1.15, font.main = 2,
         xlim = xlim, ylim = ylim, axes = FALSE)
    plot(st_geometry(corridor), col = "#ffffff", border = "steelblue", lwd = 1.4, add = TRUE)
    if (!is.null(a)) {
      plot(a, col = DIV_PAL(20), breaks = brks, add = TRUE, legend = FALSE)
    } else {
      cc <- st_coordinates(st_centroid(st_union(corridor)))
      text(cc[1], cc[2], "no data", col = "red", cex = 1.3, font = 2)
    }
    plot(st_geometry(corridor), border = "steelblue", lwd = 1.4, add = TRUE)
    plot(st_geometry(zim), border = "grey45", lwd = 1.3, add = TRUE)
    if (!is.null(seg)) plot(st_geometry(seg), col = "black", lwd = 3.2, add = TRUE)
    points(CITIES$lon, CITIES$lat, pch = 21, bg = "black", col = "white", cex = 1.0)
    lab <- CITIES$label
    text(CITIES$lon[lab], CITIES$lat[lab], CITIES$name[lab],
         pos = lab_pos[lab], cex = 0.8, col = "grey10", font = 2, xpd = NA)
    terra::sbar(200, xy = "bottomleft", type = "bar", below = "km", cex = 0.7, divs = 2)
  }
  ## wide colorbar
  par(mar = c(3.4, 14, 1.2, 14))
  z <- seq(-zmax, zmax, length.out = 200)
  image(z, 1, matrix(z, ncol = 1), col = DIV_PAL(200), axes = FALSE, xlab = "", ylab = "")
  axis(1, cex.axis = 0.95); box()
  mtext("red = suppression          green = enhancement", side = 1, line = 2.4, cex = 0.95)
  mtext(sprintf("%s   |   %s   (%s)", event_title, short_lab,
                if (demeaned) "de-meaned anomaly" else "raw anomaly"),
        outer = TRUE, cex = 1.3, font = 2, line = 1.0)
  dev.off()
  cat("wrote:", fn, "\n")
  invisible(fn)
}

## ---- combined triplet: 3 signal rows x 6 windows, one figure ----
draw_triplet <- function(res, event_title, event_label, zim, corridor, seg, mapdir,
                         signals = c("sif","nirvr","phif"),
                         short = c(sif = "SIF", nirvr = "NIRvR", phif = "Phi_F"),
                         demeaned = TRUE) {
  store <- if (demeaned) res$anomd else res$anom
  wins <- names(WINDOWS)
  zext <- ext(vect(zim))
  xpad <- 0.06 * (zext[2] - zext[1]); ypad <- 0.04 * (zext[4] - zext[3])
  xlim <- c(zext[1] - xpad*0.4, zext[2] + xpad*1.6); ylim <- c(zext[3] - ypad, zext[4] + ypad)
  tag <- if (demeaned) "demeaned" else "raw"
  fn <- file.path(mapdir, sprintf("%s_triplet_%s.png", event_label, tag))
  png(fn, width = 2600, height = 1250, res = 150)
  layout(matrix(1:21, nrow = 3, byrow = TRUE), widths = c(rep(1,6), 0.32))
  par(oma = c(1, 2.2, 3, 0))
  for (s in signals) {
    zmax <- max(abs(unlist(lapply(wins, function(w){
      a <- store[[paste(w, s)]]; if (is.null(a)) return(NA)
      v <- values(a); max(abs(v[is.finite(v)]), na.rm = TRUE) }))), na.rm = TRUE)
    if (!is.finite(zmax) || zmax == 0) zmax <- 1
    brks <- seq(-zmax, zmax, length.out = 21)
    first_row <- identical(s, signals[1])
    for (wi in seq_along(wins)) {
      w <- wins[wi]; a <- store[[paste(w, s)]]
      par(mar = c(0.4, 0.4, if (first_row) 2 else 0.4, 0.4))
      plot(st_geometry(zim), col = "grey94", border = "grey45", lwd = 1,
           main = if (first_row) pretty_window(w) else "",
           cex.main = 1.0, font.main = 2, xlim = xlim, ylim = ylim, axes = FALSE)
      plot(st_geometry(corridor), col = "#ffffff", border = "steelblue", lwd = 1, add = TRUE)
      if (!is.null(a)) plot(a, col = DIV_PAL(20), breaks = brks, add = TRUE, legend = FALSE)
      else { cc <- st_coordinates(st_centroid(st_union(corridor)))
             text(cc[1], cc[2], "no\ndata", col = "red", cex = 0.85, font = 2) }
      plot(st_geometry(corridor), border = "steelblue", lwd = 1, add = TRUE)
      plot(st_geometry(zim), border = "grey45", lwd = 1, add = TRUE)
      if (!is.null(seg)) plot(st_geometry(seg), col = "black", lwd = 2.5, add = TRUE)
      points(CITIES$lon, CITIES$lat, pch = 21, bg = "black", col = "white", cex = 0.55)
      if (wi == 1) mtext(short[s], side = 2, line = 0.4, cex = 0.95, font = 2)
    }
    ## per-signal colorbar (column 7)
    par(mar = c(1.2, 0.4, if (first_row) 2 else 1.2, 2.6))
    z <- seq(-zmax, zmax, length.out = 200)
    image(1, z, matrix(z, nrow = 1), col = DIV_PAL(200), axes = FALSE, xlab = "", ylab = "")
    axis(4, cex.axis = 0.65, las = 1); box()
  }
  mtext(sprintf("%s   |   SIF  /  NIRvR  /  Phi_F   (%s;  red = suppression,  green = enhancement)",
                event_title, if (demeaned) "de-meaned" else "raw"),
        outer = TRUE, cex = 1.2, font = 2, line = 0.6)
  dev.off(); cat("wrote:", fn, "\n"); invisible(fn)
}

## ---- coverage figure ----
draw_coverage <- function(res, event_label, zim, corridor, mapdir) {
  zext <- ext(vect(zim))
  fn <- file.path(mapdir, sprintf("%s_coverage_per_window.png", event_label))
  png(fn, width = 2500, height = 560, res = 150)
  par(mfrow = c(1,6), mar = c(2,2,3,3), oma = c(0,0,3,0))
  for (w in names(WINDOWS)) {
    plot(st_geometry(zim), col = "grey94", border = "grey45", main = pretty_window(w),
         cex.main = 1.0, font.main = 2, xlim = c(zext[1], zext[2]), ylim = c(zext[3], zext[4]))
    plot(st_geometry(corridor), border = "steelblue", add = TRUE)
    if (!is.null(res$cover[[w]])) {
      plot(res$cover[[w]], add = TRUE, legend = TRUE)
      plot(st_geometry(corridor), border = "steelblue", add = TRUE)
    } else {
      cc <- st_coordinates(st_centroid(st_union(corridor)))
      text(cc[1], cc[2], "no\ndata", col = "red", font = 2)
    }
  }
  mtext(sprintf("%s   |   valid SIF soundings per %.2f deg cell (coverage diagnostic)",
                event_label, GRID_DEG), outer = TRUE, cex = 1.15, font = 2)
  dev.off()
  cat("wrote:", fn, "\n"); invisible(fn)
}

message("[spatial_engine] loaded: compute_event_anomalies, draw_event_maps, draw_triplet, draw_coverage")
