#!/bin/bash
#SBATCH -A p30771
#SBATCH -p normal
#SBATCH -t 12:00:00
#SBATCH -o ./logfiles/slurm.%x-%j.out # STDOUT
#SBATCH --job-name="aviToTIFF"
#SBATCH --mem-per-cpu=5200M
#SBATCH -N 1
#SBATCH -n 16

module purge all

#path to file (h5 or tiff should work)

INPUT_path_to_denoisedAVIs=$1
echo $INPUT_path_to_denoisedAVIs


# add projects to path 
#export PATH=$PATH/projects/p30771/

#load modules to use
module load ffmpeg
module load matlab/r2023b 

#load modules to use



matlab -nosplash -nodesktop -r "folderPath='$INPUT_path_to_denoisedAVIs';run('convertFFV1Avis.m');exit;"



