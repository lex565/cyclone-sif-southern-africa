# Known issues

Things a reproducer will hit. Listed so they are not mistaken for mistakes on your side.

## 1. Madagascar / Francisco: the manuscript tables and two figures disagree

**Status: open, knowingly.**

| Where | Acute corridor-mean SIF change |
|---|---|
| Manuscript Tables 2 and 3 | **-28.3%** |
| Manuscript Figure 5 and Figure 7 | **-27.8%** |
| `derived_data/moran_forest_data.csv` (`effect`) | -27.8 |
| `derived_data/robustness/dual_variant_2026_08_07/eq6_triplet_all_windows_dual.csv` (`A_SIF_pct`, window `acute`) | -28.34 |

Eleven of the twelve observable events reproduce their published acute value to within
0.05 percentage points through the dual-variant rerun in
`code/robustness/dual_variant_2026_08_07/`. Francisco is the only exception, at 0.54 pp.
The manuscript tables were updated to the reproducing value; Figures 5 and 7 were not
regenerated, so they still carry the previously published one. Table 3's confidence
interval for Francisco, `[-34.2, -21.3]`, is also still centred on -27.8 rather than -28.3,
because recentring it without rerunning the 25 km spatial-block bootstrap would be an
approximation rather than a result.

The most likely cause has not been confirmed. Francisco's leave-one-year-out climatology
rests on a single contributing non-event year (`clim_years_contributing = 1` in
`derived_data/robustness/dual_variant_2026_08_07/coverage_audit.csv`) and it has seven
acute-window files but only four unique usable days after QC.

To close it: diagnose the divergence, rerun the block bootstrap for that event, update
`derived_data/moran_forest_data.csv`, and regenerate Figures 5 and 7.

## 2. Raw inputs are not redistributed

`derived_data/` is everything the pipeline produced. The raw satellite granules are public
but large and are not included; see the Raw inputs section of the README. Set
`CYCLONE_SIF_DATA` to your own copy before running anything under `code/` that reads
level-2 files.

## 3. The archive used here does not cover the whole study period

The TROPOSIF holding that produced these results begins on 1 May 2018 and contains no
granules between 1 January and 24 April 2021. Nine of the 21 storm-country events
therefore have zero acute-window files and are excluded from all quantitative analysis.
Per-event file counts are in
`derived_data/robustness/dual_variant_2026_08_07/coverage_audit.csv`, and
`derived_data/robustness/Figure_3_rebuild_audit.txt` records the same check for the four
empty recovery panels in Figure 3. Anyone rebuilding from a more complete TROPOSIF
holding should expect to be able to analyse more than 12 events.

## 4. Abadi is an Office cloud font

The figure scripts request Abadi and fall back to a humanist sans if it is absent. On a
machine without Office the figures will render in the fallback face; values and layout are
unaffected. `CYCLONE_SIF_HOME` points at the profile directory the font cache lives under.
