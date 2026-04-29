et -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  submit_gray_from_denoised_tifs_auto.sh BASE_DIR [SBATCH_SCRIPT]
  submit_gray_from_denoised_tifs_auto.sh --dry-run BASE_DIR [SBATCH_SCRIPT]

Description:
  For each immediate session subdirectory of BASE_DIR, inspect its Denoised/
  folder for files named like denoised0.tif, denoised1.tif, ..., denoisedN.tif.
  Then submit:

    sbatch SBATCH_SCRIPT <session_dir>/Denoised <first_tif_number> <last_tif_number>

Defaults:
  SBATCH_SCRIPT=slurm_v4preprocessing_convert_to_gray.sh

Examples:
  submit_gray_from_denoised_tifs_auto.sh /scratch/jma819/CaliAli_linearTrackData/414
  submit_gray_from_denoised_tifs_auto.sh --dry-run /scratch/jma819/CaliAli_linearTrackData/414
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
sbatch_script="${2:-slurm_v4_convert_to_gray.sh}"

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

  denoised_dir="${session_dir}Denoised"
  if [[ ! -d "$denoised_dir" ]]; then
    echo "Skipping $(basename "$session_dir"): no Denoised/ subdirectory"
    continue
  fi

  tif_nums=()
  for tif_path in "$denoised_dir"/denoised*.tif; do
    tif_file="${tif_path##*/}"
    tif_num="${tif_file#denoised}"
    tif_num="${tif_num%.tif}"
    if [[ "$tif_num" =~ ^[0-9]+$ ]]; then
      tif_nums+=("$tif_num")
    fi
  done

  if [[ ${#tif_nums[@]} -eq 0 ]]; then
    echo "Skipping $(basename "$session_dir"): no numeric denoised*.tif files found in Denoised/"
    continue
  fi

  IFS=$'\n' sorted_nums=($(printf '%s\n' "${tif_nums[@]}" | sort -n))
  unset IFS

  first_num="${sorted_nums[0]}"
  last_num="${sorted_nums[-1]}"

  printf 'Session: %s\n' "$session_dir"
  printf '  Denoised dir: %s\n' "$denoised_dir"
  printf '  TIFF range: %s to %s\n' "$first_num" "$last_num"
  printf '  Command: sbatch %s %q %s %s\n' "$sbatch_script" "$denoised_dir" "$first_num" "$last_num"

  if [[ "$dry_run" -eq 0 ]]; then
    sbatch "$sbatch_script" "$denoised_dir" "$first_num" "$last_num"
  fi
done

if [[ "$found_any" -eq 0 ]]; then
  echo "ERROR: No immediate subdirectories found in $base_dir" >&2
  exit 1
fi


