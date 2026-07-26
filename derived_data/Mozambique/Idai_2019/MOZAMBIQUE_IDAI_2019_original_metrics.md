# Cyclone Idai (Mar 2019) — original manuscript metrics (Section 3)

Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. Triplet / de-meaning / attribution outputs are unchanged.

> **What "de-meaning" means (plain language).** The baseline (pre-storm) window measures how far the event year already sat from a normal year. De-meaning subtracts that constant offset from every window, so the baseline reads 0 and each window measures only the cyclone-attributable departure, not the background year bias. Full note: `../METHODS_NOTES.md`.

## Eq 1 / Eq 2 — Coverage fraction & dilution factor
| A_footprint (km2) | A_national (km2) | CF | DF |
|---|---|---|---|
| 322,339.2 | 770,805.2 | 0.418 | 2.4 |

Only 42% of Mozambique lies inside the 200 km storm footprint; a national mean would dilute the signal ~2x (DF).

## Eq 6 — % change vs baseline (naive vs corrected)
Naive uses the depressed *observed* baseline; corrected anchors to the climatological baseline level (0.558) on de-meaned anomalies.
| Window | n days | % naive | % corrected |
|---|---|---|---|
| baseline | 7 | 0.0 | 0.0 |
| pre7 | 7 | -6.2 | 6.1 |
| acute | 7 | -25.3 | -6.0 |
| early | 7 | -10.7 | 4.9 |
| recov2 | 4 | -29.5 | -13.1 |
| recov3 | 7 | -10.5 | 9.9 |

## Eq 7 — Recovery ratios
**RR_naive/corrected** divide by the *pre-event baseline* (Eq 7 literal; seasonally confounded for the late window). **RR_vs_clim** divides by the *same-date climatology* — "recovered to normal for the season" (=1 means full seasonal recovery).
| Phase | rel days | n obs | RR naive | RR corrected | RR vs climatology |
|---|---|---|---|---|---|
| early_recovery | +1..+10 | 5591 | 0.820 | 0.824 | 0.976 |
| late_recovery | +45..+60 | 7561 | 0.682 | 0.688 | 1.054 |

## Eq 8 — SIF-GPP agreement (PML-V2 8-day)
- **Validation deferred — GPP not yet downloaded for Mozambique.** The SIF disruption analysis (Eq 1/2/5/6/7, §3.7, attribution Eq 9) is complete and fully independent of GPP. Eq 8 will be added once the PML-V2 tiles arrive, as an additive re-run with no SIF recomputation.

## §3.7 — Functional response classification (acute)
| Class | n cells | proportion |
|---|---|---|
| Strong suppression | 20 | 0.127 |
| Moderate suppression | 23 | 0.146 |
| Negligible | 25 | 0.159 |
| Moderate enhancement | 39 | 0.248 |
| Strong enhancement | 50 | 0.318 |
- Shannon entropy H = **1.55** (max 1.61; evenness 0.96).
- Figure: `metrics/MOZAMBIQUE_IDAI_2019_response_classes_acute.png`

