# Methods notes (plain-language) — paste-ready for the manuscript

## Baseline de-meaning (year-offset correction)

**Plain meaning:** *subtract how far the event year already sat from a normal
year **before** the storm, so the analysis measures only what the storm itself
did — not a pre-existing good/bad-year bias.*

**Why it is needed.** For each grid cell the anomaly is the observed event-year
SIF minus the multi-year climatology (Eq 5). In a normal year the pre-event
(baseline) window should read ≈ 0. In practice the event year often carries a
corridor-wide offset unrelated to the cyclone. For Cyclone Idai the baseline
window sat at observed SIF 0.333 against a climatological level of 0.373 — a
**−0.037 offset**, i.e. 2019 was already a slightly low-SIF year across the whole
corridor before landfall.

**What is done.** The mean anomaly over the baseline window (the offset) is
computed per signal (SIF, NIRvR, ΦF) and subtracted from every window:

```
de-meaned anomaly  =  raw anomaly  −  baseline-window mean anomaly
```

After this the baseline window is exactly 0 by construction, and every other
window measures the departure attributable to the cyclone rather than the
background year bias. Example (Idai acute): raw anomaly −0.178 → de-meaned
−0.141 once the −0.037 year bias is removed.

**Why it matters here.** The earlier draft's "supra-baseline enhancement" arose
from comparing later windows to the *depressed observed baseline* (0.333); a low
baseline makes anything near normal look like a rise. De-meaning anchors the
comparison to the true seasonal level (0.373) so a low baseline can no longer
manufacture an apparent recovery.

**Assumption / caveat.** De-meaning treats the year-offset as spatially uniform
and constant over the analysis window. If the bias were itself patchy in space
or drifting in time, this is an approximation — but it is a standard, defensible
one and strictly better than leaving the bias in.

---

## Daylength (diurnal) correction — product-applied

The TROPOSIF L2B product provides two SIF variables: `SIF_743` (instantaneous,
~13:30 overpass) and `SIF_Corr_743` (long_name "daylength-corr SIF"). This
analysis uses `SIF_Corr_743`, i.e. the daylength correction of Eq 3–4 (Köhler et
al. 2018) is **already applied by the product**. Verified empirically: the mean
ratio `SIF_Corr_743 / SIF_743 = 0.33`, matching the reported daily correction
factor (DCF ≈ 0.353). Re-applying Köhler would double-count, so Eq 3–4 are cited
as product-applied rather than recomputed.
