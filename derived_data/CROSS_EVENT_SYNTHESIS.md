# Cross-event synthesis — six country-events (2018–2021)

Paste-ready summary for the Results section. All figures taken from each event's
`<EVENT>_original_metrics.md` (additive Section-3 metrics over the de-meaned
spatial pipeline). "Corrected" %-change anchors to climatological baseline level
on de-meaned anomalies (removes the depressed-baseline artifact). `RR_vs_clim`
divides each recovery window by its **same-date** climatology, so 1.0 = recovered
to seasonal normal. See `METHODS_NOTES.md` for de-meaning and daylength-correction.

## Master table

| Event | Country | Anchor date | CF | DF | Acute SIF % (corr.) | n acute d | RR_vs_clim early (+1..+10) | RR_vs_clim late (+45..+60) | Eq8 SIF–GPP (Pearson r, p, n) | §3.7 dominant class | Shannon H (evenness) | Tier |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Idai** | Zimbabwe | 2019-03-15 | 0.34 | 2.9 | **−37.8%** | 3 | 0.84 | 1.10 | r=0.74, p=0.094, n=6 | Strong enh. 34% / Strong supp. 27% | 1.52 (0.94) | ✅ full |
| **Chalane** | Zimbabwe | 2020-12-30 | 0.65 | 1.5 | **−42.9%** | 2 | 1.81 | NA | r=−0.93, p=0.247, n=3 † | Strong supp. 72% | 0.88 (0.54) | ⚠️ partial |
| **Eloise** | Zimbabwe | 2021-01-23 | 0.20 | 4.9 | NA | 0 | NA | NA | not computable | skipped | NA | ❌ blackout |
| **Idai** | Malawi | 2019-03-07 | 0.40 | 2.5 | −3.0% | 4 | 1.34 | 1.14 | **r=−0.82, p=0.048, n=6** ‡ | Strong enh. 28% / Strong supp. 21% | 1.58 (0.98) | ✅ full (Eq8 flagged) |
| **Chalane** | Botswana | 2020-12-31 | 0.47 | 2.1 | −10.2% | 1 | NA | NA | r=0.75, p=0.459, n=3 † | Strong supp. 100% (4 cells) | 0.00 (0.00) | ⚠️ partial |
| **Eloise** | Botswana | 2021-01-25 | 0.38 | 2.6 | NA | 0 | NA | NA | not computable | skipped | NA | ❌ blackout |

† **n = 3** paired 8-day composites — too few to interpret; reported for completeness only (monsoon cloud blackout limits paired SIF). Not a usable validation.
‡ **Diagnosed an artifact (2026-06-01), not SIF–GPP decoupling — do NOT report.** All six ΔSIF are positive (0.014–0.144): no SIF suppression signal exists for GPP to track. The six composites are consecutive 8-day periods; ΔSIF trends down with time (r=−0.90) while ΔGPP trends up (r=+0.64), mechanically producing the negative cross-correlation. The series is serially autocorrelated so p=0.048 is not a valid test (effective n ≪ 6), and jackknife drop-one r spans −0.70 to −1.00. By contrast Zim Idai's +0.74 is trend-independent (partial-r=0.77, no time trend, jackknife 0.55–0.92) — §3.8 validation rests on it alone.

## Coverage / dilution (Eq 1 / Eq 2)

Coverage fraction (CF) and dilution factor (DF) confirm the methods' central
argument: a *national* mean would dilute the cyclone signal 1.5–4.9×, justifying
the corridor (track ∩ country, 200 km buffer) as the analysis unit rather than
the country polygon. Largest footprint = Chalane/Zimbabwe (CF 0.65); smallest =
Eloise/Zimbabwe (CF 0.20, SE-corner clip → DF 4.9).

## What is interpretable vs not

- **Three full events** carry the results: **Idai/Zimbabwe**, **Idai/Malawi**, and
  (with caveats) **Chalane/Zimbabwe**. These have ≥1 usable acute window and
  per-pixel §3.7 grids.
- **Two blackouts** (both Eloise) returned NA in every window — austral-summer
  cyclone cloud shields erase the SIF retrieval. The honest result is *"signal
  unobservable,"* not *"no impact."* Figures render as labelled no-data panels.
- **Eq 8 is only usable for the two Idai events (n = 6).** Chalane events have
  n = 3 (not interpretable). Eloise events have no pairs.

## Headline narrative (3 robust findings)

1. **Acute SIF suppression is real and substantial where observable.** Corrected
   acute change is −37.8% (Idai/Zim) and −42.9% (Chalane/Zim) — both far deeper
   than the draft's national-mean estimates, consistent with the dilution argument.
   The smaller Malawi (−3.0%) and Botswana (−10.2%) values reflect weak/remnant
   storm phases (20–25 kt, below the 34 kt threshold) — frame as rain/flood
   exposure, not intense-wind disruption.

2. **The response is structural, not a transient dip, and recovery is partial.**
   `RR_vs_clim` shows SIF returning to ~0.84 (Idai/Zim early) and even ≥1.0 in the
   late window, *but* NIRvR stays suppressed across every post-event window in the
   full events (structural/defoliation signature documented in the triplet
   analysis). The de-meaning correction removes the draft's spurious
   "supra-baseline enhancement."

3. **Within-corridor response is highly heterogeneous.** Shannon H = 1.52–1.58
   (evenness 0.94–0.98) for the two Idai events: strong suppression and strong
   enhancement coexist across the same corridor — a single corridor mean hides
   opposing pixel-level responses. Chalane/Zim collapses toward suppression
   (H = 0.88, 72% strong-suppression), and Botswana/Chalane is degenerate (4 cells).

