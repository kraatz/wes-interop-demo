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

- **Host:** single-node minikube v1.38.1 at the German site, Ubuntu 24.04,
  16 vCPU, 31 GiB. Helm chart `weskit-0.2.0`, executor type `local`. The
  executing pod was `weskit-submission-worker-669dd99984-k2gx9`, as recorded
  in the engine stderr (`*/server_run_dir/.weskit/*/stderr`).
- **WES server:** WESkit, reached at `https://192.168.49.2:30132` (WES API
  under `/ga4gh/wes/v1`), `supported_wes_versions` 1.1.0, image
  `registry.gitlab.com/one-touch-pipeline/weskit/api:latest`. WESkit has no
  release tags and `setup.py` declares 0.0.1, so there is no meaningful
  version string. The `dev-4.1.0` in `service-info.json` is a chart setting,
  not a WESkit version (note 8). The image digest of the instance that ran
  was not recorded before the cluster was stopped.
- **Engine:** WESkit was asked for `SMK=7.30.2`
  (`*/server_run_dir/.weskit/*/log.json`) and ran
  `snakemake --snakefile snp-freq.smk --cores 1 --use-conda --jobs 1 --configfile config.yaml`.
  The Snakemake binary did not print its version, so the exact version is not
  recorded; it was not 7.30.2 — see note 9.
- **Workflow:** `snp-freq.smk` and `bcftools.yaml` are sent as
  `workflow_attachment`. Both are identical to repository tag `v1.0.0`
  (`b7c8c95`).
- **Parameters:** `params/jpt_params_weskit.json` and
  `params/ceu_params_smk.json`. The JPT file is the CEU file with the sample
  list and labels changed to JPT.
- **Tool environment:** Snakemake builds a conda env from `bcftools.yaml`
  (bcftools 1.21 `h3a4d415_1`, htslib 1.24 `ha79157c_0`, the same versions as
  in the Sapporo-only run). The full list of 151 packages with URLs and MD5s
  is in `*/conda_env_explicit.txt`.
- **Input data:** `ALL.chr2_12_15.GRCh38.phased.vcf.gz` under
  `/workflows/wes-interop-demo/data/1000g/`. JPT has 104 samples and CEU has
  99 (AN = 208 and 198 in the summaries). Checksums are in `environment.txt`:
  the sample lists and `target_snps.bed` are byte-identical to the Sapporo
  site's, and the merged VCF matches it in content but not byte for byte —
  see note 10.
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
service-info.json    GET /ga4gh/wes/v1/service-info (see note 8)
environment.txt      host, cluster, engine, tool and input versions
JPT/ and CEU/
  run_log.json       GET /ga4gh/wes/v1/runs/{id} (as received, single line)
  summary.tsv        GET /weskit/v1/runs/{id}/outputs/summary.tsv
  conda_env_explicit.txt         the 151 packages of the tool env
  genotype_intermediates.sha256  checksums of the intermediate VCFs
  server_run_dir/    the WESkit run directory, without the conda env:
                     config.yaml, the attachments as received,
                     regions.normalized.bed, the intermediate VCFs,
                     summary.tsv, .snakemake/ (log, metadata, env spec)
                     and .weskit/<start time>/ (see note 2):
      stderr         engine stderr
      stdout         engine stdout, empty for both runs
      log.json       WESkit's record of cmd, env, workdir, times
