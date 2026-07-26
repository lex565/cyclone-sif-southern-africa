# =============================================================================
# Parameterized per-event pipeline (R): track corridor -> SIF/NIRvR/PhiF triplet
# -> STABILIZED climatology (+/-4 day pooling) -> anomalies + recovery + panels.
# Usage: Rscript pipeline_event.R <NAME> <SID> <ENTRY yyyy-mm-dd> <EVENT_YEAR>
# Output -> <derived_data>/<NAME>_<YEAR>/
# =============================================================================
suppressMessages({library(sf); library(ncdf4)})
sf::sf_use_s2(TRUE)

args <- commandArgs(trailingOnly = TRUE)
NAME  <- args[1]; SID <- args[2]
ENTRY <- as.Date(args[3]); EVENT_YEAR <- as.integer(args[4])
POOL  <- 4                                   # +/- days for climatology pooling
CLIM_YEARS <- setdiff(2018:2021, EVENT_YEAR) # SIF coverage = 2018-2021

ib_pts  <- file.path(Sys.getenv("CYCLONE_SIF_DATA", "data_raw"), "IBTracs/Extracted/IBTrACS.SI.list.v04r01.points.shp")
zim_shp <- file.path(Sys.getenv("CYCLONE_SIF_DATA", "data_raw"), "Ecological Regions/By_Country/Ecoregions2017_Zimbabwe.shp")
sif_root<- file.path(Sys.getenv("CYCLONE_SIF_DATA", "data_raw"), "TROPOSIF")
outroot <- Sys.getenv("CYCLONE_SIF_OUT", Sys.getenv("CYCLONE_SIF_OUT", "derived_data"))
outdir  <- file.path(outroot, sprintf("%s_%d", NAME, EVENT_YEAR))
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

CF_MAX<-0.02; SZA_MAX<-85; TOA_LO<-20; TOA_HI<-200; RED_I<-1; NIR_I<-7
BUFFER_KM <- 200
windows <- list(baseline=c(-14,-8), pre7=c(-7,-1), acute=c(0,6),
                early=c(7,13), recov2=c(14,20), recov3=c(21,27))

cat(sprintf("=== %s %d (SID %s) entry %s | clim yrs %s | pooling +/-%d d ===\n",
            NAME, EVENT_YEAR, SID, ENTRY, paste(CLIM_YEARS,collapse=","), POOL))

## ---- 1. corridor (track x Zimbabwe, 200 km, equal-area buffer) ----
pts <- st_read(ib_pts, quiet=TRUE); s <- pts[pts$SID==SID,]
s$ISO_TIME <- as.POSIXct(s$ISO_TIME, tz="UTC"); s <- s[order(s$ISO_TIME),]
track <- st_cast(st_combine(s),"LINESTRING"); st_crs(track) <- 4326
zim <- st_union(st_make_valid(st_read(zim_shp, quiet=TRUE)))
ctr <- st_coordinates(st_centroid(st_union(s)))
laea <- sprintf("+proj=laea +lat_0=%f +lon_0=%f +datum=WGS84 +units=m +no_defs", ctr[2], ctr[1])
corridor <- st_intersection(st_buffer(st_transform(track,laea), BUFFER_KM*1000),
                            st_transform(zim,laea)) |> st_transform(4326) |> st_union()
st_write(st_sf(geometry=corridor), file.path(outdir,"corridor_zim.gpkg"),
         delete_dsn=TRUE, quiet=TRUE)
bb <- st_bbox(corridor)
cat(sprintf("corridor bbox lon %.2f..%.2f lat %.2f..%.2f\n",
            bb["xmin"],bb["xmax"],bb["ymin"],bb["ymax"]))

