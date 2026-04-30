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
  TIFF. ffmpeg decodes frames and Python+tifffile writes the TIFF stack.
  Output is written as:

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
module load python/anaconda3
set +u
source activate v4_preprocessing
set -u

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

PY_HELPER="$(mktemp /tmp/avi_to_tiff_XXXXXX.py)"
cleanup() {
  rm -f "$PY_HELPER"
}
trap cleanup EXIT

cat > "$PY_HELPER" <<'PYEOF'
import json
import os
import subprocess
import sys

import numpy as np
import tifffile


def probe_video(path):
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=width,height",
        "-of",
        "json",
        path,
    ]
    result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    info = json.loads(result.stdout)
    streams = info.get("streams", [])
    if not streams:
        raise RuntimeError("No video stream found in {}".format(path))
    width = int(streams[0]["width"])
    height = int(streams[0]["height"])
    return width, height


def convert_one(in_path, out_path):
    width, height = probe_video(in_path)
    frame_bytes = width * height
    ffmpeg_cmd = [
        "ffmpeg",
        "-v",
        "error",
        "-i",
        in_path,
        "-f",
        "rawvideo",
        "-pix_fmt",
        "gray",
        "-",
    ]

    proc = subprocess.Popen(ffmpeg_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    frame_count = 0

    try:
        with tifffile.TiffWriter(out_path, bigtiff=True) as tif:
            while True:
                chunk = proc.stdout.read(frame_bytes)
                if not chunk:
                    break
                if len(chunk) != frame_bytes:
                    raise RuntimeError(
                        "Incomplete frame while reading {}: expected {} bytes, got {}".format(
                            in_path, frame_bytes, len(chunk)
                        )
                    )
                frame = np.frombuffer(chunk, dtype=np.uint8).reshape((height, width))
                tif.write(frame, photometric="minisblack")
                frame_count += 1
    except Exception:
        proc.kill()
        proc.wait()
        if os.path.exists(out_path):
            os.remove(out_path)
        raise

    stderr_text = proc.stderr.read().decode("utf-8", errors="replace")
    return_code = proc.wait()
    if return_code != 0:
        if os.path.exists(out_path):
            os.remove(out_path)
        raise RuntimeError("ffmpeg failed for {}:\n{}".format(in_path, stderr_text))
    if frame_count == 0:
        if os.path.exists(out_path):
            os.remove(out_path)
        raise RuntimeError("No frames were decoded from {}".format(in_path))

    print("Wrote {} frame(s) to {}".format(frame_count, out_path))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: python avi_to_tiff.py INPUT_AVI OUTPUT_TIF")
    convert_one(sys.argv[1], sys.argv[2])
PYEOF

convert_one() {
  local avi_path="$1"
  local avi_name avi_stem out_path

  avi_name="${avi_path##*/}"
  avi_stem="${avi_name%.avi}"
  out_path="${OUTPUT_DIR}/${avi_stem}.tif"
  echo "Converting $avi_name -> $out_path"

  python3 "$PY_HELPER" "$avi_path" "$out_path"
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
