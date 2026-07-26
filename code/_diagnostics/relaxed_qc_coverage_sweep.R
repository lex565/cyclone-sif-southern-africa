# Relaxed-QC sweep: for each event, count valid SIF days per BER window at a
# range of cloud-fraction thresholds. Tests whether looser QC salvages wet-season
# events (Chalane/Eloise). Event-year only (no climatology) -> fast.
suppressMessages({library(sf); library(ncdf4)})
sf::sf_use_s2(TRUE)
sif_root <- file.path(Sys.getenv("CYCLONE_SIF_DATA", "data_raw"), "TROPOSIF")
outroot  <- Sys.getenv("CYCLONE_SIF_OUT", Sys.getenv("CYCLONE_SIF_OUT", "derived_data"))
SZA_MAX<-85; TOA_LO<-20; TOA_HI<-200; RED_I<-1; NIR_I<-7
CF_LEVELS <- c(0.02, 0.05, 0.10, 0.20, 0.50, 0.80)
windows <- list(baseline=c(-14,-8),pre7=c(-7,-1),acute=c(0,6),early=c(7,13),recov2=c(14,20),recov3=c(21,27))

events <- list(
  IDAI    = list(sid="2019063S18038", entry=as.Date("2019-03-15"), dir="IDAI_2019"),
  CHALANE = list(sid="2020355S11065", entry=as.Date("2020-12-30"), dir="CHALANE_2020"),
  ELOISE  = list(sid="2021012S12086", entry=as.Date("2021-01-23"), dir="ELOISE_2021")
)

count_day <- function(d, corridor, bb, cf_levels) {
  f <- file.path(sif_root, format(d,"%Y"), sprintf("TROPOSIF_L2B_%s.nc", format(d,"%Y-%m-%d")))
  if (!file.exists(f)) return(setNames(rep(0,length(cf_levels)), cf_levels))
  nc <- nc_open(f); on.exit(nc_close(nc))
  lat<-ncvar_get(nc,"PRODUCT/latitude"); lon<-ncvar_get(nc,"PRODUCT/longitude")
  keep<-which(lon>=bb["xmin"]&lon<=bb["xmax"]&lat>=bb["ymin"]&lat<=bb["ymax"])
  if(!length(keep)) return(setNames(rep(0,length(cf_levels)), cf_levels))
  g<-function(p) ncvar_get(nc,p)[keep]
  sif<-g("PRODUCT/SIF_Corr_743"); cf<-g("PRODUCT/SUPPORT_DATA/INPUT_DATA/cloud_fraction_L2")
  sza<-g("PRODUCT/SUPPORT_DATA/GEOLOCATIONS/solar_zenith_angle")
  nrd<-g("PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/Mean_TOA_RAD_743")
  toa<-ncvar_get(nc,"PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/TOA_RFL")[,keep,drop=FALSE]
  red<-toa[RED_I,]; nir<-toa[NIR_I,]
  df<-data.frame(lon=lon[keep],lat=lat[keep],sif=sif,cf=cf,sza=sza,nirrad=nrd,red=red,nir=nir)
  pin<-st_within(st_as_sf(df,coords=c("lon","lat"),crs=4326),corridor,sparse=FALSE)[,1]
  df<-df[pin,,drop=FALSE]; if(!nrow(df)) return(setNames(rep(0,length(cf_levels)), cf_levels))
  ndvi<-(df$nir-df$red)/(df$nir+df$red); nirvr<-ndvi*df$nirrad
  base_ok <- df$sza<SZA_MAX & df$nirrad>=TOA_LO & df$nirrad<=TOA_HI &
             is.finite(df$sif) & is.finite(nirvr) & nirvr>0 & ndvi>0.1
  sapply(cf_levels, function(cl) sum(base_ok & df$cf<cl))
}

allres <- list()
for (nm in names(events)) {
  ev <- events[[nm]]
  corridor <- st_read(file.path(outroot, ev$dir, "corridor_zim.gpkg"), quiet=TRUE) |> st_union()
  bb <- st_bbox(corridor)
  cat("\n######", nm, "######\n")
  rel_range <- min(sapply(windows,`[`,1)):max(sapply(windows,`[`,2))
  daily <- t(sapply(rel_range, function(r) count_day(ev$entry+r, corridor, bb, CF_LEVELS)))
  rownames(daily) <- rel_range; colnames(daily) <- paste0("cf",CF_LEVELS)
  # per-window: count days with >=1 valid sounding, at each CF level
  wtab <- do.call(rbind, lapply(names(windows), function(w){
    rr <- windows[[w]][1]:windows[[w]][2]
    rows <- daily[as.character(rr), , drop=FALSE]
    days_with <- colSums(rows > 0)
    data.frame(event=nm, window=w, n_window_days=length(rr),
               as.list(setNames(days_with, paste0("days_cf",CF_LEVELS))))
  }))
  print(wtab, row.names=FALSE)
  allres[[nm]] <- wtab
}
final <- do.call(rbind, allres)
write.csv(final, file.path(outroot, "relaxed_qc_coverage_sweep.csv"), row.names=FALSE)
cat("\nSaved relaxed_qc_coverage_sweep.csv\n")