## ---- 2. daily corridor-mean extractor (+ optional per-sounding return) ----
day_means <- function(d, return_pts=FALSE) {
  f <- file.path(sif_root, format(d,"%Y"), sprintf("TROPOSIF_L2B_%s.nc", format(d,"%Y-%m-%d")))
  if (!file.exists(f)) return(NULL)
  nc <- nc_open(f); on.exit(nc_close(nc))
  lat <- ncvar_get(nc,"PRODUCT/latitude"); lon <- ncvar_get(nc,"PRODUCT/longitude")
  keep <- which(lon>=bb["xmin"]&lon<=bb["xmax"]&lat>=bb["ymin"]&lat<=bb["ymax"])
  if(!length(keep)) return(if(return_pts) NULL else c(n=0,sif=NA,nirvr=NA,phif=NA))
  g <- function(p) ncvar_get(nc,p)[keep]
  sif<-g("PRODUCT/SIF_Corr_743"); cf<-g("PRODUCT/SUPPORT_DATA/INPUT_DATA/cloud_fraction_L2")
  sza<-g("PRODUCT/SUPPORT_DATA/GEOLOCATIONS/solar_zenith_angle")
  nrd<-g("PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/Mean_TOA_RAD_743")
  toa<-ncvar_get(nc,"PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/TOA_RFL")[,keep,drop=FALSE]
  red<-toa[RED_I,]; nir<-toa[NIR_I,]
  df<-data.frame(lon=lon[keep],lat=lat[keep],sif=sif,cf=cf,sza=sza,nirrad=nrd,red=red,nir=nir)
  pin<-st_within(st_as_sf(df,coords=c("lon","lat"),crs=4326),corridor,sparse=FALSE)[,1]
  df<-df[pin,,drop=FALSE]
  if(!nrow(df)) return(if(return_pts) NULL else c(n=0,sif=NA,nirvr=NA,phif=NA))
  ndvi<-(df$nir-df$red)/(df$nir+df$red); nirvr<-ndvi*df$nirrad
  ok<-df$cf<CF_MAX&df$sza<SZA_MAX&df$nirrad>=TOA_LO&df$nirrad<=TOA_HI&
      is.finite(df$sif)&is.finite(nirvr)&nirvr>0&ndvi>0.1
  if(!any(ok)) return(if(return_pts) NULL else c(n=0,sif=NA,nirvr=NA,phif=NA))
  if(return_pts){ d2<-df[ok,]; d2$nirvr<-nirvr[ok]; d2$phif<-df$sif[ok]/nirvr[ok]; return(d2) }
  c(n=sum(ok),sif=mean(df$sif[ok]),nirvr=mean(nirvr[ok]),phif=mean(df$sif[ok]/nirvr[ok]))
}

## ---- 3. event-year daily series across full BER span ----
rel_range <- min(sapply(windows,`[`,1)):max(sapply(windows,`[`,2))
evt <- do.call(rbind, lapply(rel_range, function(r){
  d<-ENTRY+r; m<-day_means(d); if(is.null(m)) m<-c(n=0,sif=NA,nirvr=NA,phif=NA)
  data.frame(rel=r,date=d,n=m["n"],sif=m["sif"],nirvr=m["nirvr"],phif=m["phif"])
}))

## ---- 4. STABILIZED climatology: for each rel-day, pool +/-POOL days x clim years ----
clim_for_rel <- function(r){
  vals <- list(sif=c(),nirvr=c(),phif=c())
  for(yr in CLIM_YEARS){
    anchor <- ENTRY + r
    cyear_anchor <- as.Date(sprintf("%d%s", yr, format(anchor,"-%m-%d")))
    for(off in -POOL:POOL){
      m<-day_means(cyear_anchor+off)
      if(!is.null(m) && is.finite(m["sif"])){
        vals$sif<-c(vals$sif,m["sif"]); vals$nirvr<-c(vals$nirvr,m["nirvr"]); vals$phif<-c(vals$phif,m["phif"])
      }
    }
  }
  c(n=length(vals$sif),
    sif=mean(vals$sif),nirvr=mean(vals$nirvr),phif=mean(vals$phif))
}
cat("building stabilized climatology...\n")
clim <- do.call(rbind, lapply(rel_range, function(r){
  cm<-clim_for_rel(r); data.frame(rel=r, clim_n=cm["n"],
    sif.clim=cm["sif"], nirvr.clim=cm["nirvr"], phif.clim=cm["phif"]) }))

m <- merge(evt, clim, by="rel"); m<-m[order(m$rel),]
m$sif_anom<-m$sif-m$sif.clim; m$nirvr_anom<-m$nirvr-m$nirvr.clim; m$phif_anom<-m$phif-m$phif.clim
m$window<-NA_character_
for(w in names(windows)) m$window[m$rel>=windows[[w]][1]&m$rel<=windows[[w]][2]]<-w
write.csv(m, file.path(outdir,"event_vs_climatology.csv"), row.names=FALSE)