## Attribution (Eq 9) — per-pixel acute ΔSIF on wind × moisture + acute rain

Fitted only where ≥20 complete-case acute pixels exist. Standardised predictors,
5000-iteration bootstrap CIs. Wind = inverse-distance-to-track proxy; moisture =
CHIRPS 60-day antecedent PRCPTOT; acute_rain = CHIRPS acute-window PRCPTOT.

| Event | n_pix | R² | model p | Significant terms (95% CI) | Mechanism |
|---|---|---|---|---|---|
| **Idai / Zimbabwe** | 147 | 0.20 | 1.7×10⁻⁶ | wind +0.049*, moisture −0.067*, acute_rain +0.050*, **wind×moisture −0.064*** | wind–moisture **compounding** (damage where strong wind met saturated soil) |
| **Idai / Malawi** | 53 | 0.21 | 0.020 | **wind −0.075*** only | **proximity-to-track** drives flood-phase suppression; no interaction |
| **Chalane / Zimbabwe** | 58 | 0.12 | 0.138 ⁿˢ | none (intercept −0.126*) | spatially **uniform** suppression; no resolvable driver gradient |
| Chalane / Botswana | 4 | — | — | not fitted (n<20) | too few acute pixels |
| Eloise / Zimbabwe | — | — | — | not computable | blackout |
| Eloise / Botswana | — | — | — | not computable | blackout |

**Storm intensity controls the attribution structure:** the intense Idai/Zimbabwe
landfall (105 kt) shows wind×moisture compounding; the weak Idai flood phase over
Malawi (~25 kt) shows a pure wind-proximity gradient; the moderate Chalane (60 kt)
shows corridor-wide uniform suppression with no gradient. (Note: the Idai/Zim
main-effect signs are individually weak and partly offsetting — lead with the
significant interaction.)

## Full story — by storm, by country, combined

### By storm
- **Idai (Mar 2019)** — the anchor. Struck **Malawi** first (07 Mar, early
  tropical-storm flood phase ~25 kt), looped to sea, re-intensified, then made an
  intense **Zimbabwe** landfall (15 Mar, 105 kt). Best-observed event in both
  countries (post-monsoon clearing). Same structural signature in both: acute SIF
  physiologically near-flat while NIRvR collapses → canopy *stripped*, not
  down-regulated. **Two countries, one mechanism**; attribution differs by
  intensity (Zim compounding, Malawi proximity).
- **Chalane (Dec 2020)** — **Zimbabwe** (30 Dec, 60 kt, large footprint CF 0.65)
  with **Botswana** remnant (31 Dec, ~20 kt). Zim shows the deepest acute change
  (−42.9 %) but over only 2 days and spatially uniform (72 % strong suppression,
  H 0.88, no driver gradient). Botswana reduced to 4 acute pixels. Mid-summer →
  partial blackout.
- **Eloise (Jan 2021)** — **Zimbabwe** SE corner (23 Jan, weakened ~28 kt inland)
  and **Botswana** remnant (25 Jan). **Both full blackouts** — austral-summer
  cloud erased SIF. Honest result: *unobservable*, not *no impact*.

### By country
- **Zimbabwe (3 events)** — the core, spanning the full observability spectrum:
  Idai fully resolved (anchor), Chalane large-footprint but mid-summer partial,
  Eloise erased. The only country with attribution, recovery, and validation all
  computable (on Idai).
- **Malawi (1 event)** — Idai flood phase, fully observable, reproduces the Zim
  structural signature independently. Confirms the mechanism generalises across
  the border.
- **Botswana (2 events)** — both weak remnants under monsoon cloud; marginal
  (Chalane, 4 px) to absent (Eloise) signal. Frame as rain/flood exposure, not
  intense-wind disruption.

### Combined narrative (what the six events say together)
1. **Observability is structured, and that structure is a finding.** Post-monsoon
   landfall (Idai, March) is observable; mid-summer landfall (Chalane/Eloise,
   Dec–Jan) is cloud-blacked-out. This is a systematic limitation of optical SIF
   for austral-summer cyclones and bounds what any TROPOMI-based study can claim.
2. **Where observable, the acute response is structural, not physiological.** SIF
   yield (ΦF) is largely preserved while NIRvR collapses — the canopy loses
   fluorescing area rather than down-regulating. A raw-SIF-only design (the
   draft's) misses this because area loss and yield move oppositely and cancel in
   the mean. This is the central reason for the triplet.
3. **The draft's "supra-baseline enhancement" is an artifact** of a depressed
   baseline plus seasonal green-up and illumination — removed by de-meaning and by
   `RR_vs_clim`. The corrected story is sustained structural suppression, not
   recovery above baseline.
4. **Attribution scales with intensity:** compounding (intense) → proximity
   (weak flood) → uniform (moderate). One physical framework, intensity-dependent
   expression.
5. **GPP validation is thin** — robust only for Idai/Zimbabwe (r = 0.74). This is
   the weakest leg and the clearest target for strengthening (daily GPP).

## Eq 6 temporal-vs-spatial reconciliation — RESOLVED

Both estimators agree SIF is suppressed in the acute window (raw −0.118 to −0.178);
the −37.8 % vs +0.013 apparent contradiction is **entirely a de-meaning-offset
artifact** (corridor-scalar −0.037 vs grid-mean −0.130). The per-pixel de-meaned
*mean* is not a reliable scalar (small difference of two large quantities, and it
averages out real heterogeneity). **Report:** corridor temporal change (−37.8 %)
as regional magnitude; per-pixel grid for spatial *pattern* only; adopt one offset
convention. Full treatment in `METHODS_FINAL.md` §3.6.
