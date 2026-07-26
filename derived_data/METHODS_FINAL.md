# Materials and Methods — realized analysis (final)

*Written to mirror the manuscript's Section 3 prose. Documents which of the
original equations (Eq 1–9) were retained, which were corrected, and why, as
implemented in the R pipeline (`G:\Alex\Results\R_Scripts`). A closing section
lists the adjustments still required for publication readiness.*

---

## 3.1 Event selection and analytical unit

This study quantifies cyclone-induced vegetation functional disruption across
Southern Africa using a physiologically anchored, event-based disturbance
framework. The analytical unit is the **storm-country event** — the period during
which a tropical-cyclone track intersects a national boundary. Events were
extracted from IBTrACS v04r01 (southwest Indian Ocean basin) by intersecting each
storm's interpolated track *line* with the national polygon and dating entry to
the first boundary crossing. This line-intersection rule replaces the earlier
centre-point-inside test, which discarded events whose centre crossed a border
between six-hourly fixes (e.g. Cyclone Eloise over southeastern Zimbabwe).

The realized analysis spans **2018–2021**, the interval for which TROPOMI SIF is
available on disk; the 2022 storms (Ana, Gombe) are excluded for want of SIF.
Three storms intersecting three countries yield **six storm-country events**:
Idai (Zimbabwe, Malawi), Chalane (Zimbabwe, Botswana), and Eloise (Zimbabwe,
Botswana). Of these, three are fully observable (Idai/Zimbabwe, Idai/Malawi,
Chalane/Zimbabwe), and three are limited or erased by austral-summer cloud
(Chalane/Botswana partially; both Eloise events completely). The differential
observability is itself reported as a result rather than concealed.

## 3.2 Data sources

The primary physiological indicator is solar-induced chlorophyll fluorescence from
TROPOMI/Sentinel-5P, TROPOSIF Level-2B at 743 nm (`SIF_Corr_743`). Independent
carbon-flux validation uses PML-V2 gross primary productivity (8-day composites,
500 m). Daily precipitation is from CHIRPS v2.0. Cyclone position, intensity, and
track geometry are from IBTrACS. National boundaries and ecoregions delimit the
analytical units. All extraction is performed in EPSG:4326; equal-area buffering
for the corridor is performed in a storm-centred Lambert azimuthal projection.

## 3.3 Footprint-scale spatial framework — **Eq 1, Eq 2 (retained)**

Country-level aggregation is rejected. For each event the IBTrACS track line is
buffered by 200 km (the minimum radius capturing all candidate events in a
100/150/200/300 km sensitivity sweep) and intersected with the national polygon
to define the corridor. Two diagnostics quantify the cost of national averaging:

- **Eq 1 — Coverage fraction:** `CF = A_footprint / A_national`
- **Eq 2 — Dilution factor:** `DF = 1 / CF = A_national / A_footprint`

These are diagnostic only and enter no SIF/GPP computation. Realized values range
from CF = 0.20 (Eloise/Zimbabwe, DF 4.9) to CF = 0.65 (Chalane/Zimbabwe, DF 1.5),
confirming that a national mean would dilute the disturbance signal 1.5–4.9×.

## 3.4 TROPOMI SIF retrieval and QC — **Eq 3, Eq 4 (retained, product-applied)**

Only retrievals with cloud fraction < 0.02, solar zenith angle < 85°, and NIR
radiance 20–200 mW m⁻² sr⁻¹ nm⁻¹ are retained; cells additionally require NDVI >
0.10 to exclude water and bare ground. The diurnal (daylength) correction of
Köhler et al. (2018) — **Eq 3** with the daily correction factor **Eq 4** — is
**applied by the product**: `SIF_Corr_743` is the daylength-corrected variable.
This was verified empirically (`SIF_Corr_743 / SIF_743 ≈ 0.33`, matching the
reported DCF ≈ 0.353). Equations 3–4 are therefore cited as product-applied;
re-applying them would double-count the correction. Soundings are composited to a
0.1° grid requiring ≥ 2 soundings per cell.

### Structural normalisation — the triplet (new, beyond the original draft)

Raw SIF alone conflates two competing acute responses: loss of fluorescing canopy
area (structural) and change in per-area fluorescence yield (physiological). To
separate them the analysis adds the near-infrared radiance of vegetation,
`NIRvR = NDVI × NIR_radiance`, and the structurally normalised yield
`ΦF = SIF / NIRvR` (Zeng et al. 2022). The **SIF / NIRvR / ΦF triplet** is the
central methodological addition: a flat SIF with collapsed NIRvR and preserved ΦF
diagnoses *structural* damage (canopy stripped) rather than physiological
down-regulation. NIRvR cancels the fluorescence escape fraction and needs no PAR
input, making it well suited to TROPOMI.

## 3.5 Baseline construction and anomaly — **Eq 5 (retained) + de-meaning (new)**

A pre-event window (here −14 to −8 days relative to entry) defines the baseline
state. For each grid cell and calendar day a multi-year climatology is built from
the non-event years (2018/2020/2021 for a 2019 event, etc.) using **±4-day pooling**
to stabilise the sparse reference (~25–30 samples per relative day versus ~3).

