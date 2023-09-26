#!/bin/bash
#SBATCH -A p30771
#SBATCH -p normal
#SBATCH -t 12:00:00
#SBATCH -o /home/jma819/miniscope_denoising/miniscope_v4_preprocessing/logfiles/slurm.%x-%j.out # STDOUT
#SBATCH --job-name="slurm_v4_preprocessing"
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=20G

module purge all
cd ~
#add project directory to PATH
export PATH=$PATH/projects/p30771/


#get inputs from command line and run 

INPUT_dataDir=$1
#INPUT_dataFilePrefix=$2
INPUT_startingFileNum=$2
#framesPerFile=1000
INPUT_movieend=$3
INPUT_regExp='denoised'
INPUT_parallel_enable=true




echo "converting to gray"

module purge all 
module load matlab/r2018a
#cd to script directory
cd /projects/p30771/MATLAB/CNMF_E_jjm/quest_MATLAB_cnmfe






matlab -nosplash -nodesktop -r "dirpath='$INPUT_dataDir';movie_start='$INPUT_startingFileNum';movie_end='$INPUT_movieend';regExp='$INPUT_regExp';parallel='$INPUT_parallel_enable';disp(dirpath);run('/projects/p30771/MATLAB/CNMF_E_jjm/quest_MATLAB_cnmfe/multiTiffsToGrayDirectory.m');exit;"

cd $INPUT_dataDir


mkdir gray
mv *converted.tif gray

cd gray

mv denoised0_converted.tif denoised00_converted.tif
mv denoised1_converted.tif denoised01_converted.tif
mv denoised2_converted.tif denoised02_converted.tif
mv denoised3_converted.tif denoised03_converted.tif
mv denoised4_converted.tif denoised04_converted.tif
mv denoised5_converted.tif denoised05_converted.tif
mv denoised6_converted.tif denoised06_converted.tif
mv denoised7_converted.tif denoised07_converted.tif
mv denoised8_converted.tif denoised08_converted.tif
mv denoised9_converted.tif denoised09_converted.tif

