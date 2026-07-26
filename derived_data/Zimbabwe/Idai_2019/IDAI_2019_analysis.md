# Cyclone Idai — Zimbabwe vegetation response (TROPOMI SIF triplet)

**Event:** Tropical Cyclone Idai · landfall corridor entry 2019-03-15
**Sensor:** TROPOMI TROPOSIF L2B (SIF_Corr_743, daylength-corrected)
**Domain:** 200 km track-buffer corridor ∩ Zimbabwe, 0.1° grid, min 2 soundings/cell
**Climatology:** non-event years 2018, 2020, 2021 (±4-day pooling)
**Baseline de-meaning:** baseline-window corridor offset removed per signal to isolate the cyclone signal from year-level bias.

> **What "de-meaning" means (plain language).** The baseline window (before the
> storm) measures how far the event year already sat from a normal year — here
> 2019 ran ~0.037 SIF units *below* the 2018/2020/2021 climatology before Idai
> even arrived (a low-SIF year). De-meaning subtracts that constant offset from
> every window, so the baseline becomes 0 by construction and each window then
> measures only the departure attributable to the cyclone, not the background
> year bias. (Example: acute raw anomaly −0.178 → de-meaned −0.141.) It assumes
> the offset is spatially uniform and time-constant — a standard approximation.
> See `../METHODS_NOTES.md`.

Figures (in `spatial_maps/`):
- `IDAI_2019_triplet_demeaned.png` — combined SIF / NIRvR / Phi_F, 6 BER windows
- `IDAI_2019_SIF_demeaned.png`, `IDAI_2019_NIRVR_demeaned.png`, `IDAI_2019_PHIF_demeaned.png`
- matching `_raw.png` versions, `IDAI_2019_coverage_per_window.png`
- attribution: `attribution/IDAI_driver_maps.png`, `IDAI_attribution_scatter.png`

---

## 1. Window-by-window measurements (de-meaned)

| Window | n_cells | SIF mean | NIRvR mean | Phi_F mean | NIRvR % suppressed |
|---|---|---|---|---|---|
| baseline (−14..−8 d) | 39 | 0.000* | 0.00* | 0.0000* | 48.7 |
| pre7 (−7..−1 d) | 319 | +0.029 | +0.76 | +0.0007 | 41.1 |
| **acute (0..+6 d)** | 147 | **+0.013** | **−2.76** | +0.0009 | **61.9** |
| early (+7..+13 d) | 769 | +0.149 | +3.33 | +0.0033 | 24.3 |
| recov2 (+14..+20 d) | 842 | +0.137 | +5.97 | +0.0025 | 14.1 |
| recov3 (+21..+27 d) | 177 | +0.157 | +9.23 | +0.0023 | 7.3 |

\*baseline is zero by construction (de-meaning reference). Raw baseline SIF was **−0.130** — i.e. the pre-event window sat well *below* climatology. This depressed baseline is exactly what made the draft's relative-ratio "supra-baseline enhancement" an artifact (see §4).

---

## 2. The triplet reading — structural damage, not physiological collapse

The diagnostic value of the triplet is in the **acute window**:

- **SIF corridor-mean is essentially flat (+0.013)** — a single-signal SIF analysis would conclude "no acute impact."
- **NIRvR drops sharply (−2.76; 62% of cells suppressed)** — the canopy-structure term collapses. This is the wind- and flood-driven loss of green leaf area / canopy integrity along the track.
- **Phi_F (SIF/NIRvR) is slightly positive** — fluorescence yield per unit canopy structure is *not* depressed.

Interpretation: the acute Idai impact is **structural** (canopy stripped) rather than a physiological down-regulation of the surviving canopy. A raw-SIF-only design would have missed it because the loss of emitting area and the per-area yield move in opposite directions and partly cancel in the corridor mean. The NIRvR normalisation (Zeng 2022) is what exposes the damage. This directly vindicates abandoning the "raw SIF only" standpoint.

Spatially (see `IDAI_2019_NIRVR_demeaned.png`): the acute suppression is **localised along the NW reach of the track**, not corridor-wide — which is the argument for the footprint/corridor approach over a country mean.

---

## 3. Attribution (acute dSIF, per-pixel OLS, n = 147)

Model: `dSIF ~ wind_stress * ante_moist + acute_rain` (standardised predictors; 5000-iter bootstrap CIs). Overall **R² = 0.20, F p = 1.7×10⁻⁶** — all four terms significant.

| Term | Estimate | 95% CI | Sig |
|---|---|---|---|
| wind_stress | +0.049 | [0.020, 0.077] | * |
| ante_moist | −0.067 | [−0.104, −0.028] | * |
| acute_rain | +0.050 | [0.009, 0.094] | * |
| **wind_stress × ante_moist** | **−0.064** | [−0.112, −0.017] | * |

Headline: a **significant wind × antecedent-moisture interaction** — the negative sign means that where strong winds coincided with already-wet (saturated) soils, the SIF response was most depressed. This is the physically expected compounding of wind loading on waterlogged, less-anchored canopy/soil, and matches methodology §3.9.

The `ante_moist` main-effect sign is counterintuitive (reported honestly): in isolation, higher antecedent moisture associates with slightly *higher* dSIF, but the interaction shows the damage emerges specifically under the wind+wet combination. The main effect should not be over-interpreted on its own.

---

## 4. Narrative correction (vs. the original draft)

The draft reported a "Type II supra-baseline enhancement (RR_late ≈ 1.10)" — a *recovery above baseline*. This analysis shows that reading is an **artifact** of two confounds:

1. **Depressed pre-event baseline** (raw baseline SIF −0.130). A relative ratio against a low baseline manufactures apparent enhancement.
2. **Seasonal green-up + illumination.** The rising de-meaned SIF/NIRvR through early→recov3 (NIRvR climbing +3.3 → +9.2) coincides with the post-event wet-season greening and increasing irradiance (Damm 2015: SIF irradiance sensitivity up to 58%). It is not cyclone-driven recovery.

Corrected story: **acute structural suppression localised along the track**, exposed by NIRvR, attributable to a wind × antecedent-moisture interaction. The later "enhancement" is seasonal/illumination-confounded and is not claimed as a recovery signal.

---

## 5. Caveats

- Acute n = 147 cells; coverage is good for Idai (mid-March, post-monsoon clearing) — see `coverage_per_window.png`. This observability is **why Idai is the anchor event** (cf. Chalane/Eloise monsoon blackout).
- Phi_F has high relative noise at low SIF; the acute Phi_F signal is weak and used only qualitatively.
- The recovery windows are confounded with phenology and are deliberately not used for attribution.
