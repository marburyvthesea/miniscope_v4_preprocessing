#!/bin/bash
#SBATCH -A p30771
#SBATCH -p short
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --job-name=avi_to_tiff
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sbatch ffmpeg_avi_to_tiff_frames.sbatch INPUT_DIR [OUTPUT_DIR] [WORKERS]

Description:
  Convert every numeric .avi file in INPUT_DIR into one grayscale multi-page
  TIFF using ffmpeg. Output is written as:

    OUTPUT_DIR/<avi_stem>.tif

Arguments:
  INPUT_DIR   Directory containing .avi files
  OUTPUT_DIR  Optional output root (default: INPUT_DIR/tiff_frames)
  WORKERS     Optional parallel worker count (default: SLURM_CPUS_PER_TASK or 4)

Example:
  sbatch ffmpeg_avi_to_tiff_frames.sbatch \
    /projects/p30771/TmazeRecordings/2025_08_14_recording_day/16_44_25_328_part1/My_V4_Miniscope
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 || $# -gt 3 ]]; then
  usage >&2
  exit 1
fi

INPUT_DIR="$1"
OUTPUT_DIR="${2:-${INPUT_DIR%/}/tiff_frames}"
WORKERS="${3:-${SLURM_CPUS_PER_TASK:-4}}"

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "ERROR: INPUT_DIR does not exist: $INPUT_DIR" >&2
  exit 1
fi

if ! [[ "$WORKERS" =~ ^[0-9]+$ ]] || [[ "$WORKERS" -lt 1 ]]; then
  echo "ERROR: WORKERS must be a positive integer. Got: $WORKERS" >&2
  exit 1
fi

module purge
module load ffmpeg/6.1

mkdir -p "$OUTPUT_DIR"

shopt -s nullglob
avi_files=( "$INPUT_DIR"/*.avi )

if [[ ${#avi_files[@]} -eq 0 ]]; then
  echo "ERROR: No .avi files found in $INPUT_DIR" >&2
  exit 1
fi

IFS=$'\n' avi_files=( $(printf '%s\n' "${avi_files[@]}" | sort -V) )
unset IFS

echo "INPUT_DIR=$INPUT_DIR"
echo "OUTPUT_DIR=$OUTPUT_DIR"
echo "WORKERS=$WORKERS"
echo "AVI_COUNT=${#avi_files[@]}"

convert_one() {
  local avi_path="$1"
  local avi_name avi_stem out_path

  avi_name="${avi_path##*/}"
  avi_stem="${avi_name%.avi}"
  out_path="${OUTPUT_DIR}/${avi_stem}.tif"
  echo "Converting $avi_name -> $out_path"

  ffmpeg -v error -y \
    -i "$avi_path" \
    -pix_fmt gray \
    "$out_path"
}

running=0
for avi_path in "${avi_files[@]}"; do
  convert_one "$avi_path" &
  running=$((running + 1))

  if [[ "$running" -ge "$WORKERS" ]]; then
    wait -n
    running=$((running - 1))
  fi
done

wait

echo "Done."
