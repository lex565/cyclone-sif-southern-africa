# Cyclone Desmond (Jan 2019) — original manuscript metrics (Section 3)

Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. Triplet / de-meaning / attribution outputs are unchanged.

> **What "de-meaning" means (plain language).** The baseline (pre-storm) window measures how far the event year already sat from a normal year. De-meaning subtracts that constant offset from every window, so the baseline reads 0 and each window measures only the cyclone-attributable departure, not the background year bias. Full note: `../METHODS_NOTES.md`.

## Eq 1 / Eq 2 — Coverage fraction & dilution factor
| A_footprint (km2) | A_national (km2) | CF | DF |
|---|---|---|---|
| 227,809.7 | 770,805.4 | 0.295 | 3.4 |

Only 30% of Mozambique lies inside the 200 km storm footprint; a national mean would dilute the signal ~3x (DF).

## Eq 6 — % change vs baseline (naive vs corrected)
Naive uses the depressed *observed* baseline; corrected anchors to the climatological baseline level (0.358) on de-meaned anomalies.
| Window | n days | % naive | % corrected |
|---|---|---|---|
| baseline | 6 | 0.0 | 0.0 |
| pre7 | 7 | 101.4 | 68.2 |
| acute | 6 | 88.4 | 35.5 |
| early | 7 | 80.9 | 43.8 |
| recov2 | 7 | 69.0 | 42.0 |
| recov3 | 7 | 37.5 | 0.6 |

## Eq 7 — Recovery ratios
**RR_naive/corrected** divide by the *pre-event baseline* (Eq 7 literal; seasonally confounded for the late window). **RR_vs_clim** divides by the *same-date climatology* — "recovered to normal for the season" (=1 means full seasonal recovery).
| Phase | rel days | n obs | RR naive | RR corrected | RR vs climatology |
|---|---|---|---|---|---|
| early_recovery | +1..+10 | 1643 | 1.872 | 1.760 | 1.225 |
| late_recovery | +45..+60 | 3671 | 1.200 | 1.170 | 1.052 |

## Eq 8 — SIF-GPP agreement (PML-V2 8-day)
- **Validation deferred — GPP not yet downloaded for Mozambique.** The SIF disruption analysis (Eq 1/2/5/6/7, §3.7, attribution Eq 9) is complete and fully independent of GPP. Eq 8 will be added once the PML-V2 tiles arrive, as an additive re-run with no SIF recomputation.

## §3.7 — Functional response classification (acute)
| Class | n cells | proportion |
|---|---|---|
| Strong suppression | 7 | 0.538 |
| Moderate suppression | 3 | 0.231 |
| Negligible | 0 | 0.000 |
| Moderate enhancement | 0 | 0.000 |
| Strong enhancement | 3 | 0.231 |
- Shannon entropy H = **1.01** (max 1.61; evenness 0.63).
- Figure: `metrics/MOZAMBIQUE_DESMOND_2019_response_classes_acute.png`

