# Cyclone Chalane (Dec 2020) — original manuscript metrics (Section 3)

Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. Triplet / de-meaning / attribution outputs are unchanged.

> **What "de-meaning" means (plain language).** The baseline (pre-storm) window measures how far the event year already sat from a normal year. De-meaning subtracts that constant offset from every window, so the baseline reads 0 and each window measures only the cyclone-attributable departure, not the background year bias. Full note: `../METHODS_NOTES.md`.

## Eq 1 / Eq 2 — Coverage fraction & dilution factor
| A_footprint (km2) | A_national (km2) | CF | DF |
|---|---|---|---|
| 253,654.7 | 390,647.3 | 0.649 | 1.5 |

Only 65% of Zimbabwe lies inside the 200 km storm footprint; a national mean would dilute the signal ~2x (DF).

## Eq 6 — % change vs baseline (naive vs corrected)
Naive uses the depressed *observed* baseline; corrected anchors to the climatological baseline level (0.284) on de-meaned anomalies.
| Window | n days | % naive | % corrected |
|---|---|---|---|
| baseline | 6 | 0.0 | 0.0 |
| pre7 | 6 | 31.0 | 20.2 |
| acute | 2 | -6.8 | -42.9 |
| early | 0 | NA | NA |
| recov2 | 0 | NA | NA |
| recov3 | 0 | NA | NA |

## Eq 7 — Recovery ratios
**RR_naive/corrected** divide by the *pre-event baseline* (Eq 7 literal; seasonally confounded for the late window). **RR_vs_clim** divides by the *same-date climatology* — "recovered to normal for the season" (=1 means full seasonal recovery).
| Phase | rel days | n obs | RR naive | RR corrected | RR vs climatology |
|---|---|---|---|---|---|
| early_recovery | +1..+10 | 167 | 1.169 | 1.253 | 1.813 |
| late_recovery | +45..+60 | 0 | NA | NA | NA |

## Eq 8 — SIF-GPP agreement (PML-V2 8-day)
- Pearson r = **-0.93** (p = 0.247), Spearman rho = -1.00 (p = 0.333), n = 3 composites.
- **Caveat: n = 3 is too few to interpret** — reported for completeness only; not a usable validation (monsoon blackout limits paired composites).
- Figure: `metrics/eq8_sif_gpp_scatter.png`

## §3.7 — Functional response classification (acute)
| Class | n cells | proportion |
|---|---|---|
| Strong suppression | 42 | 0.724 |
| Moderate suppression | 1 | 0.017 |
| Negligible | 3 | 0.052 |
| Moderate enhancement | 2 | 0.034 |
| Strong enhancement | 10 | 0.172 |
- Shannon entropy H = **0.88** (max 1.61; evenness 0.54).
- Figure: `metrics/CHALANE_2020_response_classes_acute.png`

