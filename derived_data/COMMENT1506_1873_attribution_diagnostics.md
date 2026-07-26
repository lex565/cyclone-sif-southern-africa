# Comments 1506 and 1873 - attribution diagnostics and spatial uncertainty

Response variable: the per-cell de-meaned acute SIF anomaly (dSIF). Negative
values mean suppression, so a negative coefficient means the predictor deepens
suppression. Predictors are standardised, so estimates are comparable in size.

Block bootstrap resamples contiguous blocks of cells rather than individual
cells, so it does not assume spatial independence. Block sizes 10, 25 and 50 km
are reported so the 25 km choice can be judged rather than asserted.

| Country | Event | Term | Estimate | Naive 95% CI | 25 km block 95% CI | 10 km | 50 km |
|---|---|---|---|---|---|---|---|
| Malawi | Idai 2019 | (Intercept) | 0.0150 | -0.0298 to 0.0489  | -0.1131 to 0.0498  |  |  |
| Malawi | Idai 2019 | wind_stress | -0.0750 | -0.1385 to -0.0140 * | -0.2935 to -0.0164 * | * | * |
| Malawi | Idai 2019 | ante_moist | -0.0369 | -0.0821 to 0.0016  | -0.1570 to 0.0010  | * | * |
| Malawi | Idai 2019 | acute_rain | 0.0375 | -0.0226 to 0.0889  | -0.0349 to 0.1092  |  |  |
| Malawi | Idai 2019 | wind_stress:ante_moist | 0.0181 | -0.0313 to 0.0560  | -0.1141 to 0.0598  |  |  |
| Zimbabwe | Chalane 2020 | (Intercept) | -0.1265 | -0.1800 to -0.0748 * | -0.1844 to -0.0576 * | * | * |
| Zimbabwe | Chalane 2020 | wind_stress | 0.0276 | -0.0490 to 0.0891  | -0.0568 to 0.1035  |  |  |
| Zimbabwe | Chalane 2020 | ante_moist | 0.0904 | -0.0192 to 0.2364  | -0.0265 to 0.2589  |  |  |
| Zimbabwe | Chalane 2020 | acute_rain | -0.0379 | -0.1906 to 0.0531  | -0.1803 to 0.0620  |  |  |
| Zimbabwe | Chalane 2020 | wind_stress:ante_moist | -0.0071 | -0.1411 to 0.0315  | -0.1490 to 0.0564  |  |  |
| Zimbabwe | Idai 2019 | (Intercept) | 0.0142 | -0.0049 to 0.0354  | -0.0092 to 0.0389  |  |  |
| Zimbabwe | Idai 2019 | wind_stress | 0.0485 | 0.0193 to 0.0776 * | 0.0138 to 0.0803 * | * | * |
| Zimbabwe | Idai 2019 | ante_moist | -0.0667 | -0.1044 to -0.0281 * | -0.1105 to -0.0207 * | * | * |
| Zimbabwe | Idai 2019 | acute_rain | 0.0500 | 0.0076 to 0.0949 * | 0.0075 to 0.0987 * | * |  |
| Zimbabwe | Idai 2019 | wind_stress:ante_moist | -0.0637 | -0.1097 to -0.0166 * | -0.1176 to -0.0081 * | * |  |

## Per-event diagnostics

### Malawi / Idai 2019
- pixels 53 (rebuilt table matches published: yes)
- R2 0.211, adjusted R2 0.145, model F p = 0.0205
- residual Moran's I (k=8) = 0.047 -> little residual dependence
- Shapiro-Wilk p = 0.187; Breusch-Pagan p = 0.766
- VIF: wind_stress=1.98, ante_moist=1.50, acute_rain=1.70, wind_stress:ante_moist=1.30
- predictor correlations: wind~ante -0.41, wind~acute 0.60, ante~acute -0.17

### Zimbabwe / Chalane 2020
- pixels 58 (rebuilt table matches published: yes)
- R2 0.121, adjusted R2 0.055, model F p = 0.138
- residual Moran's I (k=8) = -0.065 -> little residual dependence
- Shapiro-Wilk p = 0.0191; Breusch-Pagan p = 0.894
- VIF: wind_stress=1.65, ante_moist=4.46, acute_rain=3.75, wind_stress:ante_moist=1.67
- predictor correlations: wind~ante 0.48, wind~acute 0.29, ante~acute 0.85

### Zimbabwe / Idai 2019
- pixels 147 (rebuilt table matches published: yes)
- R2 0.202, adjusted R2 0.179, model F p = 1.73e-06
- residual Moran's I (k=8) = 0.152 -> residual spatial dependence present
- Shapiro-Wilk p = 0.5; Breusch-Pagan p = 0.54
- VIF: wind_stress=1.09, ante_moist=3.47, acute_rain=3.56, wind_stress:ante_moist=1.03
- predictor correlations: wind~ante 0.03, wind~acute -0.13, ante~acute 0.83

Asterisk marks an interval excluding zero.
