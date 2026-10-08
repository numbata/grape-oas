# grape-oas generation benchmarks

Generated: 2026-10-08T22:40:38Z
Ruby: ruby 3.3.6 (2024-11-05 revision 75015d4c1f) [arm64-darwin24]

Lower milliseconds are better. Negative changes mean faster generation.

## 100 routes · OpenAPI 2.0

Version | Median ms | Range ms | vs previous | vs oldest
--- | ---: | ---: | ---: | ---:
v1.0.3 (efc58951) | 156.21 | 52.33–248.50 | — | —
v1.1.0 (9b476a1e) | 147.52 | 53.37–248.04 | -5.6% | -5.6%
v1.2.0 (8b3ac106) | 157.56 | 53.21–257.82 | +6.8% | +0.9%
v1.3.0 (7648306b) | 146.06 | 52.62–254.56 | -7.3% | -6.5%
v1.4.0 (eda6ce52) | 9.33 | 8.80–15.25 | -93.6% | -94.0%
v1.5.1 (00ab3e4d) | 10.70 | 9.68–15.50 | +14.7% | -93.1%
v1.6.0 (8b2dd871) | 10.85 | 9.84–13.14 | +1.4% | -93.1%
main (439440ea) | 11.48 | 10.70–14.67 | +5.8% | -92.6%


## 100 routes · OpenAPI 3.0

Version | Median ms | Range ms | vs previous | vs oldest
--- | ---: | ---: | ---: | ---:
v1.0.3 (efc58951) | 432.40 | 311.55–515.16 | — | —
v1.1.0 (9b476a1e) | 403.45 | 289.56–524.55 | -6.7% | -6.7%
v1.2.0 (8b3ac106) | 403.38 | 295.68–523.86 | -0.0% | -6.7%
v1.3.0 (7648306b) | 403.43 | 315.84–504.68 | +0.0% | -6.7%
v1.4.0 (eda6ce52) | 9.56 | 8.56–15.08 | -97.6% | -97.8%
v1.5.1 (00ab3e4d) | 10.39 | 9.95–11.50 | +8.7% | -97.6%
v1.6.0 (8b2dd871) | 11.22 | 10.52–12.12 | +7.9% | -97.4%
main (439440ea) | 11.41 | 10.73–12.19 | +1.7% | -97.4%


## 100 routes · OpenAPI 3.1

Version | Median ms | Range ms | vs previous | vs oldest
--- | ---: | ---: | ---: | ---:
v1.0.3 (efc58951) | 680.19 | 573.69–838.65 | — | —
v1.1.0 (9b476a1e) | 719.86 | 587.56–822.02 | +5.8% | +5.8%
v1.2.0 (8b3ac106) | 723.37 | 565.26–842.01 | +0.5% | +6.3%
v1.3.0 (7648306b) | 685.61 | 541.50–879.14 | -5.2% | +0.8%
v1.4.0 (eda6ce52) | 9.38 | 8.88–10.60 | -98.6% | -98.6%
v1.5.1 (00ab3e4d) | 10.75 | 10.17–13.55 | +14.6% | -98.4%
v1.6.0 (8b2dd871) | 11.49 | 10.38–14.91 | +6.9% | -98.3%
main (439440ea) | 11.76 | 10.62–15.67 | +2.3% | -98.3%


## 500 routes · OpenAPI 2.0

Version | Median ms | Range ms | vs previous | vs oldest
--- | ---: | ---: | ---: | ---:
v1.0.3 (efc58951) | — | —–— | — | —
v1.1.0 (9b476a1e) | — | —–— | — | —
v1.2.0 (8b3ac106) | — | —–— | — | —
v1.3.0 (7648306b) | — | —–— | — | —
v1.4.0 (eda6ce52) | 55.42 | 51.08–59.52 | — | —
v1.5.1 (00ab3e4d) | 66.86 | 63.92–72.83 | +20.6% | —
v1.6.0 (8b2dd871) | 71.46 | 65.25–178.14 | +6.9% | —
main (439440ea) | 67.88 | 63.98–90.90 | -5.0% | —

Failure for v1.0.3: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.1.0: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.2.0: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.3.0: Timed out after 30 seconds, including warmup and measured generations

## 500 routes · OpenAPI 3.0

Version | Median ms | Range ms | vs previous | vs oldest
--- | ---: | ---: | ---: | ---:
v1.0.3 (efc58951) | — | —–— | — | —
v1.1.0 (9b476a1e) | — | —–— | — | —
v1.2.0 (8b3ac106) | — | —–— | — | —
v1.3.0 (7648306b) | — | —–— | — | —
v1.4.0 (eda6ce52) | 58.13 | 55.41–64.27 | — | —
v1.5.1 (00ab3e4d) | 63.56 | 59.29–71.00 | +9.4% | —
v1.6.0 (8b2dd871) | 65.83 | 57.60–70.54 | +3.6% | —
main (439440ea) | 67.43 | 59.70–69.98 | +2.4% | —

Failure for v1.0.3: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.1.0: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.2.0: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.3.0: Timed out after 30 seconds, including warmup and measured generations

## 500 routes · OpenAPI 3.1

