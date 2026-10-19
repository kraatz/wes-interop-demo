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

- **Host:** single-node minikube v1.38.1 (Kubernetes v1.33.12) on Ubuntu 24.04.4
  LTS, 16 vCPU, 31 GiB. Helm chart `weskit-0.2.0`, release revision 1.
- **WES server:** WESkit at the German site, reached at
  `https://192.168.49.2:30132` (WES API under `/ga4gh/wes/v1`),
  `supported_wes_versions` 1.1.0. The image is
  `registry.gitlab.com/one-touch-pipeline/weskit/api:latest`, digest
  `sha256:34bf3cb8…`. WESkit has no release tags, so the digest is the only
  precise version. `service-info.json` and `environment.txt` hold the details.
- **Engine:** Snakemake 9.16.3 on the submission worker (Python 3.13.3). WESkit ran
  `snakemake --snakefile snp-freq.smk --cores 1 --use-conda --jobs 1 --configfile config.yaml`.
  The request sets `workflow_type_version` to 7.30.2, which is the value
  `service-info` advertises, not the engine that ran — see note 6.
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
  99 (AN = 208 and 198 in the summaries). Checksums are in `environment.txt`:
  the sample lists and `target_snps.bed` are byte-identical to the Sapporo
  site's, the merged VCF is not — see note 7.
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
service-info.json  GET /ga4gh/wes/v1/service-info
environment.txt    host, cluster, WESkit image digest, engine versions,
                   input checksums
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
2. **stderr and stdout are lost and cannot be recovered.** The WESkit run log
   gives them as paths inside the run directory
   (`.weskit/2026-10-01T13:51:15.977621/stderr` and
   `.weskit/2026-10-01T13:52:01.270331/stderr`), not as content. Those
   directories no longer exist. The `/data` volume that held them is mounted
   and empty, the `WES.run` collection in MongoDB holds no documents, the
   backup taken on 2026-10-01 covers only the `workflows/` config volume, and
   no copy was kept on the client. The runs were not re-done, because
   re-running would produce a different run and this bundle documents the one
   that was compared with `example-results/`.
3. **`run_log.json` lists the whole run directory.** `outputs.filesystem` has
   31,951 entries, almost all of them files of the conda env. The intermediate
   VCFs and the Snakemake log are listed too, but only `summary.tsv` was
   downloaded.
4. **The two runs were sequential.** Concurrent runs on one worker race on the
   shared conda package cache while they create the bcftools env.
5. **Still not recorded in this bundle:** the Python package versions used for
   aggregation (`aggregate.py` ran on the client through
   `uv run --with scipy --with matplotlib --with numpy`, which resolves
   versions at run time and records none), the exact conda package list of the
   tool environment (only the `bcftools.yaml` spec is kept; the env itself was
   in the deleted run directory), and the client-side submission trace.
   The Sapporo-only bundle has all three, so the two are not symmetric.
6. **`service-info` advertises an engine version that did not run.** It lists
   SMK 7.30.2, while the submission worker has Snakemake 9.16.3, and the
   request must still set `workflow_type_version` to 7.30.2 or WESkit rejects
   it as an unknown version. The Sapporo-only run has the same problem
   (note 2 there): it advertises 9.16.3 and runs 9.22.0. Both services
   understate their engine, so in neither bundle is the version in
   `service-info` evidence of what ran.
7. **The merged input VCF differs between the two sites by checksum.** Each
   site ran `bcftools concat` itself, and `concat` writes its own command and
   date into the header, so the files cannot be byte-identical. The sample
   lists and `target_snps.bed` are byte-identical across sites. For a content
   comparison, `environment.txt` gives a checksum of the header without the
   `##bcftools*` lines and of the records at the three target SNPs; the
   Sapporo side can run the same two commands.