combined/            aggregate.py output (TSV + plot)
```

## Notes and deviations

1. **The files were moved into this layout after the run.** The submit script
   first wrote a flat `results-weskit/` directory (`runlog_jpt.json`,
   `summary_jpt.tsv`, ...). The files were moved here unchanged, so that both
   cross-check runs share one layout. The script now writes this layout
   directly.
2. **stderr, stdout and the run directories were recovered after the fact.**
   The WESkit run log gives stderr and stdout as paths inside the run
   directory (`.weskit/<start time>/stderr`), not as content, and the client
   kept no copy. The cluster that ran them was stopped on 2026-10-14, so they
   were recovered on 2026-10-19 from its stopped node, under
   `/var/hostpath-provisioner/default/data-pvc/{c8e3,9ee2}/`. They are the
   runs documented here: the recovered `summary.tsv` of each run is
   byte-identical to the `summary.tsv` in this bundle, which was downloaded
   from the API on the day of the run. The files are copied verbatim, with
   one change: `:` in the `.weskit/<start time>/` directory names is
   replaced by `-` (`2026-10-01T13:51:15.977621` becomes
   `2026-10-01T13-51-15.977621`), because Windows does not allow `:` in
   file names. `run_log.json` and `log.json` keep the original paths.
3. **stdout is empty for both runs.** The files are included at length zero
   rather than omitted, because WESkit's run log points at them and an absent
   file would be ambiguous. Snakemake writes its progress to stderr.
4. **The conda environment directory is not included.** It is about 1.5 GB per
   run. The env spec (`server_run_dir/.snakemake/conda/*.yaml`) and the
   explicit package list (`*/conda_env_explicit.txt`, reconstructed from the
   environment's own `conda-meta/`) are included instead.
5. **Genotype-level intermediates are included.** `subset.raw.vcf.gz`,
   `subset.vcf.gz` and `tagged.vcf.gz` under `server_run_dir/` hold per-sample
   genotypes at the 3 target SNPs, for public 1000 Genomes samples. They are
   kept so the run directory is complete, and because WESkit listed them among
   the run's outputs and would have served them from the same endpoint as
   `summary.tsv`. Their checksums are in `*/genotype_intermediates.sha256`.
6. **The two runs were sequential.** Concurrent runs on one worker race on the
   shared conda package cache while they create the bcftools env.
7. **`run_log.json` lists the whole run directory.** `outputs.filesystem` has
   31,951 entries, almost all of them files of the conda env. The intermediate
   VCFs and the Snakemake log are listed too, but only `summary.tsv` was
   downloaded.
8. **`service-info.json` was captured after the run, from a redeployment.**
   The instance that ran was never queried for it, and that cluster is gone.
   The file is included because the engine lists in it are read from the
   WESkit configuration, and the configuration of the instance that ran
   declares the same engines (NFL 23.04.1, SMK 7.30.2). Treat it as the
   configuration of this deployment, not as a record of the run. Its
   `version` (`dev-4.1.0`) is not a WESkit version: service-info returns
   `static_service_info.version` from the WESkit configuration, and the
   `weskit-0.2.0` chart sets it to `dev-4.1.0` in
   `configs/weskit/config.yaml.tpl`, next to placeholder values such as
   `https://example.org` and the `tag1`/`tag2` tags.
9. **The engine version that actually ran is not recorded, and it was not
   7.30.2.** WESkit requires `workflow_type_version` to be 7.30.2, the only
   SMK version it advertises, and passes it on as `WESKIT_WORKFLOW_ENGINE`.
   But the Snakemake binary on the worker never printed its version, and the
   log wording ("Assuming unrestricted shared filesystem usage.",
   "Execute 1 jobs...") is Snakemake 8/9, not 7.30.2. The Sapporo-only run has
   the same class of problem (note 2 there): it advertises 9.16.3 and runs
   9.22.0. In neither bundle is the version in `service-info` evidence of what
   ran.
10. **The merged input VCF differs between the two sites by checksum, not by
   content.** Each site ran `bcftools concat` itself, and `concat` writes its
   own command and date into the header, so the files cannot be
   byte-identical. `environment.txt` gives two content checksums instead:
   of the header without the `##bcftools*` lines, and of the records at the
   three target SNPs. The Sapporo site's merged VCF no longer exists, but a
   rebuild from its source files gives the same two checksums, and the
   intermediate VCFs of the two runs have identical records and headers
   apart from the `##bcftools*` lines (note 7 of the Sapporo-only README).
   The sample lists and `target_snps.bed` are byte-identical across sites.
11. **Still not recorded:** the Python package versions used for aggregation.
    `aggregate.py` ran on the client through
    `uv run --with scipy --with matplotlib --with numpy`, which resolves
    versions at run time and records none. The Sapporo-only bundle has them in
    `combined/AGGREGATION_ENV.txt`, so the two are not symmetric here. The
    client-side submission trace was likewise not kept, and the submit script
    does not write one.