- **Eq 5 — anomaly:** `ΔSIF = SIF_obs − SIF_clim`

A **year-offset de-meaning** step is added on top of Eq 5: the mean anomaly over
the baseline window (the corridor's pre-storm departure from climatology) is
subtracted from every window, so the baseline reads 0 by construction and each
window measures only the cyclone-attributable departure. This is required because
the event year often carries a corridor-wide offset unrelated to the storm (Idai
2019 sat −0.037 below climatology before landfall). De-meaning prevents a
depressed baseline from manufacturing apparent "supra-baseline enhancement."
*Caveat:* it treats the offset as spatially uniform and time-constant — an
approximation discussed in §3.6 and in the publication-readiness notes.

## 3.6 Disruption and recovery — **Eq 6, Eq 7 (retained, corrected)**

- **Eq 6 — percentage change:** reported in two forms. The *naive* form divides by
  the depressed observed baseline (the draft's formulation, which manufactures
  enhancement); the *corrected* form anchors to the climatological baseline level
  and uses de-meaned anomalies. Only the corrected form is interpreted.
- **Eq 7 — recovery ratio:** reported as the literal pre-event-baseline ratio
  (`RR_naive`/`RR_corrected`) *and* as `RR_vs_clim`, which divides each recovery
  window by its **same-date** climatology to remove seasonal phenology (a March
  baseline versus a May recovery window otherwise confounds senescence with
  cyclone recovery). `RR_vs_clim` is the honest recovery measure.

### Reconciliation of the two Eq 6 estimators (temporal vs spatial)

Eq 6 admits two estimators that diverge for Idai/Zimbabwe and must be reconciled
explicitly. The **temporal** estimator (corridor daily means averaged over the
acute window) gives a raw acute anomaly of −0.178 and, after de-meaning by the
corridor-scalar offset (−0.037), −37.8 % of baseline. The **spatial** estimator
(per-pixel grid mean) gives a raw acute anomaly of −0.117 and, after de-meaning by
the per-pixel grid offset (−0.130), +0.013 (apparently flat). **Both raw
anomalies are negative** — SIF is suppressed by 12–18 % under either estimator;
the qualitative result is robust. The divergence lies entirely in the *de-meaning
offset* (−0.037 corridor-scalar versus −0.130 grid-mean), which differs because
the two estimators weight space versus sounding density differently and the sparse
baseline window constrains the offset poorly. The per-pixel de-meaned **mean**
(+0.013) is the small difference of two large, differently-referenced quantities
and additionally averages out genuine spatial heterogeneity (Shannon H = 1.52;
strong suppression and strong enhancement coexist). It is therefore **not used as
a scalar headline.** The corridor temporal change (−37.8 %, ≈ the draft's −38.8 %)
is reported as the regional disruption magnitude, and the per-pixel grid is used
for spatial *pattern* (localised suppression along the northwest track reach), not
for a single mean. A single offset convention (corridor-scalar) should be adopted
for both estimators in the final manuscript.

## 3.7 Functional response classification (corrected thresholds)

Per-pixel de-meaned acute anomalies are classified into five symmetric classes
relative to the climatological baseline level: strong suppression (< −20 %),
moderate suppression (−20 % to −5 %), negligible (±5 %), moderate enhancement
(+5 % to +20 %), strong enhancement (> +20 %). The earlier ±1.96 SD band was
rejected because canopy heterogeneity inflated the band until 94 % of cells read
"negligible." Within-corridor heterogeneity is summarised by Shannon entropy H of
the class proportions (max ln 5 = 1.61). Realized H ranges from 0.00
(Chalane/Botswana, 4 cells, all suppressed) to 1.58 (Idai/Malawi, near-maximal
heterogeneity).

## 3.8 Validation against GPP — **Eq 8 (retained, thin)**

- **Eq 8 — Pearson r** between SIF and GPP anomalies, aggregated to the 8-day
  composite grid, with Spearman ρ reported alongside.

Realized validation is **thin and rests on a single event**: Idai/Zimbabwe gives
r = 0.74 (ρ = 0.89, n = 6), a trend-independent positive association (see notes).
The Chalane events have only n = 3 paired composites (not interpretable), the
Eloise events none, and Idai/Malawi's r = −0.82 is a diagnosed artifact (no SIF
suppression signal to track; opposing time trends in ΔSIF and ΔGPP across six
serially-autocorrelated consecutive composites; jackknife unstable −0.70 to
−1.00) and is **not** reported as decoupling. The 8-day product yields too few
cloud-free paired composites; a daily GPP product is required to strengthen §3.8.

## 3.9 Attribution — **Eq 9 (retained, generalised)**

Per-pixel acute de-meaned ΔSIF is regressed on three drivers on the common 0.1°
grid:

- **Eq 9:** `ΔSIF = β0 + β1·wind + β2·moisture + β3·(wind × moisture) + ε`

where **wind** is a distance-decay proxy `1/(1 + d_km/50)` for proximity to the
in-country track, **moisture** is CHIRPS 60-day antecedent PRCPTOT per cell, and an
**acute-rainfall** term (CHIRPS acute-window PRCPTOT) is included. Coefficients use
standardised predictors with 5000-iteration bootstrap confidence intervals.
Attribution is fitted only where ≥ 20 complete-case acute pixels exist — three
events qualify:

| Event | n | R² | model p | Significant terms (95 % bootstrap CI) | Reading |
|---|---|---|---|---|---|
| Idai / Zimbabwe | 147 | 0.20 | 1.7×10⁻⁶ | wind +0.049*, moisture −0.067*, acute_rain +0.050*, **wind×moisture −0.064*** | wind–moisture **compounding**: damage where strong wind met saturated soil |
| Idai / Malawi | 53 | 0.21 | 0.020 | **wind −0.075*** only | **proximity-to-track** controls flood-phase suppression; no interaction |
| Chalane / Zimbabwe | 58 | 0.12 | 0.138 | none (intercept −0.126*) | spatially **uniform** suppression; no resolvable driver gradient |

Eloise (both) and Chalane/Botswana (4 pixels) cannot support pixel-level
attribution. Storm intensity appears to control the attribution structure: the
intense Idai/Zimbabwe landfall shows wind×moisture compounding; the weak Idai
flood phase over Malawi shows a pure wind-proximity gradient; the moderate Chalane
shows uniform suppression with no gradient.

## 3.10 / 3.11 Stratification and statistics

Ecosystem stratification (§3.10) and the full inferential apparatus of §3.11
(Moran's I spatial autocorrelation, spatially-corrected standard errors) are
**specified but not yet realized** in the current pipeline — see below.

---

# Methodological adjustments required for publication readiness

Ordered by severity.

1. **Reconcile scope claims with realized data.** The methods text claims
   2018–2022 and *eighteen* storm-country events with a 63 km/h + 100 km track +
   cloud-free criterion. The realized analysis is 2018–2021 with *six* events from
   three storms, of which three are cloud-limited/erased. Rewrite §3.1 to the
   realized scope and frame the blackouts as a finding (optical-SIF observability
   of austral-summer cyclones), not a gap to hide.

2. **Single de-meaning convention.** Adopt one offset estimator (corridor-scalar
   recommended) for *both* temporal and spatial Eq 6, and report raw anomalies as
   primary with de-meaning as a robustness layer. Currently the temporal and
   spatial estimators use different offsets (−0.037 vs −0.130), producing the
   apparent −37.8 % vs +0.013 contradiction (resolved in §3.6 above).

3. **Strengthen or downscope §3.8 validation.** Validation rests on one event
   (Idai/Zimbabwe). Either acquire a **daily GPP product** (FluxSat v2, 0.05°) to
   raise paired-composite counts, or state explicitly that GPP cross-validation is
   demonstrated for the anchor event only. Do not report Idai/Malawi's negative r
   as decoupling.

4. **Spatial autocorrelation in attribution.** §3.11 promises Moran's I and
   spatially-corrected standard errors; neither is implemented. Per-pixel OLS with
   row-bootstrap **does not** correct for spatial autocorrelation, so the
   attribution CIs are optimistic. Implement Moran's I and either spatial-error
   regression or a spatial block bootstrap, or remove the §3.11 claim.

5. **Wind proxy vs methods text.** Eq 9 text describes wind as "derived from
   cyclone intensity and attenuated with distance," but the code uses a pure
   inverse-distance proxy with **no MSW intensity weighting**. Either weight the
   proxy by per-fix maximum sustained wind, or rephrase the text to a
   distance-decay exposure proxy. (Across events this also matters because Idai's
   105 kt and Eloise's ~28 kt inland are treated identically by distance alone.)

6. **Fix the attribution narrative sign error.** `IDAI_2019_analysis.md` §3 states
   higher antecedent moisture associates with *higher* ΔSIF, but the coefficient is
   **−0.067** (wetter → more suppression). Correct the prose; lead with the
   significant interaction and note the main effects are individually weak and
   partly offsetting.

7. **Operationalise §3.7 thresholds in the text.** The methods text still mixes
   magnitude and recovery into the "strong suppression" definition. Replace with
   the implemented symmetric ±5 %/±20 % five-class scheme and report normalised
   Shannon evenness.

8. **Resolve promised-but-unused data products.** Methods §3.2 lists ETCCDI
   indices (RX1day, R95pTOT) and §3.10 lists ESA-CCI ecosystem stratification;
   only PRCPTOT and unstratified results are produced. Either compute and use them
   or trim the claims.

9. **GPP units audit.** Confirm the kg C m⁻² (8-day) → g C m⁻² d⁻¹ conversion of
   §3.2 is applied in the Eq 8 pairing (paired GPP values are ~800–950, consistent
   with an 8-day sum, not a daily rate). Make units consistent end-to-end.

10. **Report n and uncertainty on every mean.** Acute windows with n_days = 0–2
    (Eloise, Chalane) must carry the sample size in-table; corridor means should
    carry confidence intervals. Several headline numbers currently rest on 1–3
    days or composites.
