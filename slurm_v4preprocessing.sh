#!/bin/bash
#SBATCH -A p30771
#SBATCH -p short
#SBATCH -t 04:00:00
#SBATCH -o /home/jma819/miniscope/miniscope_v4_preprocessing/logfiles/slurm.%x-%j.out # STDOUT
#SBATCH --job-name="slurm_v4_preprocessing"
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=20G

module purge all
cd ~
#add project directory to PATH
export PATH=$PATH/projects/p30771/

#load modules to use
module load python/anaconda3.6 

#need to cd to load conda environment

source activate v4_preprocessing

#need to cd to module directory

cd /home/jma819/miniscope/miniscope_v4_preprocessing

#get inputs from command line and run 

INPUT_dataDir=$1
#INPUT_dataFilePrefix=$2
INPUT_startingFileNum=$2
#framesPerFile=1000


python v4PreProcessingScript.py $INPUT_dataDir $INPUT_startingFileNum

echo "finished preprocessing"
