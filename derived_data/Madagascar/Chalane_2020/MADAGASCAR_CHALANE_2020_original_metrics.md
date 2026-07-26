# Cyclone Chalane (Dec 2020) — original manuscript metrics (Section 3)

Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. Triplet / de-meaning / attribution outputs are unchanged.

> **What "de-meaning" means (plain language).** The baseline (pre-storm) window measures how far the event year already sat from a normal year. De-meaning subtracts that constant offset from every window, so the baseline reads 0 and each window measures only the cyclone-attributable departure, not the background year bias. Full note: `../METHODS_NOTES.md`.

## Eq 1 / Eq 2 — Coverage fraction & dilution factor
| A_footprint (km2) | A_national (km2) | CF | DF |
|---|---|---|---|
| 255,657.9 | 590,084.8 | 0.433 | 2.3 |

Only 43% of Madagascar lies inside the 200 km storm footprint; a national mean would dilute the signal ~2x (DF).

## Eq 6 — % change vs baseline (naive vs corrected)
Naive uses the depressed *observed* baseline; corrected anchors to the climatological baseline level (0.328) on de-meaned anomalies.
| Window | n days | % naive | % corrected |
|---|---|---|---|
| baseline | 7 | 0.0 | 0.0 |
| pre7 | 7 | 31.8 | 17.3 |
| acute | 5 | 11.0 | -9.5 |
| early | 0 | NA | NA |
| recov2 | 0 | NA | NA |
| recov3 | 0 | NA | NA |

## Eq 7 — Recovery ratios
**RR_naive/corrected** divide by the *pre-event baseline* (Eq 7 literal; seasonally confounded for the late window). **RR_vs_clim** divides by the *same-date climatology* — "recovered to normal for the season" (=1 means full seasonal recovery).
| Phase | rel days | n obs | RR naive | RR corrected | RR vs climatology |
|---|---|---|---|---|---|
| early_recovery | +1..+10 | 1665 | 1.555 | 1.441 | 1.042 |
| late_recovery | +45..+60 | 0 | NA | NA | NA |

## Eq 8 — SIF-GPP agreement (PML-V2 8-day)
- **Validation deferred — GPP not yet downloaded for Madagascar.** The SIF disruption analysis (Eq 1/2/5/6/7, §3.7, attribution Eq 9) is complete and fully independent of GPP. Eq 8 will be added once the PML-V2 tiles arrive, as an additive re-run with no SIF recomputation.

## §3.7 — Functional response classification (acute)
| Class | n cells | proportion |
|---|---|---|
| Strong suppression | 143 | 0.278 |
| Moderate suppression | 62 | 0.120 |
| Negligible | 55 | 0.107 |
| Moderate enhancement | 73 | 0.142 |
| Strong enhancement | 182 | 0.353 |
- Shannon entropy H = **1.49** (max 1.61; evenness 0.93).
- Figure: `metrics/MADAGASCAR_CHALANE_2020_response_classes_acute.png`

