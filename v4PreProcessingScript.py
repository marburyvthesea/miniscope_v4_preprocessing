

import sys 
sys.path.append('/home/jma819/miniscope/miniscope_v4_preprocessing')
import v4SpatialFiltering
from matplotlib import pyplot as plt
import numpy as np
import imageio
import os
from tqdm import tqdm

dataDir = sys.argv[1]
dataFilePrefix = ''
startingFileNum = int(sys.argv[2])
framesPerFile = 1000


#1 generate mean FFT
print('generating mean FFT')
meanFFT, rows, cols = v4SpatialFiltering.generateMeanFFT(startingFileNum, dataDir, dataFilePrefix, framesPerFile)

#2 generate notch filter mask for FFT
print('generating FFT mask')
modifiedFFT, maskFFT = v4SpatialFiltering.generateFFTMask(meanFFT, 2000, 3, 20, rows, cols)

# save image of fft transform eg
plt.figure()
plt.subplot(121),plt.imshow(np.log(meanFFT), cmap = 'gray')
plt.title('Mean FFT of Data')
plt.subplot(122),plt.imshow(np.log(modifiedFFT), cmap = 'gray')
plt.title('Filtered FFT')
plt.savefig(dataDir+"/denoised_"+str(startingFileNum)+"_fft_filter.svg")

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

# convert to tif and save images 

print('converting to tiffs')
avi_files_to_convert = [dirOutput+'/'+fname for fname in os.listdir(dirOutput) if 'avi' in fname]
for path_to_video in tqdm(avi_files_to_convert):
	savepath = path_to_video.strip('.avi')+'.tif'
	#savepath = '/'.join(path_to_video.split('/')[0:-1])+'/denoised_'+path_to_video.split('/')[-1].strip('.avi')+'.tif'
	try:
		video_loaded=imageio.get_reader(path_to_video)
		imageio.mimwrite(savepath, video_loaded)

	except OSError:
		print('error in:'+path_to_video)
		pass

print('converted to tiffs')










