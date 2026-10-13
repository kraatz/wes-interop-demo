#!/usr/bin/env bash
# submit_weskit_only.sh — Cross-check: run BOTH populations on WESkit and compare
# against the mixed Sapporo (JPT) + WESkit (CEU) reference results.
# Usage: bash scripts/submit_weskit_only.sh
#
# Workflow: workflow/snp-freq.smk (Snakemake)
# Params:   params/jpt_params_weskit.json  (WESkit)
#           params/ceu_params_smk.json     (WESkit)
# Reference: example-results/ (or $REFERENCE_DIR)
# Output:    run-logs/<date>_weskit-only/ (or $RESULTS_DIR), laid out as
#            {JPT,CEU}/{summary.tsv,run_log.json} and combined/
set -euo pipefail

WESKIT_ENDPOINT="${WESKIT_ENDPOINT:-https://192.168.49.2:30132}"
WESKIT_CACERT="${WESKIT_CACERT:-$HOME/interoperability/helm-deployment/certs/weskit.crt}"
RESULTS_DIR="${RESULTS_DIR:-run-logs/$(date -u +%F)_weskit-only}"
REFERENCE_DIR="${REFERENCE_DIR:-example-results}"
JPT_PARAMS="params/jpt_params_weskit.json"
CEU_PARAMS="params/ceu_params_smk.json"
SMK_WORKFLOW="workflow/snp-freq.smk"
SMK_CONDA_ENV="workflow/envs/bcftools.yaml"

WES="$WESKIT_ENDPOINT/ga4gh/wes/v1"
CURL=(curl --cacert "$WESKIT_CACERT")

mkdir -p "$RESULTS_DIR/JPT" "$RESULTS_DIR/CEU" "$RESULTS_DIR/combined"

submit() {
    local params="$1"
    "${CURL[@]}" -fsSL -X POST "$WES/runs" \
        -H "Accept: application/json" \
        -F workflow_type="$(jq -r .workflow_type "$params")" \
        -F workflow_type_version="$(jq -r .workflow_type_version "$params")" \
        -F workflow_url="$(jq -r .workflow_url "$params")" \
        -F workflow_engine="$(jq -r .workflow_engine "$params")" \
        -F workflow_engine_parameters="$(jq -c .workflow_engine_parameters "$params")" \
        -F workflow_params="$(jq -c .workflow_params "$params")" \
        -F tags="$(jq -c .tags "$params")" \
        -F "workflow_attachment=@${SMK_WORKFLOW};filename=snp-freq.smk" \
        -F "workflow_attachment=@${SMK_CONDA_ENV};filename=bcftools.yaml" | jq -r .run_id
}

poll_until_done() {
    local run_id="$1"
    local label="$2"
    while true; do
        STATE=$("${CURL[@]}" -s "$WES/runs/$run_id/status" | jq -r .state)
        echo "[$label] $STATE"
        case "$STATE" in
            COMPLETE) return 0 ;;
            EXECUTOR_ERROR|SYSTEM_ERROR|CANCELED)
                echo "[$label] Run failed: $STATE" >&2
                "${CURL[@]}" -s "$WES/runs/$run_id" | jq '{exit_code: .run_log.exit_code, stderr: .run_log.stderr}' >&2
                return 1 ;;
        esac
        sleep 15
    done
}

# Runs are sequential: concurrent runs on one worker race on the shared conda
# package cache (/opt/conda/pkgs) while creating the bcftools env.
echo "==> Submitting JPT to WESkit..."
RUN_JPT=$(submit "$JPT_PARAMS")
echo "    run_id: $RUN_JPT"
poll_until_done "$RUN_JPT" "JPT"

echo "==> Submitting CEU to WESkit..."
RUN_CEU=$(submit "$CEU_PARAMS")
echo "    run_id: $RUN_CEU"
poll_until_done "$RUN_CEU" "CEU"

echo "==> Downloading outputs and run logs..."
for pair in "JPT:$RUN_JPT" "CEU:$RUN_CEU"; do
    pop="${pair%%:*}"; rid="${pair#*:}"
    "${CURL[@]}" -fsSL -o "$RESULTS_DIR/$pop/summary.tsv" \
        "$WESKIT_ENDPOINT/weskit/v1/runs/$rid/outputs/summary.tsv"
    "${CURL[@]}" -fsSL -o "$RESULTS_DIR/$pop/run_log.json" "$WES/runs/$rid"
done

echo "==> Aggregating..."
# Use uv for aggregate.py's dependencies when available; else plain python3.
if command -v uv >/dev/null; then
    PY=(uv run --no-project --with scipy --with matplotlib --with numpy python3)
else
    PY=(python3)
fi
"${PY[@]}" scripts/aggregate.py \
    "$RESULTS_DIR/JPT/summary.tsv" \
    "$RESULTS_DIR/CEU/summary.tsv" \
    --output "$RESULTS_DIR/combined/combined_results.tsv" \
    --plot "$RESULTS_DIR/combined/allele_freq_comparison.png"

echo ""
echo "==> Comparing against $REFERENCE_DIR/ ..."
FAIL=0
# reference file : result file
for pair in "summary_jpt.tsv:JPT/summary.tsv" \
            "summary_ceu.tsv:CEU/summary.tsv" \
            "combined_results.tsv:combined/combined_results.tsv"; do
    ref="$REFERENCE_DIR/${pair%%:*}"; res="$RESULTS_DIR/${pair#*:}"
    if diff -u "$ref" "$res" > "$res.diff"; then
        echo "  IDENTICAL  $res"
        rm -f "$res.diff"
    else
        echo "  DIFFERS    $res  (see $res.diff)"
        FAIL=1
    fi
done

echo ""
if [[ $FAIL -eq 0 ]]; then
    echo "PASS: WESkit-only results match the Sapporo+WESkit reference."
else
    echo "FAIL: results differ from reference." >&2
    exit 1
fi
