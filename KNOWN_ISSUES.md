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

**Reproducibility gap:** the script that produced the ΦF column, `fix_phif.R`, is not in
this archive and no longer exists on the authors' machines. Its output survives as
`summary_tables/table3_phif_corrected.csv` in the earlier deposit. Until it is rebuilt,
the ΦF column can be checked against that CSV but not regenerated from source. Every other
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
