#!/bin/bash
#SBATCH -A p30771
#SBATCH -p normal
#SBATCH -t 12:00:00
#SBATCH -o /home/jma819/miniscope_denoising/miniscope_v4_preprocessing/logfiles/slurm.%x-%j.out # STDOUT
#SBATCH --job-name="slurm_v4_preprocessing"
#SBATCH -N 1
#SBATCH -n 4
#SBATCH --mem=25G

set -euo pipefail

module purge all
cd ~
#add project directory to PATH
export PATH=$PATH/projects/p32501
export PATH=$PATH/projects/p30771

#load modules to use
module load python/anaconda3

#need to cd to load conda environment
set +u
eval "$(conda shell.bash hook)"
conda activate v4_preprocessing
set -u 

#need to cd to module directory

cd /home/jma819/miniscope_denoising/miniscope_v4_preprocessing

#get inputs from command line and run 

INPUT_dataDir=$1
#INPUT_dataFilePrefix=$2
INPUT_startingFileNum=$2
#framesPerFile=1000
INPUT_movieend=$3
INPUT_regExp='denoised'
INPUT_parallel_enable=true
SCRIPT_DIR="/home/jma819/miniscope_denoising/miniscope_v4_preprocessing"
GRAY_INPUT_DIR="${INPUT_dataDir%/}/Denoised"

echo "starting preprocessing"

python v4PreProcessingScript.py $INPUT_dataDir $INPUT_startingFileNum

echo "finished preprocessing"
echo "converting to gray"

module purge all 
module load matlab/r2018a
cd "$SCRIPT_DIR"

matlab -nosplash -nodesktop -r "dirpath='$GRAY_INPUT_DIR';movie_start='$INPUT_startingFileNum';movie_end='$INPUT_movieend';regExp='$INPUT_regExp';parallel='$INPUT_parallel_enable';disp(dirpath);run('$SCRIPT_DIR/multiTiffsToGrayDirectory.m');exit;"

cd "$GRAY_INPUT_DIR"

mkdir -p gray
shopt -s nullglob
converted_files=( *converted.tif )
if [[ ${#converted_files[@]} -eq 0 ]]; then
  echo "ERROR: No converted TIFFs were created in $GRAY_INPUT_DIR" >&2
  exit 1
fi

mv -- "${converted_files[@]}" gray/

cd gray

for n in {0..9}; do
  src="denoised${n}_converted.tif"
  dst="denoised0${n}_converted.tif"
  if [[ -f "$src" ]]; then
    mv "$src" "$dst"
  fi
done
