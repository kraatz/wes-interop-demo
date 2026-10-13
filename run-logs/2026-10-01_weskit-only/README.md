# WESkit-only run, 2026-10-01

Both populations (JPT and CEU) were run on a single WESkit instance at the
German site and submitted through the GA4GH WES API. Running both on one
implementation separates workflow behaviour from implementation differences.
The results are compared against the federated results in `example-results/`
(v1.0.0: JPT on Sapporo, CEU on WESkit, June 2026). The Sapporo-only
counterpart is in `../2026-10-09_sapporo-only/`.

## Result

All outputs are byte-identical to `example-results/` in v1.0.0:

| File | Compared with | Result |
|---|---|---|
| `JPT/summary.tsv` | `example-results/summary_jpt.tsv` | identical |
| `CEU/summary.tsv` | `example-results/summary_ceu.tsv` | identical |
| `combined/combined_results.tsv` | `example-results/combined_results.tsv` | identical |

The same three files are also identical to those of the Sapporo-only run.
The plot (`combined/allele_freq_comparison.png`) is not compared, because its
bytes depend on the matplotlib build.

## Setup

- **WES server:** WESkit at the German site, reached at
  `https://192.168.49.2:30132` (WES API under `/ga4gh/wes/v1`).
- **Engine:** Snakemake. WESkit ran
  `snakemake --snakefile snp-freq.smk --cores 1 --use-conda --jobs 1 --configfile config.yaml`.
  The request sets `workflow_type_version` to 7.30.2.
- **Workflow:** `snp-freq.smk` and `bcftools.yaml` are sent as
  `workflow_attachment`. Both are identical to repository tag `v1.0.0`
  (`b7c8c95`).
- **Parameters:** `params/jpt_params_weskit.json` and
  `params/ceu_params_smk.json`. The JPT file is the CEU file with the sample
  list and labels changed to JPT.
- **Tool environment:** Snakemake builds a conda env from `bcftools.yaml`
  (bcftools 1.21, htslib 1.24, the same builds as in the Sapporo-only run).
  The package names come from the `conda-meta/` entries listed in
  `*/run_log.json`.
- **Input data:** `ALL.chr2_12_15.GRCh38.phased.vcf.gz` under
  `/workflows/wes-interop-demo/data/1000g/`. JPT has 104 samples and CEU has
  99 (AN = 208 and 198 in the summaries).
- **Client:** `scripts/submit_weskit_only.sh` submitted both runs, downloaded
  the results, ran `aggregate.py` and compared the output with
  `example-results/`.

## Runs

| Site | run_id | Started | Ended | State | Exit |
|---|---|---|---|---|---|
| JPT | `c8e3e865-af8f-4a63-974d-0ff88096eb07` | 2026-10-01T13:51:15 | 2026-10-01T13:51:59 | COMPLETE | 0 |
| CEU | `9ee227a3-dcb4-41ec-a248-71a88b83a1f3` | 2026-10-01T13:52:01 | 2026-10-01T13:52:52 | COMPLETE | 0 |

Times are as reported in the WESkit run log, which does not state a time zone.

## Layout

```
JPT/ and CEU/
  run_log.json     GET /ga4gh/wes/v1/runs/{id} (as received, single line)
  summary.tsv      GET /weskit/v1/runs/{id}/outputs/summary.tsv
combined/          aggregate.py output (TSV + plot)
```

## Notes and deviations

1. **The files were moved into this layout after the run.** The submit script
   first wrote a flat `results-weskit/` directory (`runlog_jpt.json`,
   `summary_jpt.tsv`, ...). The files were moved here unchanged, so that both
   cross-check runs share one layout. The script now writes this layout
   directly.
2. **stderr and stdout are not included.** The WESkit run log gives them as
   paths inside the run directory (`.weskit/<start time>/stderr`), not as
   content.
3. **`run_log.json` lists the whole run directory.** `outputs.filesystem` has
   31,951 entries, almost all of them files of the conda env. The intermediate
   VCFs and the Snakemake log are listed too, but only `summary.tsv` was
   downloaded.
4. **The two runs were sequential.** Concurrent runs on one worker race on the
   shared conda package cache while they create the bcftools env.
5. **Not recorded in this bundle:** the WESkit version and its
   `service-info`, the Snakemake version that ran, input file checksums, and
   the Python package versions used for aggregation.
