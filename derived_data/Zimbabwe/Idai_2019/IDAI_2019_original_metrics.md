# Cyclone Idai — original manuscript metrics (Section 3)

Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. The
triplet / de-meaning / attribution outputs are unchanged.

> **What "de-meaning" means (plain language).** The baseline (pre-storm) window
> measures how far the event year already sat from a normal year. Here 2019 ran
> ~0.037 SIF units below the 2018/2020/2021 climatology *before* Idai arrived.
> De-meaning subtracts that constant offset from every window, so the baseline
> reads 0 and each window measures only the cyclone-attributable departure, not
> the background year bias. This is also what stops a depressed baseline from
> faking "supra-baseline enhancement." Full note: `../METHODS_NOTES.md`.

## Eq 1 / Eq 2 — Coverage fraction & dilution factor
| A_footprint (km2) | A_national (km2) | CF | DF |
|---|---|---|---|
| 132,781.1 | 390,647.3 | 0.340 | 2.9 |

Only 34% of Zimbabwe lies inside the 200 km storm footprint; a national mean would dilute the signal ~3x (DF).

## Eq 6 — % change vs baseline (naive vs corrected)
Naive uses the depressed *observed* baseline (manufactures enhancement); corrected anchors to the climatological baseline level (0.373) on de-meaned anomalies.
| Window | n days | % naive | % corrected |
|---|---|---|---|
| baseline | 6 | +0.0 | +0.0 |
| pre7 | 7 | -26.3 | -25.2 |
| acute | 3 | -42.4 | -37.8 |
| early | 4 | -13.3 | +9.3 |
| recov2 | 5 | -29.1 | +3.2 |
| recov3 | 4 | -43.5 | -23.1 |

## Eq 7 — Recovery ratios
RR = window level / reference level. **RR_naive/corrected** divide by the *pre-event baseline* (methods Eq 7 literal) — these are confounded by seasonal phenology for the late window (mid-May senescence vs March baseline). **RR_vs_clim** divides by the *same-date climatology*, removing phenology: it answers "did SIF return to normal *for that time of year*" (=1 means fully recovered to seasonal normal).
| Phase | rel days | n obs | RR naive | RR corrected | RR vs climatology |
|---|---|---|---|---|---|
| early_recovery | +1..+10 | 5026 | 0.747 | 0.767 | 0.841 |
| late_recovery | +45..+60 | 17453 | 0.437 | 0.489 | 1.097 |

## Eq 8 — SIF-GPP agreement (PML-V2 8-day)
SIF anomaly aggregated to the 8-day GPP composite grid, paired with GPP anomaly (event - climatology).
- Pearson r = **0.74** (p = 0.094), Spearman rho = 0.89 (p = 0.033), n = 6 composites.
- Figure: `metrics/eq8_sif_gpp_scatter.png`

## §3.7 — Functional response classification (acute)
| Class | n cells | proportion |
|---|---|---|
| Strong suppression | 39 | 0.265 |
| Moderate suppression | 21 | 0.143 |
| Negligible | 16 | 0.109 |
| Moderate enhancement | 21 | 0.143 |
| Strong enhancement | 50 | 0.340 |
- Shannon entropy H = **1.52** (max 1.61; evenness 0.94) — very high within-corridor response heterogeneity (strong suppression and strong enhancement coexist across the corridor).
- Figure: `metrics/IDAI_2019_response_classes_acute.png`

