# Cyclone Ava (Jan 2018) — original manuscript metrics (Section 3)

Additive layer over the de-meaned spatial pipeline. Files in `metrics/`. Triplet / de-meaning / attribution outputs are unchanged.

> **What "de-meaning" means (plain language).** The baseline (pre-storm) window measures how far the event year already sat from a normal year. De-meaning subtracts that constant offset from every window, so the baseline reads 0 and each window measures only the cyclone-attributable departure, not the background year bias. Full note: `../METHODS_NOTES.md`.

## Eq 1 / Eq 2 — Coverage fraction & dilution factor
| A_footprint (km2) | A_national (km2) | CF | DF |
|---|---|---|---|
| 211,931 | 590,084.8 | 0.359 | 2.8 |

Only 36% of Madagascar lies inside the 200 km storm footprint; a national mean would dilute the signal ~3x (DF).

## Eq 6 — % change vs baseline (naive vs corrected)
Naive uses the depressed *observed* baseline; corrected anchors to the climatological baseline level (0.335) on de-meaned anomalies.
| Window | n days | % naive | % corrected |
|---|---|---|---|
| baseline | 0 | NA | NA |
| pre7 | 0 | NA | NA |
| acute | 0 | NA | NA |
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
- **Validation deferred — GPP not yet downloaded for Madagascar.** The SIF disruption analysis (Eq 1/2/5/6/7, §3.7, attribution Eq 9) is complete and fully independent of GPP. Eq 8 will be added once the PML-V2 tiles arrive, as an additive re-run with no SIF recomputation.

## §3.7 — Functional response classification
- Skipped: acute window has no usable per-pixel grid (blacked out).

