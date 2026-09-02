# Cyclone-driven disruption of vegetation photosynthesis in Southern Africa (TROPOMI SIF)

Analysis code and derived data for the manuscript by **Mbendana, Zhao, Gumbo & Rofiqoh**.

This repository contains the R pipeline and the derived datasets needed to reproduce the
figures, tables and statistics in the paper. The raw satellite inputs are public and are
**not** redistributed here; see [Raw inputs](#raw-inputs).

Study design: 21 storm-country events over 2018-2021, analysed inside 200 km tropical-cyclone
track corridors using TROPOMI solar-induced chlorophyll fluorescence (SIF), decomposed against
the NIRvR structural proxy and apparent fluorescence yield, and compared with PML-V2 gross
primary production.

---

## Quick start

```r
# 1. point the pipeline at your data and output locations
cp paths_local.R.example paths_local.R     # then edit it
source("paths_local.R")

# 2. run one event end to end
Rscript code/IDAI_2019/05_original_metrics.R
```

All paths are read from environment variables, with repo-relative defaults:

| Variable | Meaning | Default |
|---|---|---|
| `CYCLONE_SIF_DATA` | raw satellite inputs (you must supply these) | `data_raw` |
| `CYCLONE_SIF_OUT` | per-event derived outputs | `derived_data` |
| `CYCLONE_SIF_CODE` | shared function library | `code/00_shared` |
| `CYCLONE_SIF_CODEROOT` | code root | `code` |
| `CYCLONE_SIF_RESULTS` | figures and summary products | `results` |

Nothing in this repository hard-codes a machine-specific path.

---

## Layout

```
code/
  00_shared/        config.R, functions.R, original_metrics.R, spatial_engine.R,
                    attribution_engine.R, run_*.R   (parameterised, country-agnostic)
  IDAI_2019/  CHALANE_2020/  ELOISE_2021/  ...      per-event drivers
  _diagnostics/     storm selection, QC sweeps, coverage checks
  robustness/       dual-variant rebuild, apparent-yield pairing comparison
derived_data/       one folder per storm-country event (see below)
  robustness/       outputs of the robustness analyses
paths_local.R.example
KNOWN_ISSUES.md
CITATION.cff
LICENSE             MIT
SESSION_INFO.txt    R and package versions used to produce the archived results
```

Each event folder in `derived_data/` contains:

- `event_vs_climatology.csv` - per-day corridor SIF / NIRvR / PhiF, the pooled climatology
  and the resulting anomalies, with the BER window label
- `window_anomalies.csv` - corridor-mean anomaly per window
- `metrics/` - coverage and dilution (Eq 1-2), percentage change (Eq 6), recovery ratios
  (Eq 7), SIF-GPP correlation (Eq 8), response-class and Shannon-entropy summaries
- `attribution/` - per-pixel driver values and fitted coefficients (three corridors only)
- `corridor*.gpkg`, `segment.gpkg` - the 200 km corridor and the in-country track segment

Root-level `COMMENT*.csv` and `TABLE3_*.csv` files are the verification products described
below.

---

## Method summary

- **Corridor**: the IBTrACS track line is buffered by 200 km in a Lambert Azimuthal
  Equal-Area projection centred on each event, then intersected with the national boundary,
  so both the buffer distance and the derived areas are metrically correct.
- **Anchor (day 0)**: the first six-hourly IBTrACS fix inside the country. For 20 of 21
  events this coincides with the first boundary crossing and the closest approach at zero
  distance; the exception is Eloise over Zimbabwe, where no fix falls inside and the anchor
  is the boundary crossing of the interpolated track.
- **Windows** (days relative to the anchor): baseline -14 to -8, pre-event -7 to -1,
  acute 0 to 6, early recovery +7 to +13, then +14 to +20 and +21 to +27. Late recovery is
  +45 to +60. The windows are sequential and do not overlap.
- **Climatology**: leave-one-year-out over the remaining years in 2018-2021, pooled +/-4 days
  around each relative day.
- **Aggregation**: corridor means reported in tables are sounding-weighted arithmetic means
  of all QC-passing soundings. Mapped fields use a separate 0.1 degree grid with a minimum of
  two soundings per cell, so maps and tables share temporal windows but not spatial units.
- **Uncertainty**: attribution coefficients use a spatial block bootstrap (10, 25 and 50 km
  blocks) rather than row-wise resampling, because residual spatial dependence is present.

---

## Verification products

These files record checks run against the pipeline rather than new science:

| File | Contents |
|---|---|
| `COMMENT01_gpp_sif_table.csv` | SIF-GPP per event: n, Pearson r, Fisher 95% CI, exact p, Spearman, lag-1 autocorrelation, Durbin-Watson, leave-one-out range |
| `COMMENT150_anchor_verification.csv` | all 21 anchors re-derived from IBTrACS against the national polygons |
| `COMMENT1890_reference_contamination.csv` | screen of every climatology year for other cyclones in the same corridor and window |
| `COMMENT1506_1873_attribution_diagnostics.csv` | adjusted R2, model F test, residual Moran's I, Shapiro-Wilk, Breusch-Pagan, VIF, and block-bootstrap intervals at three block sizes |
| `COMMENT2085_recovery_window_rerun.csv` | recovery ratios under both the overlapping and the sequential early window |
| `COMMENT2090_table7_matched_rerun.csv` | corridor-radius sensitivity recomputed through the main pipeline |
| `TABLE3_recovery_triplet_rerun.csv` | recovery ratios for SIF, NIRvR and PhiF under both windows |
| `table3_phif_corrected.csv` | the authoritative Table 3 apparent-yield column: 25 km spatial-block bootstrap estimate of the derived residual, with 95% intervals. See `KNOWN_ISSUES.md` issue 3 - the generating script is lost, so this CSV is the source of record |

Each rerun reproduces the published value before changing anything, so the comparisons are
like for like. The radius reruns reproduce the main-analysis acute value exactly at 200 km
for all four tested events.

---

## Known limitations

Stated plainly, because they bound what the code can show:

- **Acute-window coverage**: 9 of the 21 events have no acute-window retrievals at all.
  This is not cloud: the TROPOSIF holding used here begins on 1 May 2018 and contains no
  granules between 1 January and 24 April 2021, so two events precede the record and seven
  fall inside the 2021 gap. Per-event file counts are in
  `derived_data/robustness/dual_variant_2026_08_07/coverage_audit.csv`. Cloud *is* the
  binding constraint inside the 12 observable corridors, several of which rest on one to
  three cloud-free days.
- **Corridor radius matters**: the acute anomaly is not stable with respect to corridor
  width. Only one of four tested events shows a monotonic response.
- **Reference-year contamination**: 13 of 21 events have at least one climatology year
  containing another cyclone in the same corridor and window. This depresses the reference
  and therefore makes reported suppression conservative.
- **Apparent fluorescence yield is derived**, not independently measured: PhiF = SIF / NIRvR
  comes from the same retrieval.
- **Attribution is exploratory**: three corridors, R2 between 0.12 and 0.21, with antecedent
  and acute rainfall correlated at 0.83 to 0.85.

---

## Robustness analyses

Added 2026-09-01. These do not change any published number; they are the evidence behind
three decisions in the paper.

| Location | What it establishes |
|---|---|
| `code/robustness/dual_variant_2026_08_07/` | Rebuilds all 21 event series reading `SIF_743` alongside `SIF_Corr_743` in a single pass, then recomputes the Eq 6 triplet for every window under both pairings. Outputs in `derived_data/robustness/dual_variant_2026_08_07/`. Verdict: 12 events reproduced, 9 with no event data, 0 mismatches. |
| `code/robustness/phif_variant_2026_08_04/` | Compares the current apparent-yield pairing (daylength-corrected SIF over instantaneous NIRvR) against the Zeng-consistent instantaneous-over-instantaneous pairing. Verdict: 0 sign flips, Spearman 0.951 for SIF and 0.937 for PhiF, mean absolute shift 3.56 pp. The pairing was documented rather than changed, because Methods 3.4 states the exact identity 1 + dSIF = (1 + dNIRvR)(1 + dPhiF), which only holds if all three move together. |
| `derived_data/robustness/dual_variant_2026_08_07/coverage_audit.csv` | Per-event acute and window file counts, plus how many non-event years contribute to each climatology. Five of the 12 observable corridors rest on a single reference year. |
| `code/00_shared/compose_figure3_uniform.py` and `derived_data/robustness/Figure_3_rebuild_audit.txt` | Rebuilds Figure 3 on a common panel geometry, and re-derives the reason each empty panel is empty from the file counts rather than assuming cloud. |

`code/00_shared/functions.R` carries the additive change that makes the dual-variant read
possible. The QC condition is deliberately untouched, so the retained sounding set is
byte-identical and the original variant still reproduces the published values.

See `KNOWN_ISSUES.md` before reporting a mismatch.

---

## Raw inputs

Not redistributed. Obtain from the original providers and cite them:

- **TROPOMI TROPOSIF** L2B - Guanter et al. (2021), *Earth System Science Data* 13(11) 5423-5440
- **CHIRPS** daily rainfall - Funk et al. (2015)
- **IBTrACS** v04r01 cyclone tracks - Knapp et al. (2010)
- **Ecoregions2017** biome and boundary polygons - Dinerstein et al. (2017)
- **PML-V2** gross primary production - Zhang et al. (2019)

---

## Environment

See `SESSION_INFO.txt`. R 4.5.1 with `sf`, `terra`, `ncdf4` and `dplyr`.

## Citation

See `CITATION.cff`. Please cite both this archive and the associated manuscript.

## License

This archive is dual-licensed, because code and data need different terms:

- **Code** (`code/`) - MIT, see `LICENSE`
- **Derived data** (`derived_data/`) - Creative Commons Attribution 4.0, see `LICENSE-DATA`

Both require attribution. If you use either, please cite this archive and the
associated manuscript (see `CITATION.cff`).
