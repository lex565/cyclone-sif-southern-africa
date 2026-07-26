# =============================================================================
# 00_shared/clean_figures.R — publication-clean figure pair for ANY event, in
# the locked reference style (discrete 7-class %-of-normal bar, framed serif
# panels, shared horizontal colour bar, north arrow, minimal labels).
#   A: SIF across 3 windows (Before / Storm week / Weeks after)
#   B: SIF / NIRvR / PhiF for the storm week (structure vs physiology)
# Blackout / missing windows render as honest "no data" panels.
# Usage:  source this file, then  clean_event_pair(evdir)   [evdir absolute]
# Output: <evdir>/clean_figures/<LABEL>_CLEAN_{A_SIF_time,B_triplet_acute}.png
# =============================================================================
suppressMessages({library(terra); library(sf)})
if (!exists("RESULTS_ROOT")) source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))

# ---- display options ----
.SMOOTH      <- TRUE   # display-only bilinear smoothing (gaps preserved as NA)
.SMOOTH_FACT <- 8      # disaggregation factor; stats are ALWAYS on native grid
# ---- locked colour scheme ----
.BRK <- c(-200,-40,-20,-5,5,20,40,200)
.COL <- c("#8c2d04","#d95f0e","#f6a563","#f7f7f7","#a6d96a","#5aae61","#1a7e3f")
.LAB <- c("< -40","-40\n-20","-20\n-5","-5..+5\n(none)","+5\n+20","+20\n+40","> +40")
.CBT <- "Change relative to normal  (%)"

.parse_label <- function(evdir) {
  label <- basename(evdir); parent <- basename(dirname(evdir))
  known_dirs <- c("Zimbabwe","Malawi","Botswana","Mozambique","Madagascar","South_Africa")
  if (parent %in% known_dirs) {                 # NESTED layout: Country/Storm_Year
    parts <- strsplit(label, "_")[[1]]; n <- length(parts)
    year <- if (grepl("^[0-9]{4}$", parts[n])) parts[n] else "?"
    country <- parent; storm <- parts[1]
  } else {                                       # FLAT label: PREFIX_STORM_YEAR
    parts <- strsplit(label, "_")[[1]]; n <- length(parts)
    year <- if (grepl("^[0-9]{4}$", parts[n])) parts[n] else "?"
    known <- c(MOZAMBIQUE="Mozambique", MADAGASCAR="Madagascar", SOUTH="South_Africa",
               BOTSWANA="Botswana", MALAWI="Malawi")
    if (parts[1] %in% names(known)) {
      country <- known[[parts[1]]]; storm <- if (parts[1]=="SOUTH") parts[3] else parts[2]
    } else { country <- "Zimbabwe"; storm <- parts[1] }
  }
  storm <- paste0(toupper(substr(storm,1,1)), tolower(substr(storm,2,nchar(storm))))
  list(country=country, storm=storm, year=year)
}

.month_label <- function(evdir, year) {
  f <- file.path(evdir, "event_vs_climatology.csv")
  if (file.exists(f)) {
    d <- read.csv(f); z <- d[d$rel==0, "date"][1]
    if (!is.na(z)) return(format(as.Date(z), "%b %Y"))
  }
  year
}

.add_north <- function() {
  u <- par("usr"); x <- u[2]-(u[2]-u[1])*0.07; y0 <- u[3]+(u[4]-u[3])*0.80
  arrows(x,y0,x,y0+(u[4]-u[3])*0.13, length=0.10, lwd=2.6); text(x,y0+(u[4]-u[3])*0.18,"N",font=2,cex=1.5)
}
.empty_panel <- function(title, cbb) {
  par(mar=c(0.4,0.4,4.0,0.4))
  plot(NA, xlim=c(cbb["xmin"],cbb["xmax"]), ylim=c(cbb["ymin"],cbb["ymax"]), xlab="",ylab="",axes=FALSE,asp=1)
  box(lwd=1.6); title(main=title, font.main=2, cex.main=1.55, line=0.4)
  text(mean(cbb[c("xmin","xmax")]), mean(cbb[c("ymin","ymax")]),
       "no data\n(cloud blackout)", col="grey45", font=3, cex=1.5)
}
.draw_map <- function(r, title, cbb, boundary, segment, north=FALSE) {
  if (is.null(r)) { .empty_panel(title, cbb); return(invisible()) }
  r <- clamp(r, min(.BRK), max(.BRK), values=TRUE)
  if (.SMOOTH) r <- disagg(r, .SMOOTH_FACT, method="bilinear")  # display only; NA gaps kept
  par(mar=c(0.4,0.4,4.0,0.4))
  plot(NA, xlim=c(cbb["xmin"],cbb["xmax"]), ylim=c(cbb["ymin"],cbb["ymax"]), xlab="",ylab="",axes=FALSE,asp=1)
  image(r, breaks=.BRK, col=.COL, add=TRUE, maxcell=5e6)
  if(!is.null(boundary)) plot(st_geometry(boundary), add=TRUE, border="grey25", lwd=1.3)
  if(!is.null(segment))  plot(st_geometry(segment), add=TRUE, col="black", lwd=3.2)
  box(lwd=1.6); title(main=title, font.main=2, cex.main=1.55, line=0.4); if(north) .add_north()
}
.draw_cbar <- function() {
  par(mar=c(3.2,3,3.2,3)); n <- length(.COL)
  plot.new(); plot.window(xlim=c(0,n), ylim=c(0,1))
  rect(0:(n-1),0.45,1:n,1.00, col=.COL, border="grey30", lwd=0.9)
  # single-line tick labels at the boundaries BETWEEN colour cells (no stacking -> no clipping)
  brk_in <- .BRK[2:(length(.BRK)-1)]                 # -40,-20,-5,5,20,40
  labs <- sprintf("%+d", brk_in)
  segments(1:(n-1), 0.45, 1:(n-1), 0.33, col="grey30", lwd=0.9)
  text(1:(n-1), 0.16, labs, cex=1.3)
  mtext(.CBT, side=3, line=0.4, font=2, cex=1.75)
}

