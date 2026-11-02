#!/usr/bin/env bash
##
## Launch the DOM-79203 CDISC1-shaped Flows Artifact Export scale workflow,
## exporting to a NetApp Volume instead of a Domino Dataset. Life Sciences
## customers export to NetApp, not just Datasets, so this is the second
## target this harness needs to prove out (Datasets first).
##
## Usage:
##   bash generate_and_run_scale_export_netapp.sh <dataset_url> <netapp_volume_id> <project_name> <profile> [--skip-export] [--sas-environment <name>]
##
## <dataset_url> still seeds the sdtm_dataset_snapshot input (the default
## project dataset) -- only the export target changes to the NetApp Volume.
## <netapp_volume_id> is the volume's remotefs id (not a URL), so the Cucu
## caller must resolve it, e.g. via the "I save the volume ID for volume ...
## to the variable ..." step.
## profile is `reduced` or `full`.
## --sas-environment names the Domino environment for the SAS tasks
## (default "SAS Environment").
##
set -euo pipefail

USAGE="Usage: bash generate_and_run_scale_export_netapp.sh <dataset_url> <netapp_volume_id> <project_name> <profile> [--skip-export] [--sas-environment <name>]"
if [[ $# -lt 4 ]]; then
  echo "$USAGE" >&2
  exit 1
fi

DATASET_URL="$1"
NETAPP_VOLUME_ID="$2"
PROJECT_NAME="$3"
PROFILE="$4"
shift 4
SKIP_EXPORT=""
SAS_ENVIRONMENT="SAS Environment"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-export) SKIP_EXPORT="--skip-export"; shift ;;
    --sas-environment) SAS_ENVIRONMENT="$2"; shift 2 ;;
    *) echo "$USAGE" >&2; exit 1 ;;
  esac
done

# Git-based projects mount the project dataset at /mnt/data; DFS projects at /domino/datasets/local.
if [[ -d "/mnt/data/${PROJECT_NAME}" ]]; then
  DATASET_DIR="/mnt/data/${PROJECT_NAME}"
else
  DATASET_DIR="/domino/datasets/local/${PROJECT_NAME}"
fi
ROOT="${DOMINO_WORKING_DIR:-/mnt/code}"

cd "$ROOT"

python "$ROOT/scripts/seed_sdtm_placeholders.py" "$DATASET_DIR"

GEN_ARGS=(--profile "$PROFILE" --netapp-volume-id "$NETAPP_VOLUME_ID" --sas-environment "$SAS_ENVIRONMENT" --out "$ROOT/generate_artifacts_scale_run.py")
if [[ "$SKIP_EXPORT" == "--skip-export" ]]; then
  GEN_ARGS+=(--skip-export)
fi
python "$ROOT/flows/gen_scale_export_workflow.py" "${GEN_ARGS[@]}"

pyflyte run --remote "$ROOT/generate_artifacts_scale_run.py" export_scale_study \
  --sdtm_dataset_snapshot "$DATASET_DIR"
