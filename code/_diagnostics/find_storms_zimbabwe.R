suppressMessages({library(sf)})
ib <- file.path(Sys.getenv("CYCLONE_SIF_DATA", "data_raw"), "IBTracs/Extracted/IBTrACS.SI.list.v04r01.points.shp")
zim_shp <- file.path(Sys.getenv("CYCLONE_SIF_DATA", "data_raw"), "Ecological Regions/By_Country/Ecoregions2017_Zimbabwe.shp")
p <- st_read(ib, quiet=TRUE)
zim <- st_read(zim_shp, quiet=TRUE) |> st_make_valid()
zim_nat <- st_union(zim)

# storms of interest
targets <- c("CHALANE","ELOISE","IDAI")
for (nm in targets) {
  s <- p[toupper(p$NAME)==nm, ]
  if (!nrow(s)) { cat(nm, ": not found\n"); next }
  cat("\n==========", nm, "==========\n")
  for (sid in unique(s$SID)) {
    ss <- s[s$SID==sid, ]
    ss$ISO_TIME <- as.POSIXct(ss$ISO_TIME, tz="UTC")
    ss <- ss[order(ss$ISO_TIME),]
    # does it intersect Zimbabwe?
    inside <- st_within(ss, zim_nat, sparse=FALSE)[,1]
    nin <- sum(inside)
    entry <- if (nin>0) format(min(ss$ISO_TIME[inside]),"%Y-%m-%d %H:%M") else "—"
    w <- suppressWarnings(as.numeric(ss$WMO_WIND)); if(all(is.na(w))) w<-suppressWarnings(as.numeric(ss$REU_WIND))
    cat(sprintf("  SID=%s season=%s pts=%d in-Zim=%d entry=%s maxwind=%s\n",
                sid, ss$SEASON[1], nrow(ss), nin, entry,
                ifelse(is.finite(max(w,na.rm=TRUE)), round(max(w,na.rm=TRUE)), "NA")))
  }
}
