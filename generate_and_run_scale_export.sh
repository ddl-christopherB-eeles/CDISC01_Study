#!/usr/bin/env bash
##
## Launch the DOM-79203 CDISC1-shaped Flows Artifact Export scale workflow.
##
## Usage:
##   bash generate_and_run_scale_export.sh <dataset_url> <project_name> <profile> [--skip-export] [--sas-environment <name>]
##
## profile is `reduced` or `full`.
## --skip-export generates the clinical + extra-file DAG without a programmatic
## export so a Cucu scenario can drive per-stage UI exports instead.
## --sas-environment names the Domino environment for the SAS tasks
## (default "SAS Environment").
##
set -euo pipefail

USAGE="Usage: bash generate_and_run_scale_export.sh <dataset_url> <project_name> <profile> [--skip-export] [--sas-environment <name>]"
if [[ $# -lt 3 ]]; then
  echo "$USAGE" >&2
  exit 1
fi

DATASET_URL="$1"
PROJECT_NAME="$2"
PROFILE="$3"
shift 3
SKIP_EXPORT=""
SAS_ENVIRONMENT="SAS Environment"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-export) SKIP_EXPORT="--skip-export"; shift ;;
    --sas-environment) SAS_ENVIRONMENT="$2"; shift 2 ;;
    *) echo "$USAGE" >&2; exit 1 ;;
  esac
done

DATASET_ID="$(basename "$DATASET_URL")"
# Git-based projects mount the project dataset at /mnt/data; DFS projects at /domino/datasets/local.
if [[ -d "/mnt/data/${PROJECT_NAME}" ]]; then
  DATASET_DIR="/mnt/data/${PROJECT_NAME}"
else
  DATASET_DIR="/domino/datasets/local/${PROJECT_NAME}"
fi
ROOT="${DOMINO_WORKING_DIR:-/mnt/code}"

cd "$ROOT"

python "$ROOT/scripts/seed_sdtm_placeholders.py" "$DATASET_DIR"
python "$ROOT/scripts/snapshot_sdtm_dataset.py" "$DATASET_ID"

GEN_ARGS=(--profile "$PROFILE" --dataset-id "$DATASET_ID" --sas-environment "$SAS_ENVIRONMENT" --out "$ROOT/generate_artifacts_scale_run.py")
if [[ "$SKIP_EXPORT" == "--skip-export" ]]; then
  GEN_ARGS+=(--skip-export)
fi
python "$ROOT/flows/gen_scale_export_workflow.py" "${GEN_ARGS[@]}"

pyflyte run --remote "$ROOT/generate_artifacts_scale_run.py" export_scale_study \
  --sdtm_dataset_snapshot "$DATASET_DIR"
