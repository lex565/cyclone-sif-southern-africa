# =============================================================================
# clean_figure_prototype.R — IDAI prototypes in the reference (clean) style,
# UNIFIED scheme: everything expressed as % of that signal's normal baseline,
# one shared 7-class discrete colour bar (breaks ±5/±20/±40 — the ±5/±20 match
# the §3.7 classification thresholds; ±40 adds a 'very strong' tier).
#   A: SIF across 3 time windows (Before / Storm week / Weeks after)
#   B: SIF / NIRvR / PhiF for the storm week (structure vs physiology)
# =============================================================================
suppressMessages({library(terra); library(sf)})
RR <- Sys.getenv("CYCLONE_SIF_OUT", Sys.getenv("CYCLONE_SIF_OUT", "derived_data")); ev <- file.path(RR,"IDAI_2019"); sm <- file.path(ev,"spatial_maps")
out <- file.path(RR,"_FIGURE_PROTOTYPES"); dir.create(out, showWarnings=FALSE)

boundary <- tryCatch(st_read(file.path(RR,"zimbabwe_boundary.gpkg"), quiet=TRUE), error=function(e) NULL)
segment  <- tryCatch(st_read(file.path(RR,"idai2019_zim_segment.gpkg"), quiet=TRUE), error=function(e) NULL)
corr <- st_read(file.path(ev,"corridor_zim.gpkg"), quiet=TRUE) |> st_union(); cbb <- st_bbox(corr)

evc <- read.csv(file.path(ev,"event_vs_climatology.csv")); br <- evc[evc$rel>=-14 & evc$rel<=-8,]
lvl <- c(sif=mean(br$sif.clim,na.rm=TRUE), nirvr=mean(br$nirvr.clim,na.rm=TRUE), phif=mean(br$phif.clim,na.rm=TRUE))

# ---- unified 7-class % scheme ----
BRK <- c(-200,-40,-20,-5,5,20,40,200)
COL <- c("#8c2d04","#d95f0e","#f6a563","#f7f7f7","#a6d96a","#5aae61","#1a7e3f")
LAB <- c("< -40","-40\n-20","-20\n-5","-5..+5\n(none)","+5\n+20","+20\n+40","> +40")
CBTITLE <- "Change relative to normal  (%)"

add_north <- function() {
  u <- par("usr"); x <- u[2]-(u[2]-u[1])*0.07; y0 <- u[3]+(u[4]-u[3])*0.80
  arrows(x,y0,x,y0+(u[4]-u[3])*0.13, length=0.08, lwd=2); text(x,y0+(u[4]-u[3])*0.17,"N",font=2)
}
draw_map <- function(r, title, north=FALSE) {
  r <- clamp(r, min(BRK), max(BRK), values=TRUE)
  par(mar=c(0.4,0.4,2.0,0.4))
  plot(NA, xlim=c(cbb["xmin"],cbb["xmax"]), ylim=c(cbb["ymin"],cbb["ymax"]), xlab="",ylab="",axes=FALSE,asp=1)
  image(r, breaks=BRK, col=COL, add=TRUE, maxcell=5e5)
  if(!is.null(boundary)) plot(st_geometry(boundary), add=TRUE, border="grey25", lwd=0.8)
  if(!is.null(segment))  plot(st_geometry(segment), add=TRUE, col="black", lwd=2.2)
  box(lwd=1.4); title(main=title, font.main=2, cex.main=1.15, line=0.4); if(north) add_north()
}
draw_cbar <- function() {
  par(mar=c(3.8,3,2.4,3)); n <- length(COL)
  plot.new(); plot.window(xlim=c(0,n), ylim=c(0,1))
  rect(0:(n-1),0.50,1:n,1.00, col=COL, border="grey30", lwd=0.7)
  text((0:(n-1))+0.5, 0.16, LAB, cex=0.82); mtext(CBTITLE, side=3, line=0.3, font=2, cex=1.2)
}
pct <- function(sig, win) rast(file.path(sm, sprintf("anomd_%s_%s.tif", sig, win))) / lvl[[sig]] * 100

# ===== A : SIF across time =====
wm <- c(pre7="Before the storm", acute="Storm week", recov3="3–4 weeks after")
png(file.path(out,"IDAI_PROTO_A_SIF_time.png"), width=1850, height=950, res=160)
par(family="serif", oma=c(0,0,2.4,0)); layout(matrix(c(1,2,3,4,4,4),2,byrow=TRUE), heights=c(4.0,1.5))
for(i in seq_along(wm)) draw_map(pct("sif", names(wm)[i]), unname(wm)[i], north=(i==3))
draw_cbar(); mtext("Cyclone Idai (Mar 2019) — SIF response over time", side=3, outer=TRUE, line=0.3, font=2, cex=1.4)
dev.off(); cat("wrote A\n")

# ===== B : 3 signals, storm week =====
sm2 <- c(sif="SIF (photosynthesis glow)", nirvr="NIRvR (canopy structure)", phif="ΦF (efficiency)")
png(file.path(out,"IDAI_PROTO_B_triplet_acute.png"), width=1850, height=950, res=160)
par(family="serif", oma=c(0,0,2.4,0)); layout(matrix(c(1,2,3,4,4,4),2,byrow=TRUE), heights=c(4.0,1.5))
for(i in seq_along(sm2)) draw_map(pct(names(sm2)[i], "acute"), unname(sm2)[i], north=(i==3))
draw_cbar(); mtext("Cyclone Idai (Mar 2019) — structure vs. physiology in the storm week",
                   side=3, outer=TRUE, line=0.3, font=2, cex=1.35)
dev.off(); cat("wrote B\n"); cat("DONE ->", out, "\n")