clean_event_pair <- function(evdir) {
  label <- basename(evdir); meta <- .parse_label(evdir)
  sm <- file.path(evdir, "spatial_maps")
  outd <- file.path(evdir, "clean_figures"); dir.create(outd, showWarnings=FALSE)
  dlab <- .month_label(evdir, meta$year)
  cat(sprintf("  clean figs: %s (%s %s, %s)\n", label, meta$storm, meta$country, dlab))

  # geometry
  cpath <- if (file.exists(file.path(evdir,"corridor.gpkg"))) file.path(evdir,"corridor.gpkg") else file.path(evdir,"corridor_zim.gpkg")
  corr <- tryCatch(st_union(st_read(cpath, quiet=TRUE)), error=function(e) NULL)
  if (is.null(corr)) { cat("   !! no corridor; skip\n"); return(invisible()) }
  cbb <- st_bbox(corr)
  boundary <- tryCatch(st_union(st_make_valid(st_read(country_shp(meta$country), quiet=TRUE))), error=function(e) NULL)
  segf <- file.path(evdir,"segment.gpkg")
  if (!file.exists(segf) && label=="IDAI_2019") segf <- file.path(RESULTS_ROOT,"idai2019_zim_segment.gpkg")
  segment <- if (file.exists(segf)) tryCatch(st_read(segf, quiet=TRUE), error=function(e) NULL) else NULL

  # baseline levels for % conversion
  evc <- tryCatch(read.csv(file.path(evdir,"event_vs_climatology.csv")), error=function(e) NULL)
  if (is.null(evc)) { cat("   !! no event_vs_climatology; skip\n"); return(invisible()) }
  br <- evc[evc$rel>=-14 & evc$rel<=-8, ]
  lvl <- c(sif=mean(br$sif.clim,na.rm=TRUE), nirvr=mean(br$nirvr.clim,na.rm=TRUE), phif=mean(br$phif.clim,na.rm=TRUE))
  # actual calendar date range for a window's relative-day span (for friendly panel titles)
  evc$date <- as.Date(evc$date)
  drange <- function(lo, hi) {
    s <- evc$date[evc$rel >= lo & evc$rel <= hi]; s <- s[!is.na(s)]
    if (!length(s)) "" else sprintf("%s – %s", format(min(s), "%d %b"), format(max(s), "%d %b %Y"))
  }

  pct <- function(sig, win) {
    f <- file.path(sm, sprintf("anomd_%s_%s.tif", sig, win))
    if (!file.exists(f) || !is.finite(lvl[[sig]]) || lvl[[sig]]==0) return(NULL)
    rast(f) / lvl[[sig]] * 100
  }

  # ---- A : SIF across time ----
  wkeys <- c("pre7","acute","recov3")
  wttl  <- c(sprintf("Before the storm\n%s",  drange(-7,-1)),
             sprintf("Storm week\n%s",        drange(0, 6)),
             sprintf("3–4 weeks after\n%s",   drange(21,27)))
  png(file.path(outd, sprintf("%s_CLEAN_A_SIF_time.png", label)), width=1850, height=1040, res=160)
  par(family="serif", oma=c(0,0,3.2,0)); layout(matrix(c(1,2,3,4,4,4),2,byrow=TRUE), heights=c(4.0,1.7))
  for (i in seq_along(wkeys)) .draw_map(pct("sif", wkeys[i]), wttl[i], cbb, boundary, segment, north=(i==3))
  .draw_cbar(); mtext(sprintf("Cyclone %s (%s) — SIF response over time", meta$storm, dlab),
                      side=3, outer=TRUE, line=0.6, font=2, cex=2.0)
  dev.off()

  # ---- B : triplet, storm week ----
  sm2 <- c(sif="SIF (photosynthesis glow)", nirvr="NIRvR (canopy structure)", phif="ΦF (efficiency)")
  png(file.path(outd, sprintf("%s_CLEAN_B_triplet_acute.png", label)), width=1850, height=1040, res=160)
  par(family="serif", oma=c(0,0,3.2,0)); layout(matrix(c(1,2,3,4,4,4),2,byrow=TRUE), heights=c(4.0,1.7))
  for (i in seq_along(sm2)) .draw_map(pct(names(sm2)[i], "acute"), unname(sm2)[i], cbb, boundary, segment, north=(i==3))
  .draw_cbar(); mtext(sprintf("Cyclone %s (%s) — structure vs. physiology in the storm week", meta$storm, dlab),
                      side=3, outer=TRUE, line=0.6, font=2, cex=1.9)
  dev.off()
  invisible(outd)
}

message("[clean_figures] loaded: clean_event_pair(evdir)")
