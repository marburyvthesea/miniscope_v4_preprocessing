

import sys 
sys.path.append('/home/jma819/miniscope/miniscope_v4_preprocessing')
import v4SpatialFiltering



dataDir = sys.argv[1]
dataFilePrefix = sys.argv[2]
startingFileNum = sys.argv[3]
framesPerFile = 1000


#1 generate mean FFT
print('generating mean FFT')
meanFFT, rows, cols = v4SpatialFiltering.generateMeanFFT(startingFileNum, dataDir, dataFilePrefix, framesPerFile)

#2 generate notch filter mask for FFT
print('generating FFT mask')
modifiedFFT, maskFFT = v4SpatialFiltering.generateFFTMask(meanFFT, 2000, 3, 20, rows, cols)

#3 get mean fluorescence per frame
print('generating mean fluorescence per frame')
meanFrame = v4SpatialFiltering.calculateMeanFluorescencePerFrame(dataDir, dataFilePrefix, startingFileNum, maskFFT, framesPerFile)

#4 lowpass filter mean fluorescence
print('lowpass filtering')
fs = 20 # TODO: Should get this from timestamp file
cutoff = 3.0
butterOrder = 6
meanFiltered = v4SpatialFiltering.lowpassFilterMeanFluorescence(meanFrame, butterOrder, cutoff, fs)

##5 apply FFT and lowpass filter to each frame
print('applying FFT and lowpass filter to frames')
    # apply mask from #2 to dft of each frame
    # subtrace meanF from each frame from meanFiltered from #4
dirOutput = v4SpatialFiltering.applyFFTLowpassFiltering(dataDir, dataFilePrefix, startingFileNum, cutoff, "GREY", meanFiltered, maskFFT, rows, cols, 1000)

print('saved denoised images to:')
print(dirOutput)

#TO DO: save some examples of FFT/filtered FFT, lowpass filtering examples from datasets 