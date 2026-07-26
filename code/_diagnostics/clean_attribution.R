# Clean attribution figure (Eq 9) for events that have it: vegetation storm-week
# response (% of normal) vs each driver — antecedent rain, storm rain, wind
# exposure — serif, framed, regression line + r. Reads saved attribution_pixels.csv
# (no recompute). Output: <evdir>/clean_figures/<LABEL>_CLEAN_attribution.png
source(file.path(Sys.getenv("CYCLONE_SIF_CODE", "code/00_shared"), "config.R"))
# find every event with attribution pixels (flat OR nested layout)
all <- list.dirs(RESULTS_ROOT, recursive=TRUE)
EVDIRS <- Filter(function(d) file.exists(file.path(d,"attribution","attribution_pixels.csv")), all)

storm_lab <- function(evdir){
  parent <- basename(dirname(evdir)); l <- basename(evdir); p <- strsplit(l,"_")[[1]]
  known <- c("Zimbabwe","Malawi","Botswana","Mozambique","Madagascar","South_Africa")
  s <- if (parent %in% known) p[1] else if (p[1] %in% c("MOZAMBIQUE","MADAGASCAR","BOTSWANA","MALAWI")) p[2] else p[1]
  paste0(toupper(substr(s,1,1)),tolower(substr(s,2,nchar(s)))) }

for (evdir in EVDIRS) {
  lab <- basename(evdir)
  pf <- file.path(evdir,"attribution","attribution_pixels.csv")
  d <- read.csv(pf)
  evc <- read.csv(file.path(evdir,"event_vs_climatology.csv"))
  base <- evc[evc$rel>=-14 & evc$rel<=-8,]; sifL <- mean(base$sif.clim,na.rm=TRUE)
  d$resp <- d$dSIF / sifL * 100   # response as % of normal SIF (matches maps)

  drivers <- list(
    list(v="ante_moist", lab="Antecedent 60-day rainfall (mm)"),
    list(v="acute_rain", lab="Storm-week rainfall (mm)"),
    list(v="wind_stress",lab="Wind exposure (proximity to track)"))
  outd <- file.path(evdir,"clean_figures"); dir.create(outd,showWarnings=FALSE)
  png(file.path(outd, sprintf("%s_CLEAN_attribution.png", lab)), width=1850, height=720, res=160)
  par(family="serif", mfrow=c(1,3), mar=c(4.6,4.8,3.2,1.2), oma=c(0,0,2.4,0))
  for (dr in drivers) {
    x <- d[[dr$v]]; y <- d$resp; ok <- is.finite(x)&is.finite(y)
    x<-x[ok]; y<-y[ok]; r <- if(length(x)>2) cor(x,y) else NA
    plot(x,y,pch=19,col="#1a6fc466",cex=0.9,
         xlab=dr$lab, ylab="Storm-week SIF response (% of normal)",
         cex.lab=1.15, cex.axis=1.0)
    abline(h=0,col="grey75"); if(length(x)>2) abline(lm(y~x),col="#c0392b",lwd=2.4)
    box(lwd=1.4)
    title(main=sprintf("r = %.2f", r), font.main=2, cex.main=1.2, line=0.5)
  }
  mtext(sprintf("Cyclone %s — vegetation response vs. drivers (Eq 9 attribution, n = %d pixels)",
                storm_lab(evdir), nrow(d)), side=3, outer=TRUE, line=0.3, font=2, cex=1.3)
  dev.off(); cat("wrote clean attribution:",lab,"\n")
}
cat("DONE.\n")
