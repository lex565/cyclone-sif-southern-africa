# Known issues

Things a reproducer will hit. Listed so they are not mistaken for mistakes on your side.

## 1. Raw inputs are not redistributed

`derived_data/` is everything the pipeline produced. The raw satellite granules are public
but large and are not included; see the Raw inputs section of the README. Set
`CYCLONE_SIF_DATA` to your own copy before running anything under `code/` that reads
level-2 files.

## 2. The archive used here does not cover the whole study period

The TROPOSIF holding that produced these results begins on 1 May 2018 and contains no
granules between 1 January and 24 April 2021. Nine of the 21 storm-country events
therefore have zero acute-window files and are excluded from all quantitative analysis.
Per-event file counts are in
`derived_data/robustness/dual_variant_2026_08_07/coverage_audit.csv`, and
`derived_data/robustness/Figure_3_rebuild_audit.txt` records the same check for the four
empty recovery panels in Figure 3. Anyone rebuilding from a more complete TROPOSIF
holding should expect to be able to analyse more than 12 events.

## 3. Table 3's apparent fluorescence yield is a bootstrap estimate, not the plug-in ratio

This is the single most likely thing to be misread as an error, so read it before
reporting one.

Table 3's ΦF column is the **25 km spatial-block bootstrap estimate of the derived
residual**, with SIF and NIRvR resampled together. It is *not* the plug-in residual
(1 + ΔSIF) / (1 + ΔNIRvR) − 1 computed once from the corridor means. Because the residual
is a ratio, the bootstrap mean is biased away from the function of the mean, and the bias
grows with resampling variance — so the two estimators separate most where the sample is
thinnest:

| Event | n soundings | Table 3 ΦF | Plug-in residual | Gap |
|---|---|---|---|---|
| Botswana / Chalane | 15 | -3.6 | -16.19 | 12.6 pp |
| Mozambique / Chalane | 170 | -0.6 | +7.81 | 8.4 pp, sign differs |
| Madagascar / Francisco | 320 | 17.7 | 20.34 | 2.6 pp |
| Madagascar / Chalane | 1665 | -13.8 | -15.71 | 1.9 pp |

The plug-in values are what
`derived_data/robustness/dual_variant_2026_08_07/eq6_triplet_all_windows_dual.csv`
reports in `A_PhiF_residual_pct`. Both are correct for what they are. Do not "reconcile"
them: the SIF and NIRvR columns of Table 3 are pipeline values and the ΦF column is a
bootstrap estimate, by design.

**Provenance:** the ΦF column's authoritative values ship here as
`derived_data/table3_phif_corrected.csv` (12 events, estimate and 95% interval), and
Table 3 of the paper matches it exactly. The script that produced them, `fix_phif.R`, is
**not** in this archive and no longer exists: it was written in a temporary working
directory that has since been cleared, and it was never committed. Recovery was attempted
on 2026-09-02 across the earlier Zenodo deposit, every surviving working directory, the
recycle bins of four volumes, volume shadow copies and this repository's history; it is
gone.

So the ΦF column can be **verified against the shipped CSV but not regenerated from
source**. A reconstruction was attempted over the 0.1 degree acute-window grid
(`derived_data/*/*/spatial_maps/anomd_{sif,nirvr}_acute.tif`) and gets close for the
well-sampled corridors but fails for the sparse ones, because no per-cell baseline
climatology raster survives to serve as the denominator; the attempt is kept outside this
archive rather than shipped, so nothing here is mistaken for the original. Every other
number in Tables 1-3 and 5-7 is reproducible from `code/`.

## 4. Abadi is an Office cloud font

The figure scripts request Abadi and fall back to a humanist sans if it is absent. On a
machine without Office the figures will render in the fallback face; values and layout are
unaffected. `CYCLONE_SIF_HOME` points at the profile directory the font cache lives under.

---

## Resolved

**Madagascar / Francisco acute values (closed 2026-09-01).** The manuscript previously
reported SIF -27.8% and NIRvR -39.9% for this event, which the pipeline did not reproduce;
the dual-variant rerun gave -28.34% and -40.45%. Every other window for this event, and
every other event's SIF, reproduced exactly, so the manuscript was updated to the
reproducing values: Tables 2 and 3 now read -28.3% and -40.5%, the 25 km block intervals
were moved by the same amount (they are stored as estimate ± 1.96 SE, and the SE does not
depend on the point estimate), `derived_data/moran_forest_data.csv` was updated, and
Figures 5 and 7 were regenerated. A pixel diff confirmed the only change in either figure
was the Francisco panel. The ΦF value for this event was deliberately left at 17.7, per
issue 3 above.
