#!/bin/bash
#SBATCH -A p30771
#SBATCH -p short 
#SBATCH -t 00:15:00
#SBATCH -o ./logfiles/slurm.%x-%j.out # STDOUT
#SBATCH --job-name="slurm_matlab_avi_to_tiff"
#SBATCH --mem=90G
#SBATCH -N 1
#SBATCH -n 9 


module purge all

cd ~

# Inputs from command line
DIR_path=$1

INPUT_moviestart=$2
INPUT_movieend=$3
INPUT_regExp=$4
INPUT_parallel_enable=true

#add project directory to PATH
export PATH=$PATH/projects/p30771/

#load modules to use

module load matlab/r2018a

#cd to script directory
cd /projects/p30771/MATLAB/CNMF_E_jjm/quest_MATLAB_cnmfe
#run  

matlab -nosplash -nodesktop -r "dirpath='$DIR_path';movie_start='$INPUT_moviestart';movie_end='$INPUT_movieend';regExp='$INPUT_regExp';parallel='$INPUT_parallel_enable';disp(dirpath);run('/projects/p30771/MATLAB/CNMF_E_jjm/quest_MATLAB_cnmfe/multiTiffsToGrayDirectory.m');exit;"


