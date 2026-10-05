# EC2 Setup — Japanese Site (Sapporo)

## Instance

- **AMI**: Ubuntu 24.04 LTS
- **Type**: t3.large (2 vCPU, 8 GB RAM) or larger depending on data volume
- **Storage**: 100 GB gp3 (for VCF data + Docker images)
- **Security group**: inbound TCP 443 (HTTPS) or 1122 (if within VPN only)

## 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu
newgrp docker
```

## 2. Deploy Sapporo

```bash
mkdir -p ~/sapporo && cd ~/sapporo

# Download compose file pinned to v2.2.5 (first release with SAPPORO_EXTRA_DOCKER_ARGS)
curl -O https://raw.githubusercontent.com/sapporo-wes/sapporo-service/2.2.5/compose.yml

# Pin the image version
export SAPPORO_VERSION=2.2.5

# Start
docker compose up -d

# Verify
curl localhost:1122/service-info | jq .workflow_engine_versions
```

## 3. Prepare and mount VCF data

The target SNPs span chromosomes 2, 12, and 15. Download the per-chromosome
1000 Genomes phase 3 VCFs and merge them into a single file:

```bash
# Download chr2, chr12, chr15 (example — adjust URL for your mirror)
BASE=https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502
for CHR in 2 12 15; do
  wget ${BASE}/ALL.chr${CHR}.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz{,.tbi}
done

# Merge and index
bcftools concat --allow-overlaps \
  ALL.chr2.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz \
  ALL.chr12.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz \
  ALL.chr15.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz \
  --output-type z --output ALL.chr2_12_15.phase3.vcf.gz
tabix -p vcf ALL.chr2_12_15.phase3.vcf.gz
```

Recommended layout on the host:

```
/data/
├── 1000g/
│   ├── ALL.chr2_12_15.phase3.vcf.gz
│   ├── ALL.chr2_12_15.phase3.vcf.gz.tbi
│   └── jpt_samples.txt
└── wes-interop-demo/
    └── data/
        └── target_snps.bed
```

Make `/data` accessible to Sapporo's inner workflow containers via
`SAPPORO_EXTRA_DOCKER_ARGS` in `compose.yml`:

```yaml
environment:
  - SAPPORO_EXTRA_DOCKER_ARGS=-v /data:/data
```

This passes `-v /data:/data` to the `snakemake/snakemake` container that
executes the workflow, so it can read files at `/data/1000g/...`.

## 4. Restrict executable workflows (data governance)

Create `executable_workflows.json` to allow only the reviewed workflow:

```json
{
  "workflows": [
    "https://raw.githubusercontent.com/sapporo-wes/wes-interop-demo/main/workflow/snp-freq.smk"
  ]
}
```

Pass it to Sapporo:

```yaml
# in compose.yml environment:
- SAPPORO_EXECUTABLE_WORKFLOWS=/app/executable_workflows.json
```

```yaml
# in compose.yml volumes:
- ./executable_workflows.json:/app/executable_workflows.json:ro
```

## 5. HTTPS (optional, recommended for production)

Use nginx + Let's Encrypt to terminate TLS in front of Sapporo:

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
sudo certbot --nginx -d wes-jp.example.org
```

Nginx config (`/etc/nginx/sites-available/sapporo`):

```nginx
server {
    listen 443 ssl;
    server_name wes-jp.example.org;

    location / {
        proxy_pass http://127.0.0.1:1122;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 300;
    }
}
```

## 6. Verify end-to-end

From your local machine:

```bash
export SAPPORO_ENDPOINT=https://wes-jp.example.org
curl -s $SAPPORO_ENDPOINT/service-info | jq .workflow_engine_versions
curl -s $SAPPORO_ENDPOINT/executable-workflows | jq .
```
