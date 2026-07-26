# Cyclone Chalane (Dec 2020) — original manuscript metrics (Section 3)

Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. Triplet / de-meaning / attribution outputs are unchanged.

> **What "de-meaning" means (plain language).** The baseline (pre-storm) window measures how far the event year already sat from a normal year. De-meaning subtracts that constant offset from every window, so the baseline reads 0 and each window measures only the cyclone-attributable departure, not the background year bias. Full note: `../METHODS_NOTES.md`.

## Eq 1 / Eq 2 — Coverage fraction & dilution factor
| A_footprint (km2) | A_national (km2) | CF | DF |
|---|---|---|---|
| 270,048.6 | 578,070.9 | 0.467 | 2.1 |

Only 47% of Botswana lies inside the 200 km storm footprint; a national mean would dilute the signal ~2x (DF).

## Eq 6 — % change vs baseline (naive vs corrected)
Naive uses the depressed *observed* baseline; corrected anchors to the climatological baseline level (0.194) on de-meaned anomalies.
| Window | n days | % naive | % corrected |
|---|---|---|---|
| baseline | 6 | 0.0 | 0.0 |
| pre7 | 6 | 15.2 | 0.5 |
| acute | 1 | 9.6 | -10.2 |
| early | 0 | NA | NA |
| recov2 | 0 | NA | NA |
| recov3 | 0 | NA | NA |

## Eq 7 — Recovery ratios
**RR_naive/corrected** divide by the *pre-event baseline* (Eq 7 literal; seasonally confounded for the late window). **RR_vs_clim** divides by the *same-date climatology* — "recovered to normal for the season" (=1 means full seasonal recovery).
| Phase | rel days | n obs | RR naive | RR corrected | RR vs climatology |
|---|---|---|---|---|---|
| early_recovery | +1..+10 | 0 | NA | NA | NA |
| late_recovery | +45..+60 | 0 | NA | NA | NA |

## Eq 8 — SIF-GPP agreement (PML-V2 8-day)
- Pearson r = **0.75** (p = 0.459), Spearman rho = 0.50 (p = 1.000), n = 3 composites.
- **Caveat: n = 3 is too few to interpret** — reported for completeness only; not a usable validation (monsoon blackout limits paired composites).
- Figure: `metrics/eq8_sif_gpp_scatter.png`

## §3.7 — Functional response classification (acute)
| Class | n cells | proportion |
|---|---|---|
| Strong suppression | 4 | 1.000 |
| Moderate suppression | 0 | 0.000 |
| Negligible | 0 | 0.000 |
| Moderate enhancement | 0 | 0.000 |
| Strong enhancement | 0 | 0.000 |
- Shannon entropy H = **-0.00** (max 1.61; evenness -0.00).
- Figure: `metrics/BOTSWANA_CHALANE_2020_response_classes_acute.png`

