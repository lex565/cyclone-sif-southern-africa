# Cyclone Idai (Mar 2019) — original manuscript metrics (Section 3)

Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. Triplet / de-meaning / attribution outputs are unchanged.

> **What "de-meaning" means (plain language).** The baseline (pre-storm) window measures how far the event year already sat from a normal year. De-meaning subtracts that constant offset from every window, so the baseline reads 0 and each window measures only the cyclone-attributable departure, not the background year bias. Full note: `../METHODS_NOTES.md`.

## Eq 1 / Eq 2 — Coverage fraction & dilution factor
| A_footprint (km2) | A_national (km2) | CF | DF |
|---|---|---|---|
| 37,686.9 | 95,414 | 0.395 | 2.5 |

Only 40% of Malawi lies inside the 200 km storm footprint; a national mean would dilute the signal ~3x (DF).

## Eq 6 — % change vs baseline (naive vs corrected)
Naive uses the depressed *observed* baseline; corrected anchors to the climatological baseline level (0.456) on de-meaned anomalies.
| Window | n days | % naive | % corrected |
|---|---|---|---|
| baseline | 6 | 0.0 | 0.0 |
| pre7 | 4 | -15.7 | -16.7 |
| acute | 4 | -15.7 | -3.0 |
| early | 5 | -14.6 | -8.3 |
| recov2 | 4 | -26.7 | -26.3 |
| recov3 | 5 | -30.9 | -34.9 |

## Eq 7 — Recovery ratios
**RR_naive/corrected** divide by the *pre-event baseline* (Eq 7 literal; seasonally confounded for the late window). **RR_vs_clim** divides by the *same-date climatology* — "recovered to normal for the season" (=1 means full seasonal recovery).
| Phase | rel days | n obs | RR naive | RR corrected | RR vs climatology |
|---|---|---|---|---|---|
| early_recovery | +1..+10 | 2293 | 0.770 | 0.698 | 1.339 |
| late_recovery | +45..+60 | 1342 | 0.535 | 0.380 | 1.135 |

## Eq 8 — SIF-GPP agreement (PML-V2 8-day)
- Pearson r = **-0.82** (p = 0.048), Spearman rho = -0.71 (p = 0.136), n = 6 composites.
- Figure: `metrics/eq8_sif_gpp_scatter.png`

> **Do not interpret this correlation (diagnosed 2026-06-01).** The negative r is an
> artifact, not SIF–GPP decoupling: (1) all six ΔSIF are **positive** (0.014–0.144) —
> SIF was above climatology with no suppression signal, so there is nothing for GPP to
> track; (2) the six composites are *consecutive* 8-day periods — ΔSIF trends down with
> time (r=−0.90, the positive anomaly relaxing to zero) while ΔGPP trends up (r=+0.64),
> mechanically producing a negative cross-correlation. The series is serially
> autocorrelated, so **p=0.048 is not a valid test** (effective n ≪ 6); (3) jackknife
> drop-one r ranges −0.70 to −1.00 (unstable on n=6). The §3.8 SIF–GPP validation rests
> on Zim Idai (r=0.74, n=6, no time trend, partial-r=0.77, jackknife 0.55–0.92).

## §3.7 — Functional response classification (acute)
| Class | n cells | proportion |
|---|---|---|
| Strong suppression | 11 | 0.208 |
| Moderate suppression | 10 | 0.189 |
| Negligible | 7 | 0.132 |
| Moderate enhancement | 10 | 0.189 |
| Strong enhancement | 15 | 0.283 |
- Shannon entropy H = **1.58** (max 1.61; evenness 0.98).
- Figure: `metrics/MALAWI_IDAI_2019_response_classes_acute.png`

