## Exactly what goes into NIRvR: units, long names, and the reflectance wavelengths.
suppressMessages(library(ncdf4))
nc <- nc_open(file.path(file.path(Sys.getenv("CYCLONE_SIF_DATA", "data_raw"), "TROPOSIF"), "2019/TROPOSIF_L2B_2019-03-20.nc"))
for (v in c("PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/Mean_TOA_RAD_743",
            "PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/TOA_RFL",
            "PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/WVL_RFL")) {
  cat(sprintf("%s\n   units    : %s\n   long_name: %s\n", v,
      ncatt_get(nc, v, "units")$value, ncatt_get(nc, v, "long_name")$value))
}
cat("\nWVL_RFL (the 7 reflectance wavelengths, nm):\n")
w <- ncvar_get(nc, "PRODUCT/SUPPORT_DATA/DETAILED_RESULTS/WVL_RFL")
for (i in seq_along(w)) cat(sprintf("   index %d : %.2f nm%s\n", i, w[i],
    if (i == 1) "   <- RED_I used for NDVI red" else if (i == 7) "   <- NIR_I used for NDVI nir" else ""))
nc_close(nc)
