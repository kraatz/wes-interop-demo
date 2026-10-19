# snp-freq.smk — SNP allele frequency summary
#
# Computes AC/AN/AF for target SNPs from a population VCF.
# Only aggregate statistics are output — no per-sample genotypes.
#
# Config keys (passed via --configfile in the WES request):
#   vcf      path to bgzipped, tabix-indexed multi-sample VCF
#   samples  path to text file with one sample ID per line
#   regions  path to BED file of target SNP positions (BED format, 0-based)
#   site_id  string label for output (e.g. "JPT" or "CEU")
#   bcftools_env optional conda environment path (default: envs/bcftools.yaml)

VCF     = config["vcf"]
SAMPLES = config["samples"]
REGIONS = config["regions"]
SITE_ID = config["site_id"]
BCFTOOLS_ENV = config.get("bcftools_env", "envs/bcftools.yaml")


rule all:
    input:
        "summary.tsv",


rule subset:
    """Subset multi-sample VCF to site-specific samples and target SNP regions."""
    input:
        vcf=VCF,
        tbi=VCF + ".tbi",
        samples=SAMPLES,
        regions=REGIONS,
    output:
        "subset.vcf.gz",
    conda:
        BCFTOOLS_ENV
    shell:
        r"""
        # Match BED chromosome naming to the VCF contig style (chr-prefixed vs plain).
        FIRST_CONTIG=$(bcftools view -h {input.vcf} | awk -F'[=,]' '/^##contig=<ID=/{{print $3; exit}}')
        if [[ "$FIRST_CONTIG" == chr* ]]; then
          awk 'BEGIN{{OFS="\t"}} /^#/ {{print; next}} {{if ($1 !~ /^chr/) $1="chr"$1; print}}' {input.regions} > regions.normalized.bed
        else
          awk 'BEGIN{{OFS="\t"}} /^#/ {{print; next}} {{sub(/^chr/, "", $1); print}}' {input.regions} > regions.normalized.bed
        fi
        bcftools view \
          --samples-file {input.samples} \
          --regions-file regions.normalized.bed \
          --output-type z \
          --output subset.raw.vcf.gz \
          {input.vcf}
        # Replace/define VCF ID from BED col4 so downstream summary has stable SNP labels.
        bcftools annotate \
          --annotations regions.normalized.bed \
          --columns CHROM,FROM,TO,ID \
          --output-type z \
          --output {output} \
          subset.raw.vcf.gz
        """


rule fill_tags:
    """Compute AC, AN, AF INFO tags from the subsetted VCF."""
    input:
        "subset.vcf.gz",
    output:
        "tagged.vcf.gz",
    conda:
        BCFTOOLS_ENV
    shell:
        "bcftools +fill-tags {input} "
        "--output-type z "
        "--output {output} "
        "-- --tags=AC,AN,AF"


rule query:
    """Extract summary TSV (SNP_ID, REF, ALT, AC, AN, AF, SITE). No per-sample data."""
    input:
        "tagged.vcf.gz",
    output:
        "summary.tsv",
    params:
        site_id=SITE_ID,
    conda:
        BCFTOOLS_ENV
    shell:
        "printf '#SNP_ID\\tREF\\tALT\\tAC\\tAN\\tAF\\tSITE\\n' > {output} && "
        "bcftools query "
        "--format '%ID\\t%REF\\t%ALT\\t%AC\\t%AN\\t%AF\\t{params.site_id}\\n' "
        "{input} >> {output}"
