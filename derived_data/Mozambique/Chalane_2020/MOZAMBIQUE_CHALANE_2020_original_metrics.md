# Cyclone Chalane (Dec 2020) — original manuscript metrics (Section 3)

Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. Triplet / de-meaning / attribution outputs are unchanged.

> **What "de-meaning" means (plain language).** The baseline (pre-storm) window measures how far the event year already sat from a normal year. De-meaning subtracts that constant offset from every window, so the baseline reads 0 and each window measures only the cyclone-attributable departure, not the background year bias. Full note: `../METHODS_NOTES.md`.

## Eq 1 / Eq 2 — Coverage fraction & dilution factor
| A_footprint (km2) | A_national (km2) | CF | DF |
|---|---|---|---|
| 116,931.1 | 770,805.3 | 0.152 | 6.6 |

Only 15% of Mozambique lies inside the 200 km storm footprint; a national mean would dilute the signal ~7x (DF).

## Eq 6 — % change vs baseline (naive vs corrected)
Naive uses the depressed *observed* baseline; corrected anchors to the climatological baseline level (0.472) on de-meaned anomalies.
| Window | n days | % naive | % corrected |
|---|---|---|---|
| baseline | 7 | 0.0 | 0.0 |
| pre7 | 6 | 27.8 | 21.8 |
| acute | 2 | -1.1 | -16.7 |
| early | 0 | NA | NA |
| recov2 | 0 | NA | NA |
| recov3 | 0 | NA | NA |

## Eq 7 — Recovery ratios
**RR_naive/corrected** divide by the *pre-event baseline* (Eq 7 literal; seasonally confounded for the late window). **RR_vs_clim** divides by the *same-date climatology* — "recovered to normal for the season" (=1 means full seasonal recovery).
| Phase | rel days | n obs | RR naive | RR corrected | RR vs climatology |
|---|---|---|---|---|---|
| early_recovery | +1..+10 | 165 | 1.170 | 1.211 | 1.250 |
| late_recovery | +45..+60 | 0 | NA | NA | NA |

## Eq 8 — SIF-GPP agreement (PML-V2 8-day)
- **Validation deferred — GPP not yet downloaded for Mozambique.** The SIF disruption analysis (Eq 1/2/5/6/7, §3.7, attribution Eq 9) is complete and fully independent of GPP. Eq 8 will be added once the PML-V2 tiles arrive, as an additive re-run with no SIF recomputation.

## §3.7 — Functional response classification (acute)
| Class | n cells | proportion |
|---|---|---|
| Strong suppression | 12 | 0.300 |
| Moderate suppression | 6 | 0.150 |
| Negligible | 2 | 0.050 |
| Moderate enhancement | 4 | 0.100 |
| Strong enhancement | 16 | 0.400 |
- Shannon entropy H = **1.39** (max 1.61; evenness 0.87).
- Figure: `metrics/MOZAMBIQUE_CHALANE_2020_response_classes_acute.png`

