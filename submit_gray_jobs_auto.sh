#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  submit_gray_jobs_auto.sh BASE_DIR [SBATCH_SCRIPT]
  submit_gray_jobs_auto.sh --dry-run BASE_DIR [SBATCH_SCRIPT]

Description:
  For each immediate subdirectory of BASE_DIR, find numeric AVI files like
  0.avi, 1.avi, ..., N.avi, then submit:

    sbatch SBATCH_SCRIPT <session_dir> <first_avi_number> <last_avi_number>

Defaults:
  SBATCH_SCRIPT=slurm_v4preprocessing_convert_to_gray.sh

Examples:
  submit_gray_jobs_auto.sh /scratch/jma819/CaliAli_linearTrackData/414
  submit_gray_jobs_auto.sh --dry-run /scratch/jma819/CaliAli_linearTrackData/414
  submit_gray_jobs_auto.sh /scratch/jma819/CaliAli_linearTrackData/414 /path/to/slurm_v4preprocessing_convert_to_gray.sh
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
for session_dir in "$base_dir"/*/; do
  [[ -d "$session_dir" ]] || continue
  found_any=1

  avi_files=()
  avi_nums=()

  for avi_path in "$session_dir"*.avi; do
    avi_file="${avi_path##*/}"
    avi_num="${avi_file%.avi}"
    if [[ "$avi_num" =~ ^[0-9]+$ ]]; then
      avi_files+=("$avi_path")
      avi_nums+=("$avi_num")
    fi
  done

  if [[ ${#avi_nums[@]} -eq 0 ]]; then
    echo "Skipping $(basename "$session_dir"): no numeric .avi files found"
    continue
  fi

  IFS=$'\n' sorted_nums=($(printf '%s\n' "${avi_nums[@]}" | sort -n))
  unset IFS

  first_num="${sorted_nums[0]}"
  last_num="${sorted_nums[-1]}"

  printf 'Session: %s\n' "$session_dir"
  printf '  AVI range: %s to %s\n' "$first_num" "$last_num"
  printf '  Command: sbatch %s %q %s %s\n' "$sbatch_script" "$session_dir" "$first_num" "$last_num"

  if [[ "$dry_run" -eq 0 ]]; then
    sbatch "$sbatch_script" "$session_dir" "$first_num" "$last_num"
  fi
done

if [[ "$found_any" -eq 0 ]]; then
  echo "ERROR: No immediate subdirectories found in $base_dir" >&2
  exit 1
fi
