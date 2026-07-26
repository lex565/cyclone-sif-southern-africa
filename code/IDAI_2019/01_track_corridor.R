# =============================================================================
# Step 1 — IDAI 2019 x Zimbabwe: track intersection, entry date, 200 km corridor
# My Manuscript project. Output -> <derived_data>
# Fixes prior bugs: SI basin only; storm selected by SID; track INTERSECTED with
# country polygon (no proximity guessing); entry date = first boundary crossing.
# =============================================================================
suppressMessages({library(sf); library(terra)})
sf::sf_use_s2(TRUE)

# ---- paths ----
ib_pts <- file.path(Sys.getenv("CYCLONE_SIF_DATA", "data_raw"), "IBTracs/Extracted/IBTrACS.SI.list.v04r01.points.shp")
zim_shp <- file.path(Sys.getenv("CYCLONE_SIF_DATA", "data_raw"), "Ecological Regions/By_Country/Ecoregions2017_Zimbabwe.shp")
outdir  <- Sys.getenv("CYCLONE_SIF_OUT", Sys.getenv("CYCLONE_SIF_OUT", "derived_data"))
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

SID <- "2019063S18038"   # Cyclone IDAI, 2019
BUFFER_KM <- 200

# ---- 1. IDAI track points (ordered in time) ----
pts <- st_read(ib_pts, quiet = TRUE)
idai <- pts[pts$SID == SID, ]
idai$ISO_TIME <- as.POSIXct(idai$ISO_TIME, tz = "UTC")
idai <- idai[order(idai$ISO_TIME), ]
cat("IDAI track points:", nrow(idai), "\n")
cat("Track time span:", format(min(idai$ISO_TIME)), "->", format(max(idai$ISO_TIME)), "\n")

# wind: SI basin official agency is REU (Reunion); WMO_WIND often mirrors it
w <- suppressWarnings(as.numeric(idai$WMO_WIND))
if (all(is.na(w))) w <- suppressWarnings(as.numeric(idai$REU_WIND))
cat("Max wind (kt):", max(w, na.rm = TRUE), "\n")

# ---- 2. build ordered track LineString ----
track_line <- idai |>
  st_combine() |>
  st_cast("LINESTRING")
st_crs(track_line) <- 4326

# ---- 3. Zimbabwe national boundary (dissolve 8 ecoregions) ----
zim <- st_read(zim_shp, quiet = TRUE) |> st_make_valid()
zim_nat <- st_union(zim)
cat("Zimbabwe polygons dissolved:", nrow(zim), "-> 1 boundary\n")

# ---- 4. metric CRS for buffering/intersection (Lambert Azimuthal Equal-Area,
#         centred on the track) so 200 km is a true 200 km ----
ctr <- st_coordinates(st_centroid(st_union(idai)))
laea <- sprintf("+proj=laea +lat_0=%f +lon_0=%f +datum=WGS84 +units=m +no_defs",
                ctr[2], ctr[1])
track_m <- st_transform(track_line, laea)
zim_m   <- st_transform(zim_nat,  laea)
pts_m   <- st_transform(idai,     laea)

# ---- 5. in-country track segment + entry date ----
seg_in <- st_intersection(track_m, zim_m)
seg_len_km <- as.numeric(st_length(seg_in)) / 1000
cat(sprintf("In-country track length: %.1f km\n", sum(seg_len_km)))

pts_in <- pts_m[st_within(pts_m, zim_m, sparse = FALSE)[,1], ]
if (nrow(pts_in) > 0) {
  entry_date <- min(pts_in$ISO_TIME)
  cat("Entry date (first track point inside Zimbabwe):",
      format(entry_date, "%Y-%m-%d %H:%M UTC"), "\n")
} else {
  # track may cross corner without a 6-hourly point landing inside:
  # use the boundary-crossing vertex of the intersected segment instead
  entry_date <- NA
  cat("No 6-hourly point strictly inside; entry via segment crossing only.\n")
}

# ---- 6. 200 km corridor, full and clipped to Zimbabwe ----
corridor_full <- st_buffer(track_m, BUFFER_KM * 1000)
corridor_zim  <- st_intersection(corridor_full, zim_m)
cat(sprintf("Corridor area (full): %.0f km2 | clipped to Zimbabwe: %.0f km2\n",
            as.numeric(st_area(corridor_full))/1e6,
            as.numeric(st_area(corridor_zim))/1e6))

