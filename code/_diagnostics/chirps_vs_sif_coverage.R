# CHIRPS corridor rainfall: daily mean precip in each event corridor across the
# BER span, plus 60-day antecedent PRCPTOT. Overlaid against SIF valid-day counts
# to demonstrate that empty SIF windows coincide with heavy rainfall (cloud).
suppressMessages({library(sf); library(terra); library(ncdf4)})
sf::sf_use_s2(TRUE)
chirps_root <- file.path(Sys.getenv("CYCLONE_SIF_DATA", "data_raw"), "CHIRPS")
sif_root    <- file.path(Sys.getenv("CYCLONE_SIF_DATA", "data_raw"), "TROPOSIF")
outroot     <- Sys.getenv("CYCLONE_SIF_OUT", Sys.getenv("CYCLONE_SIF_OUT", "derived_data"))
SZA_MAX<-85; TOA_LO<-20; TOA_HI<-200

events <- list(
  IDAI    = list(entry=as.Date("2019-03-15"), dir="IDAI_2019"),
  CHALANE = list(entry=as.Date("2020-12-30"), dir="CHALANE_2020"),
  ELOISE  = list(entry=as.Date("2021-01-23"), dir="ELOISE_2021")
)

chirps_path <- function(d) {
  f <- file.path(chirps_root, format(d,"%Y"),
                 sprintf("chirps-v2.0.%s.tif.gz", format(d,"%Y.%m.%d")))
  if (file.exists(f)) paste0("/vsigzip/", f) else NA
}
corr_rain <- function(d, vc) {  # mean corridor rainfall for date d
  p <- chirps_path(d); if (is.na(p)) return(NA)
  r <- tryCatch(rast(p), error=function(e) NULL); if (is.null(r)) return(NA)
  r <- crop(r, vc); r[r < 0] <- NA
  m <- terra::extract(r, vc, fun=mean, na.rm=TRUE, ID=FALSE)
  as.numeric(m[1,1])
}
# SIF valid-day count for date d in corridor (strict QC, cf<0.02)
sif_n <- function(d, corridor, bb) {
  f <- file.path(sif_root, format(d,"%Y"), sprintf("TROPOSIF_L2B_%s.nc", format(d,"%Y-%m-%d")))
  if (!file.exists(f)) return(0)
  nc<-nc_open(f); on.exit(nc_close(nc))
  lat<-ncvar_get(nc,"PRODUCT/latitude");lon<-ncvar_get(nc,"PRODUCT/longitude")
  keep<-which(lon>=bb["xmin"]&lon<=bb["xmax"]&lat>=bb["ymin"]&lat<=bb["ymax"]); if(!length(keep)) return(0)
  g<-function(p) ncvar_get(nc,p)[keep]
  cf<-g("PRODUCT/SUPPORT_DATA/INPUT_DATA/cloud_fraction_L2");sza<-g("PRODUCT/SUPPORT_DATA/GEOLOCATIONS/solar_zenith_angle")
  nrd<-g("PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/Mean_TOA_RAD_743");sif<-g("PRODUCT/SIF_Corr_743")
  df<-data.frame(lon=lon[keep],lat=lat[keep],sif=sif,cf=cf,sza=sza,nirrad=nrd)
  pin<-st_within(st_as_sf(df,coords=c("lon","lat"),crs=4326),corridor,sparse=FALSE)[,1];df<-df[pin,,drop=FALSE]
  if(!nrow(df)) return(0)
  sum(df$cf<0.02 & df$sza<SZA_MAX & df$nirrad>=TOA_LO & df$nirrad<=TOA_HI & is.finite(df$sif))
}

windows <- list(baseline=c(-14,-8),pre7=c(-7,-1),acute=c(0,6),early=c(7,13),recov2=c(14,20),recov3=c(21,27))
summ_all <- list()
for (nm in names(events)) {
  ev<-events[[nm]]
  corridor <- st_read(file.path(outroot, ev$dir, "corridor_zim.gpkg"), quiet=TRUE) |> st_union()
  vc <- vect(corridor); bb <- st_bbox(corridor)
  rel <- (-14):27
  cat("\n######", nm, "- reading CHIRPS + SIF coverage ######\n")
  rain <- sapply(rel, function(r) corr_rain(ev$entry+r, vc))
  nsif <- sapply(rel, function(r) sif_n(ev$entry+r, corridor, bb))
  # 60-day antecedent PRCPTOT ending day before baseline (rel -15)
  ant <- sum(sapply(0:59, function(k) corr_rain(ev$entry-15-k, vc)), na.rm=TRUE)
  df <- data.frame(rel=rel, date=ev$entry+rel, rain_mm=round(rain,2), sif_n=nsif)
  write.csv(df, file.path(outroot, ev$dir, "chirps_sif_daily.csv"), row.names=FALSE)
  # window summary
  ws <- do.call(rbind, lapply(names(windows), function(w){
    s<-df[df$rel>=windows[[w]][1]&df$rel<=windows[[w]][2],]
    data.frame(event=nm,window=w,PRCPTOT=round(sum(s$rain_mm,na.rm=TRUE),1),
               RX1day=round(max(s$rain_mm,na.rm=TRUE),1),
               sif_days=sum(s$sif_n>0))
  }))
  ws$antecedent60d <- round(ant,1)
  print(ws, row.names=FALSE)
  summ_all[[nm]] <- ws

  # plot: rainfall bars + SIF coverage points, twin axis
  png(file.path(outroot, ev$dir, "chirps_vs_sif_coverage.png"), width=1500, height=850, res=150)
  par(mar=c(4,4.5,3,4.5))
  barplot(df$rain_mm, names.arg=df$rel, col="#4a90d9", border=NA,
          xlab="Days from entry", ylab="Corridor mean rainfall (mm/day)",
          main=sprintf("%s — CHIRPS rainfall vs SIF observability", nm))
  abline(v=which(rel==0)*1.2-0.5, col="red", lty=2, lwd=2)
  par(new=TRUE)
  plot(seq_along(rel), df$sif_n, type="b", pch=19, col="darkorange", lwd=2,
       axes=FALSE, xlab="", ylab="")
  axis(4, col="darkorange", col.axis="darkorange")
  mtext("Valid SIF soundings (cf<0.02)", side=4, line=3, col="darkorange")
  legend("topright", c("rainfall (mm/d)","valid SIF soundings"),
         col=c("#4a90d9","darkorange"), pch=c(15,19), bty="n")
  dev.off()
}
final <- do.call(rbind, summ_all)
write.csv(final, file.path(outroot, "chirps_window_summary.csv"), row.names=FALSE)
cat("\nDONE. chirps_window_summary.csv + per-event CSV/PNG written.\n")
