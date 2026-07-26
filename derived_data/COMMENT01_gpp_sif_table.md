# Comment 1 - SIF-GPP paired-composite results (Table 6 replacement)

Source: `<event>/metrics/eq8_sif_gpp_pairs.csv`, written by
`Results/R_Scripts/00_shared/original_metrics.R :: eq8_sif_gpp()`.
Pairing unit is the PML-V2 8-day GPP composite. The daily SIF anomaly is
averaged onto the same composite start-DOY grid; the GPP anomaly is the
event year minus the mean of the climatology years over the identical
composite. All correlations use R `cor.test` exact small-sample p-values.

| Country | Storm | Pairs | Pearson r | 95% CI | Pearson p | Spearman rho | Spearman p | Lag-1 dSIF / dGPP | Durbin-Watson | n_eff | Leave-one-out r | Interpretation |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Botswana | Chalane 2020 | 3 | 0.751 | n/a to n/a | 0.4590 | 0.500 | 1.0000 | -0.22 / -0.01 | 2.98 | 3.0 | n/a to n/a | n = 3: descriptive only, no inference; Pearson not significant; no strong serial correlation |
| Malawi | Idai 2019 | 6 | -0.816 | -0.98 to -0.01 | 0.0476 | -0.714 | 0.1360 | 0.29 / -0.36 | 1.51 | 7.4 | -1.00 to -0.70 | small n: descriptive, highly uncertain; Pearson significant; no strong serial correlation; NEGATIVE association |
| Mozambique | Chalane 2020 | 3 | 0.960 | n/a to n/a | 0.1810 | 0.500 | 1.0000 | -0.24 / -0.09 | 2.74 | 2.9 | n/a to n/a | n = 3: descriptive only, no inference; Pearson not significant; no strong serial correlation |
| Mozambique | Desmond 2019 | 6 | 0.126 | -0.76 to 0.85 | 0.8130 | 0.086 | 0.9190 | -0.37 / -0.00 | 2.17 | 6.0 | -0.28 to 0.49 | small n: descriptive, highly uncertain; 95% CI spans zero; Pearson not significant; one composite shifts r by >0.25; no strong serial correlation |
| Mozambique | Idai 2019 | 6 | 0.683 | -0.29 to 0.96 | 0.1350 | 0.771 | 0.1030 | 0.04 / 0.10 | 1.84 | 5.9 | 0.66 to 0.78 | small n: descriptive, highly uncertain; 95% CI spans zero; Pearson not significant; no strong serial correlation |
| Mozambique | Kenneth 2019 | 6 | 0.917 | 0.41 to 0.99 | 0.0101 | 0.600 | 0.2420 | -0.34 / -0.02 | 2.37 | 5.9 | 0.48 to 0.99 | small n: descriptive, highly uncertain; Pearson significant; one composite shifts r by >0.25; no strong serial correlation |
| Zimbabwe | Chalane 2020 | 3 | -0.926 | n/a to n/a | 0.2470 | -1.000 | 0.3330 | -0.13 / -0.00 | 2.99 | 3.0 | n/a to n/a | n = 3: descriptive only, no inference; Pearson not significant; no strong serial correlation; NEGATIVE association |
| Zimbabwe | Idai 2019 | 6 | 0.737 | -0.18 to 0.97 | 0.0944 | 0.886 | 0.0333 | -0.25 / -0.01 | 1.43 | 6.0 | 0.55 to 0.92 | small n: descriptive, highly uncertain; 95% CI spans zero; Pearson not significant; Spearman significant; no strong serial correlation |

## Reading rules applied

- Three pairs cannot support inference; those rows are descriptive only.
- A 95% CI spanning zero means the sign of the association is not established.
- Cross-product agreement with a modelled GPP product is corroboration, not
  field validation, and does not license substituting SIF for GPP.
- Durbin-Watson near 2.0 indicates no serial correlation in the residuals;
  n_eff is the Dawdy-Matalas effective sample size. Where n_eff exceeds n, the
  two series are effectively anti-persistent and an autocorrelation correction
  would strengthen, not weaken, the nominal significance.