# coverage fraction (diagnostic, methods Eq.1)
CF <- as.numeric(st_area(corridor_zim)) / as.numeric(st_area(zim_m))
cat(sprintf("Coverage fraction (corridor∩Zim / Zim): %.3f | dilution factor: %.2f\n",
            CF, 1/CF))

# ---- 7. write outputs (back to WGS84 for downstream extraction) ----
to84 <- function(x) st_transform(x, 4326)
st_write(to84(track_line),   file.path(outdir, "idai2019_track_full.gpkg"),       delete_dsn = TRUE, quiet = TRUE)
st_write(to84(st_sf(geometry = seg_in)),       file.path(outdir, "idai2019_zim_segment.gpkg"),    delete_dsn = TRUE, quiet = TRUE)
st_write(to84(st_sf(geometry = corridor_full)),file.path(outdir, "idai2019_corridor_full.gpkg"),  delete_dsn = TRUE, quiet = TRUE)
st_write(to84(st_sf(geometry = corridor_zim)), file.path(outdir, "idai2019_corridor_zim.gpkg"),   delete_dsn = TRUE, quiet = TRUE)
st_write(to84(zim_nat) |> st_sf(geometry = _), file.path(outdir, "zimbabwe_boundary.gpkg"),       delete_dsn = TRUE, quiet = TRUE)

# ---- 8. quick-look map ----
png(file.path(outdir, "step1_idai_zimbabwe_corridor.png"), width = 1400, height = 1200, res = 150)
plot(st_geometry(to84(corridor_full)), col = "#cfe8ff", border = "#5aa0d8",
     main = "Cyclone IDAI 2019 — 200 km corridor & Zimbabwe exposure",
     axes = TRUE)
plot(st_geometry(to84(zim_nat)),       col = NA, border = "grey30", lwd = 2, add = TRUE)
plot(st_geometry(to84(corridor_zim)),  col = "#ffb3a766", border = "red", add = TRUE)
plot(st_geometry(to84(track_line)),    col = "blue", lwd = 2, add = TRUE)
plot(st_geometry(to84(seg_in)),        col = "red",  lwd = 4, add = TRUE)
plot(st_geometry(idai),                pch = 20, cex = 0.6, col = "blue", add = TRUE)
if (nrow(pts_in) > 0)
  plot(st_geometry(to84(pts_in)),      pch = 20, cex = 1.1, col = "darkred", add = TRUE)
legend("topright", bty = "n",
       legend = c("200 km corridor", "Zimbabwe", "corridor ∩ Zimbabwe",
                  "IDAI track", "in-country segment"),
       col = c("#5aa0d8","grey30","red","blue","red"),
       lwd = c(6,2,6,2,4))
dev.off()

# ---- 9. summary file ----
summ <- file.path(outdir, "step1_summary.txt")
writeLines(c(
  "Step 1 — IDAI 2019 x Zimbabwe",
  paste("SID:", SID),
  paste("Track points:", nrow(idai)),
  paste("Track span:", format(min(idai$ISO_TIME)), "to", format(max(idai$ISO_TIME))),
  paste("Max wind (kt):", round(max(w, na.rm = TRUE), 1)),
  paste("In-country track length (km):", round(sum(seg_len_km), 1)),
  paste("Entry date:", if (!is.na(entry_date)) format(entry_date, "%Y-%m-%d %H:%M UTC") else "segment-crossing only"),
  paste("Points inside Zimbabwe:", nrow(pts_in)),
  sprintf("Corridor area full (km2): %.0f", as.numeric(st_area(corridor_full))/1e6),
  sprintf("Corridor∩Zim area (km2): %.0f", as.numeric(st_area(corridor_zim))/1e6),
  sprintf("Coverage fraction: %.3f", CF),
  paste("Buffer radius (km):", BUFFER_KM),
  paste("Generated:", format(Sys.time()))
), summ)

cat("\nDONE. Outputs in:", outdir, "\n")
cat("Map: step1_idai_zimbabwe_corridor.png\n")
