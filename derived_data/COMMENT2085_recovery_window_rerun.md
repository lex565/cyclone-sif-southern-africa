# Comment 1891 - recovery ratios under the corrected early window

`RR_old_1_10` reproduces the published value (days +1 to +10, overlapping the
acute window on days 1-6). `RR_new_7_13` uses `WINDOWS$early` from config.R,
the sequential window every other metric in the paper already uses. Both are
recovery relative to the same-date climatology, computed with the identical
pooled-sounding machinery, so the difference isolates the window change.

| Country | Event | Anchor | RR early old (+1..+10) | RR early new (+7..+13) | Change | Soundings old/new | RR late (+45..+60) |
|---|---|---|---|---|---|---|---|
| Botswana | Chalane 2020 | 2020-12-31 | n/a | n/a | n/a | 0 / 0 | n/a |
| Botswana | Eloise 2021 | 2021-01-25 | n/a | n/a | n/a | 0 / 0 | n/a |
| Madagascar | Ava 2018 | 2018-01-05 | n/a | n/a | n/a | 0 / 0 | n/a |
| Madagascar | Belna 2019 | 2019-12-09 | 1.65 | 1.102 | -0.548 | 8484 / 15733 | 0.972 |
| Madagascar | Chalane 2020 | 2020-12-26 | 1.042 | n/a | n/a | 1665 / 0 | n/a |
| Madagascar | Diane 2020 | 2020-01-22 | 0.973 | 1.009 | 0.036 | 5414 / 5028 | 0.974 |
| Madagascar | Eliakim 2018 | 2018-03-16 | n/a | n/a | n/a | 0 / 0 | 0.947 |
| Madagascar | Eloise 2021 | 2021-01-19 | n/a | n/a | n/a | 0 / 0 | n/a |
| Madagascar | Francisco 2020 | 2020-02-15 | 1.002 | 1.057 | 0.056 | 1595 / 5146 | 0.951 |
| Madagascar | Iman 2021 | 2021-03-05 | n/a | n/a | n/a | 0 / 0 | 1.007 |
| Malawi | Idai 2019 | 2019-03-07 | 1.339 | 1.266 | -0.073 | 2293 / 872 | 1.135 |
| Mozambique | Chalane 2020 | 2020-12-30 | 1.25 | n/a | n/a | 165 / 0 | n/a |
| Mozambique | Desmond 2019 | 2019-01-17 | 1.225 | 1.446 | 0.221 | 1643 / 1989 | 1.052 |
| Mozambique | Eloise 2021 | 2021-01-23 | n/a | n/a | n/a | 0 / 0 | n/a |
| Mozambique | Guambe 2021 | 2021-02-12 | n/a | n/a | n/a | 0 / 0 | n/a |
| Mozambique | Idai 2019 | 2019-03-04 | 0.976 | 0.917 | -0.059 | 5591 / 5976 | 1.054 |
| Mozambique | Kenneth 2019 | 2019-04-25 | 0.916 | 0.775 | -0.141 | 327 / 1263 | 0.979 |
| South_Africa | Eloise 2021 | 2021-01-24 | n/a | n/a | n/a | 0 / 0 | n/a |
| Zimbabwe | Chalane 2020 | 2020-12-30 | 1.813 | n/a | n/a | 167 / 0 | n/a |
| Zimbabwe | Eloise 2021 | 2021-01-23 | n/a | n/a | n/a | 0 / 0 | n/a |
| Zimbabwe | Idai 2019 | 2019-03-15 | 0.841 | 1.051 | 0.21 | 5026 / 4613 | 1.097 |

Events with an early-recovery value: old 11, new 8.
Within the operational +/-10% band (0.90-1.10): old 5, new 4, late 9.