## ---- 5. window anomalies + bootstrap CI; recovery ratios vs pre7 ----
boot_ci<-function(x,B=5000){x<-x[is.finite(x)];if(length(x)<2)return(c(NA,NA));quantile(replicate(B,mean(sample(x,replace=TRUE))),c(.025,.975))}
wsum<-do.call(rbind,lapply(names(windows),function(w){
  s<-m[which(m$window==w),]; ci<-boot_ci(s$sif_anom)
  data.frame(window=w,days=sum(is.finite(s$sif)),clim_n=round(mean(s$clim_n)),
    sif=mean(s$sif,na.rm=TRUE),sif_clim=mean(s$sif.clim,na.rm=TRUE),
    sif_anom=mean(s$sif_anom,na.rm=TRUE),lo=ci[1],hi=ci[2],
    nirvr_anom=mean(s$nirvr_anom,na.rm=TRUE),phif_anom=mean(s$phif_anom,na.rm=TRUE))}))
bsif<-wsum$sif[wsum$window=="pre7"]; bnir<-mean(m$nirvr[m$window=="pre7"],na.rm=TRUE); bphi<-mean(m$phif[m$window=="pre7"],na.rm=TRUE)
rr<-data.frame(window=c("acute","early","recov2","recov3"),
  RR_sif=sapply(c("acute","early","recov2","recov3"),function(w)mean(m$sif[m$window==w],na.rm=TRUE)/bsif),
  RR_nirvr=sapply(c("acute","early","recov2","recov3"),function(w)mean(m$nirvr[m$window==w],na.rm=TRUE)/bnir),
  RR_phif=sapply(c("acute","early","recov2","recov3"),function(w)mean(m$phif[m$window==w],na.rm=TRUE)/bphi))
write.csv(wsum,file.path(outdir,"window_anomalies.csv"),row.names=FALSE)
write.csv(rr,file.path(outdir,"recovery_ratios.csv"),row.names=FALSE)
cat("\n=== WINDOW ANOMALIES ===\n"); print(format(wsum,digits=3),row.names=FALSE)
cat("\n=== RECOVERY RATIOS ===\n");  print(format(rr,digits=3),row.names=FALSE)

## ---- 6. panel figure ----
png(file.path(outdir,"anomaly_panels.png"),width=1700,height=1300,res=150)
par(mfrow=c(2,2),mar=c(4,4.5,3,1),oma=c(0,0,2,0))
shade<-function(){rect(0,-1e9,6,1e9,col="#ff000018",border=NA);abline(v=0,col="red",lty=2,lwd=2)}
plt<-function(ev,cl,ttl,yl){rng<-range(c(ev,cl),na.rm=TRUE)
  plot(m$rel,ev,type="n",xlab="Days from entry",ylab=yl,main=ttl,ylim=rng);shade()
  lines(m$rel,cl,col="grey55",lwd=2);points(m$rel,cl,col="grey55",pch=1,cex=.7)
  lines(m$rel,ev,col="#1a6fc4",lwd=2);points(m$rel,ev,col="#1a6fc4",pch=19,cex=.8)
  legend("topright",c(paste(EVENT_YEAR,"(event)"),"climatology (pooled)"),col=c("#1a6fc4","grey55"),lwd=2,pch=c(19,1),bty="n",cex=.8)}
plt(m$sif,m$sif.clim,"SIF","SIF_Corr_743")
plt(m$nirvr,m$nirvr.clim,"NIRvR (structure)","NIRvR")
plt(m$phif,m$phif.clim,expression(Phi[F]~"= SIF/NIRvR (physiology)"),expression(Phi[F]))
barplot(t(as.matrix(rr[,c("RR_sif","RR_nirvr","RR_phif")])),beside=TRUE,names.arg=rr$window,
  col=c("#1a6fc4","#7cb342","#e8843c"),ylim=c(0,1.3),main="Recovery ratios vs baseline",ylab="ratio")
abline(h=1,lty=2,lwd=2,col="grey30")
legend("topleft",c("SIF","NIRvR","PhiF"),fill=c("#1a6fc4","#7cb342","#e8843c"),bty="n",cex=.8)
mtext(sprintf("%s %d - Zimbabwe corridor: event vs stabilized climatology",NAME,EVENT_YEAR),outer=TRUE,cex=1.1,font=2)
dev.off()
cat("\nDONE", NAME, EVENT_YEAR, "->", outdir, "\n")
