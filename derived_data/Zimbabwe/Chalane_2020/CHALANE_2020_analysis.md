# Cyclone Chalane — Zimbabwe vegetation response (TROPOMI SIF triplet)

**Event:** Tropical Cyclone Chalane · corridor entry 2020-12-30
**Sensor:** TROPOMI TROPOSIF L2B (SIF_Corr_743, daylength-corrected)
**Domain:** 200 km track-buffer corridor ∩ Zimbabwe, 0.1° grid, min 2 soundings/cell
**Climatology:** non-event years 2018, 2019, 2021 (±4-day pooling)

Figures (in `spatial_maps/`):
- `CHALANE_2020_triplet_demeaned.png` — combined SIF / NIRvR / Phi_F
- `CHALANE_2020_SIF_demeaned.png`, `..._NIRVR_demeaned.png`, `..._PHIF_demeaned.png` (+ `_raw`)
- `CHALANE_2020_coverage_per_window.png`

---

## 1. Window-by-window measurements (de-meaned)

| Window | n_cells | SIF mean | NIRvR mean | Phi_F mean | % suppressed (SIF) |
|---|---|---|---|---|---|
| baseline (−14..−8 d) | 289 | 0.000* | 0.00* | 0.0000* | 55.0 |
| pre7 (−7..−1 d) | 802 | +0.036 | +4.34 | −0.0005 | 45.6 |
| **acute (0..+6 d)** | **58** | **−0.130** | **−5.50** | **−0.0019** | **74.1** |
| early (+7..+13 d) | — | — | — | — | — |
| recov2 (+14..+20 d) | — | — | — | — | — |
| recov3 (+21..+27 d) | — | — | — | — | — |

\*de-meaning reference (raw baseline offset removed: SIF 0.152, NIRvR 10.57, Phi_F 0.0017).
Early / recov windows have **no usable data** — Chalane (late December) lands as the monsoon cloud deck closes in. Coverage collapses from 802 cells (pre7) to 58 (acute), then to zero.

---

## 2. Reading — directionally consistent with Idai, but coverage-limited

In the one observable post-landfall window (acute), **both SIF (−0.130) and NIRvR (−5.50) are suppressed, with 74% of cells red**. The co-suppression of the structure term (NIRvR) matches the Idai signature of acute structural canopy damage along the track.

However:
- **Acute n = 58 cells** — thin and spatially patchy (see coverage figure). This is below the threshold at which a stable per-pixel attribution model can be fit.
- **No recovery windows** — the post-event trajectory is unobservable.

Chalane therefore **corroborates the Idai mechanism qualitatively** (acute structural suppression) but is **not used for quantitative attribution** or for any recovery claim.

---

## 3. Observability note

Chalane sits on the edge of the TROPOMI observability wall: a late-December landfall is partially visible in the acute window but completely blacked out through recovery. It is the intermediate case between Idai (mid-March, well observed) and Eloise (late January, fully blacked out). See the cross-event coverage comparison in the project results appendix.