Version | Median ms | Range ms | vs previous | vs oldest
--- | ---: | ---: | ---: | ---:
v1.0.3 (efc58951) | — | —–— | — | —
v1.1.0 (9b476a1e) | — | —–— | — | —
v1.2.0 (8b3ac106) | — | —–— | — | —
v1.3.0 (7648306b) | — | —–— | — | —
v1.4.0 (eda6ce52) | 59.73 | 55.88–62.57 | — | —
v1.5.1 (00ab3e4d) | 63.27 | 58.46–68.13 | +5.9% | —
v1.6.0 (8b2dd871) | 64.27 | 59.65–76.98 | +1.6% | —
main (439440ea) | 62.96 | 56.19–71.27 | -2.0% | —

Failure for v1.0.3: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.1.0: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.2.0: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.3.0: Timed out after 30 seconds, including warmup and measured generations

## 1000 routes · OpenAPI 2.0

Version | Median ms | Range ms | vs previous | vs oldest
--- | ---: | ---: | ---: | ---:
v1.0.3 (efc58951) | — | —–— | — | —
v1.1.0 (9b476a1e) | — | —–— | — | —
v1.2.0 (8b3ac106) | — | —–— | — | —
v1.3.0 (7648306b) | — | —–— | — | —
v1.4.0 (eda6ce52) | 123.49 | 111.86–129.40 | — | —
v1.5.1 (00ab3e4d) | 133.63 | 128.10–136.94 | +8.2% | —
v1.6.0 (8b2dd871) | 132.72 | 129.54–139.58 | -0.7% | —
main (439440ea) | 137.48 | 132.45–154.73 | +3.6% | —

Failure for v1.0.3: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.1.0: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.2.0: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.3.0: Timed out after 30 seconds, including warmup and measured generations

## 1000 routes · OpenAPI 3.0

Version | Median ms | Range ms | vs previous | vs oldest
--- | ---: | ---: | ---: | ---:
v1.0.3 (efc58951) | — | —–— | — | —
v1.1.0 (9b476a1e) | — | —–— | — | —
v1.2.0 (8b3ac106) | — | —–— | — | —
v1.3.0 (7648306b) | — | —–— | — | —
v1.4.0 (eda6ce52) | 121.18 | 116.77–134.80 | — | —
v1.5.1 (00ab3e4d) | 141.03 | 136.36–154.15 | +16.4% | —
v1.6.0 (8b2dd871) | 137.74 | 132.91–141.71 | -2.3% | —
main (439440ea) | 139.12 | 122.99–146.15 | +1.0% | —

Failure for v1.0.3: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.1.0: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.2.0: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.3.0: Timed out after 30 seconds, including warmup and measured generations

## 1000 routes · OpenAPI 3.1

Version | Median ms | Range ms | vs previous | vs oldest
--- | ---: | ---: | ---: | ---:
v1.0.3 (efc58951) | — | —–— | — | —
v1.1.0 (9b476a1e) | — | —–— | — | —
v1.2.0 (8b3ac106) | — | —–— | — | —
v1.3.0 (7648306b) | — | —–— | — | —
v1.4.0 (eda6ce52) | 120.86 | 118.56–128.06 | — | —
v1.5.1 (00ab3e4d) | 138.10 | 126.56–147.95 | +14.3% | —
v1.6.0 (8b2dd871) | 137.28 | 128.47–155.73 | -0.6% | —
main (439440ea) | 129.66 | 121.90–139.30 | -5.5% | —

Failure for v1.0.3: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.1.0: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.2.0: Timed out after 30 seconds, including warmup and measured generations
Failure for v1.3.0: Timed out after 30 seconds, including warmup and measured generations

## Methodology

1 warmup generation; 10 measured generations per case.
Case budget: 30 seconds. Timed-out cases have no partial timings or comparisons.
Harness: b6feb9a364630d560c2561711dba6a3c592bb1bb
GrapeOAS.generate; excludes API setup and JSON serialization

Environment and exact dependencies:

```json
{
  "ruby": "ruby 3.3.6 (2024-11-05 revision 75015d4c1f) [arm64-darwin24]",
  "os": "Darwin 24.6.0 arm64",
  "cpu": "Apple M1 Pro",
  "jit": "disabled",
  "dependencies": {
    "base64": "0.3.0",
    "bigdecimal": "4.1.3",
    "concurrent-ruby": "1.3.8",
    "connection_pool": "3.0.2",
    "drb": "2.2.3",
    "i18n": "1.15.2",
    "json": "3.0.2",
    "logger": "1.7.0",
    "prism": "1.9.0",
    "minitest": "6.0.5",
    "securerandom": "0.4.1",
    "tzinfo": "2.0.6",
    "uri": "1.1.2",
    "activesupport": "8.1.4",
    "bundler": "4.0.8",
    "zeitwerk": "2.7.5",
    "dry-core": "1.2.0",
    "dry-configurable": "1.4.0",
    "dry-inflector": "1.3.1",
    "dry-logic": "1.6.0",
    "dry-types": "1.9.1",
    "mustermann": "4.0.0",
    "mustermann-grape": "1.1.0",
    "rack": "3.2.7",
    "grape": "3.1.1",
    "rack-test": "2.2.0"
  },
  "lockfile_sha256": "ed87b264038d5ee152f88a0bcf39eb99ca421536bef58163a40c1fe21e4544a9"
}
```
