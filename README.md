# wes-interop-demo

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21184327.svg)](https://doi.org/10.5281/zenodo.21184327)

A federated bioinformatics demonstration using two WES implementations:

- **Japanese site** — [Sapporo](https://github.com/sapporo-wes/sapporo-service) on AWS EC2
- **German site** — [WESkit](https://weskit.bihealth.org/) on collaborator infrastructure

## Scenario

A researcher compares allele frequencies of population-differentiated SNPs between Japanese (JPT) and European (CEU) cohorts from the [1000 Genomes Project](https://www.internationalgenome.org/). Raw WGS data cannot leave each site. Each site runs an identical workflow locally, computes summary statistics, and returns only aggregate allele counts — no per-sample data leaves the site.

The researcher (or an AI agent) submits workflows to both WES endpoints, waits for results, and aggregates them into a population comparison.

## Workflow

The primary workflow is **Snakemake** (`workflow/snp-freq.smk`), used because WESkit does not support CWL. The pipeline runs three steps via bcftools (conda env: `workflow/envs/bcftools.yaml`):

1. `subset` — restrict to site samples and target SNP regions (`bcftools view`)
2. `fill_tags` — compute AC, AN, AF INFO tags (`bcftools +fill-tags`)
3. `query` — extract summary TSV with no per-sample data (`bcftools query`)

A CWL equivalent (`workflow/snp-freq.cwl` + `workflow/tools/`) is kept as reference.

## Repository structure

```
workflow/         Snakemake workflow, conda env, and CWL reference tools
data/             Target SNP positions, sample lists
params/           WES run parameters for each site (*_smk.json = active)
scripts/          Aggregation script, submission shell script
docs/             Narrative, setup guides, next steps
infra/            EC2 deployment for the Sapporo/Japanese site
tests/            Synthetic test data and expected outputs
```

## Quick start

See [docs/demo.md](docs/demo.md) for the full walkthrough.

## Requirements

- `curl`, `jq`, `python3` with `scipy` and `matplotlib`
- Access to a Sapporo WES endpoint (Japanese site)
- Access to a WESkit endpoint (German site)

## Zenodo

This repository will be archived on Zenodo upon publication.

## License

Apache 2.0
