# Cyclone Francisco (Feb 2020) — original manuscript metrics (Section 3)

Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. Triplet / de-meaning / attribution outputs are unchanged.

> **What "de-meaning" means (plain language).** The baseline (pre-storm) window measures how far the event year already sat from a normal year. De-meaning subtracts that constant offset from every window, so the baseline reads 0 and each window measures only the cyclone-attributable departure, not the background year bias. Full note: `../METHODS_NOTES.md`.

## Eq 1 / Eq 2 — Coverage fraction & dilution factor
| A_footprint (km2) | A_national (km2) | CF | DF |
|---|---|---|---|
| 103,953.8 | 590,084.8 | 0.176 | 5.7 |

Only 18% of Madagascar lies inside the 200 km storm footprint; a national mean would dilute the signal ~6x (DF).

## Eq 6 — % change vs baseline (naive vs corrected)
Naive uses the depressed *observed* baseline; corrected anchors to the climatological baseline level (0.436) on de-meaned anomalies.
| Window | n days | % naive | % corrected |
|---|---|---|---|
| baseline | 6 | 0.0 | 0.0 |
| pre7 | 6 | 8.3 | 11.3 |
| acute | 4 | -27.0 | -27.8 |
| early | 6 | -4.3 | -6.4 |
| recov2 | 6 | 7.1 | 3.2 |
| recov3 | 4 | -18.2 | -14.5 |

## Eq 7 — Recovery ratios
**RR_naive/corrected** divide by the *pre-event baseline* (Eq 7 literal; seasonally confounded for the late window). **RR_vs_clim** divides by the *same-date climatology* — "recovered to normal for the season" (=1 means full seasonal recovery).
| Phase | rel days | n obs | RR naive | RR corrected | RR vs climatology |
|---|---|---|---|---|---|
| early_recovery | +1..+10 | 1595 | 1.020 | 1.017 | 1.002 |
| late_recovery | +45..+60 | 2274 | 0.783 | 0.778 | 0.951 |

## Eq 8 — SIF-GPP agreement (PML-V2 8-day)
- **Validation deferred — GPP not yet downloaded for Madagascar.** The SIF disruption analysis (Eq 1/2/5/6/7, §3.7, attribution Eq 9) is complete and fully independent of GPP. Eq 8 will be added once the PML-V2 tiles arrive, as an additive re-run with no SIF recomputation.

## §3.7 — Functional response classification (acute)
| Class | n cells | proportion |
|---|---|---|
| Strong suppression | 12 | 0.316 |
| Moderate suppression | 9 | 0.237 |
| Negligible | 8 | 0.211 |
| Moderate enhancement | 6 | 0.158 |
| Strong enhancement | 3 | 0.079 |
- Shannon entropy H = **1.53** (max 1.61; evenness 0.95).
- Figure: `metrics/MADAGASCAR_FRANCISCO_2020_response_classes_acute.png`

