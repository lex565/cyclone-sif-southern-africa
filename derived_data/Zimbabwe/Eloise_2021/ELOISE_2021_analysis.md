# Cyclone Eloise — Zimbabwe vegetation response (TROPOMI SIF triplet)

**Event:** Tropical Cyclone Eloise · closest-approach anchor 2021-01-23
**Sensor:** TROPOMI TROPOSIF L2B (SIF_Corr_743, daylength-corrected)
**Domain:** 200 km track-buffer corridor ∩ Zimbabwe, 0.1° grid, min 2 soundings/cell
**Climatology:** non-event years 2018, 2019, 2020 (±4-day pooling)

Figures (in `spatial_maps/`):
- `ELOISE_2021_triplet_demeaned.png` — combined SIF / NIRvR / Phi_F (documented blackout)
- `ELOISE_2021_SIF_demeaned.png`, `..._NIRVR_demeaned.png`, `..._PHIF_demeaned.png`
- `ELOISE_2021_coverage_per_window.png`

---

## 1. Result: complete observational blackout

**Every BER window (baseline through recov3) returns zero QC-passing soundings** in the Zimbabwe corridor. There is no SIF, NIRvR, or Phi_F signal to report, and no attribution is possible.

| Window | n_cells |
|---|---|
| baseline (−14..−8 d) | 0 |
| pre7 (−7..−1 d) | 0 |
| acute (0..+6 d) | 0 |
| early (+7..+13 d) | 0 |
| recov2 (+14..+20 d) | 0 |
| recov3 (+21..+27 d) | 0 |

The figures are retained deliberately: each panel shows the Zimbabwe outline, the SE-corner corridor where Eloise clipped the country, and an explicit red "no data" tag per window. They are an honest record of the blackout, not a missing result.

---

## 2. Why — the observability wall

Eloise made landfall near Beira (central Mozambique) on 23 January and crossed southeastern Zimbabwe on 23–24 January, at the **peak of the wet season**. The persistent monsoon cloud deck means TROPOMI (which requires near-cloud-free scenes, cloud fraction < 0.02 here) cannot see the surface in any window around the event.

This was tested explicitly: relaxing the cloud-fraction threshold (0.02 → 0.80) does **not** salvage the recovery windows — they remain empty. The blackout is physical, not a QC artifact.

## 3. Implication

Eloise is the clearest demonstration of the **TROPOMI observability wall** for peak-monsoon (Dec–Jan) cyclones over the region. It defines the upper limit of what the SIF approach can observe and is the reason the quantitative attribution is anchored on Idai (mid-March, post-monsoon, well observed). Eloise contributes to the results as **methodological evidence of the observability limit**, not as an impact measurement.
