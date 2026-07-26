# Cyclone Kenneth (Apr 2019) — original manuscript metrics (Section 3)

Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. Triplet / de-meaning / attribution outputs are unchanged.

> **What "de-meaning" means (plain language).** The baseline (pre-storm) window measures how far the event year already sat from a normal year. De-meaning subtracts that constant offset from every window, so the baseline reads 0 and each window measures only the cyclone-attributable departure, not the background year bias. Full note: `../METHODS_NOTES.md`.

## Eq 1 / Eq 2 — Coverage fraction & dilution factor
| A_footprint (km2) | A_national (km2) | CF | DF |
|---|---|---|---|
| 202,931.8 | 770,805.2 | 0.263 | 3.8 |

Only 26% of Mozambique lies inside the 200 km storm footprint; a national mean would dilute the signal ~4x (DF).

## Eq 6 — % change vs baseline (naive vs corrected)
Naive uses the depressed *observed* baseline; corrected anchors to the climatological baseline level (0.440) on de-meaned anomalies.
| Window | n days | % naive | % corrected |
|---|---|---|---|
| baseline | 6 | 0.0 | 0.0 |
| pre7 | 4 | -16.2 | -17.5 |
| acute | 1 | -29.4 | -32.2 |
| early | 4 | -10.2 | -4.1 |
| recov2 | 3 | -19.3 | -6.4 |
| recov3 | 3 | -20.2 | -3.5 |

## Eq 7 — Recovery ratios
**RR_naive/corrected** divide by the *pre-event baseline* (Eq 7 literal; seasonally confounded for the late window). **RR_vs_clim** divides by the *same-date climatology* — "recovered to normal for the season" (=1 means full seasonal recovery).
| Phase | rel days | n obs | RR naive | RR corrected | RR vs climatology |
|---|---|---|---|---|---|
| early_recovery | +1..+10 | 327 | 0.856 | 0.848 | 0.916 |
| late_recovery | +45..+60 | 3538 | 0.556 | 0.523 | 0.979 |

## Eq 8 — SIF-GPP agreement (PML-V2 8-day)
- **Validation deferred — GPP not yet downloaded for Mozambique.** The SIF disruption analysis (Eq 1/2/5/6/7, §3.7, attribution Eq 9) is complete and fully independent of GPP. Eq 8 will be added once the PML-V2 tiles arrive, as an additive re-run with no SIF recomputation.

## §3.7 — Functional response classification (acute)
| Class | n cells | proportion |
|---|---|---|
| Strong suppression | 3 | 0.250 |
| Moderate suppression | 2 | 0.167 |
| Negligible | 2 | 0.167 |
| Moderate enhancement | 1 | 0.083 |
| Strong enhancement | 4 | 0.333 |
- Shannon entropy H = **1.52** (max 1.61; evenness 0.94).
- Figure: `metrics/MOZAMBIQUE_KENNETH_2019_response_classes_acute.png`

