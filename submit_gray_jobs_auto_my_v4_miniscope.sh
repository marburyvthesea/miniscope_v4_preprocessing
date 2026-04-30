#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  submit_gray_jobs_auto_my_v4_miniscope.sh BASE_DIR [SBATCH_SCRIPT]
  submit_gray_jobs_auto_my_v4_miniscope.sh --dry-run BASE_DIR [SBATCH_SCRIPT]

Description:
  Scan BASE_DIR for nested My_V4_Miniscope folders in the layout:

    BASE_DIR/<date>/<session>/My_V4_Miniscope/

  For each My_V4_Miniscope directory, find numeric AVI files like 0.avi..N.avi
  and submit:

    sbatch SBATCH_SCRIPT <my_v4_miniscope_dir> <first_avi_number> <last_avi_number>

Defaults:
  SBATCH_SCRIPT=slurm_v4preprocessing_convert_to_gray.sh

Examples:
  submit_gray_jobs_auto_my_v4_miniscope.sh /scratch/jma819/CaliAli_linearTrackData/989
  submit_gray_jobs_auto_my_v4_miniscope.sh --dry-run /scratch/jma819/CaliAli_linearTrackData/989
EOF
}

dry_run=0
if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=1
  shift
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 1
fi

base_dir="$1"
sbatch_script="${2:-slurm_v4preprocessing_convert_to_gray.sh}"

if [[ ! -d "$base_dir" ]]; then
  echo "ERROR: BASE_DIR is not a directory: $base_dir" >&2
  exit 1
fi

if [[ "$sbatch_script" != */* ]] && ! command -v "$sbatch_script" >/dev/null 2>&1 && [[ ! -f "$sbatch_script" ]]; then
  echo "ERROR: Cannot find sbatch script in PATH or current directory: $sbatch_script" >&2
  exit 1
fi

shopt -s nullglob

found_any=0
for miniscope_dir in "$base_dir"/*/*/My_V4_Miniscope/; do
  [[ -d "$miniscope_dir" ]] || continue
  found_any=1

  avi_nums=()
  for avi_path in "$miniscope_dir"*.avi; do
    avi_file="${avi_path##*/}"
    avi_num="${avi_file%.avi}"
    if [[ "$avi_num" =~ ^[0-9]+$ ]]; then
      avi_nums+=("$avi_num")
    fi
  done

  if [[ ${#avi_nums[@]} -eq 0 ]]; then
    echo "Skipping ${miniscope_dir%/}: no numeric .avi files found"
    continue
  fi

  IFS=$'\n' sorted_nums=($(printf '%s\n' "${avi_nums[@]}" | sort -n))
  unset IFS

  first_num="${sorted_nums[0]}"
  last_num="${sorted_nums[-1]}"

  printf 'My_V4_Miniscope dir: %s\n' "${miniscope_dir%/}"
  printf '  AVI range: %s to %s\n' "$first_num" "$last_num"
  printf '  Command: sbatch %s %q %s %s\n' "$sbatch_script" "${miniscope_dir%/}" "$first_num" "$last_num"

  if [[ "$dry_run" -eq 0 ]]; then
    sbatch "$sbatch_script" "${miniscope_dir%/}" "$first_num" "$last_num"
  fi
done

if [[ "$found_any" -eq 0 ]]; then
  echo "ERROR: No My_V4_Miniscope directories found under $base_dir" >&2
  exit 1
fi
