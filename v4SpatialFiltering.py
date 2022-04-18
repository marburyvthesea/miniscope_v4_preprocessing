

import os.path
from os import path
import cv2
import numpy as np
import matplotlib
from matplotlib import pyplot as plt
from matplotlib import animation, rc
from IPython.display import clear_output
import glob

from tqdm import tqdm 
from scipy.signal import butter, lfilter, freqz, filtfilt




# apply FFT and lowpass filtering 

def generateMeanFFT(fileNum, dataDir, dataFilePrefix, framesPerFile):
    # Makes sure path ends with '/'
    if (dataDir[-1] is not "/"):
        dataDir = dataDir + "/"


    frameStep = 10 # Can use frame skipping to speed this up
    showVideo = False
    sumFFT = None
    applyVignette = True
    vignetteCreated = False
    running = True

    while (path.exists(dataDir + dataFilePrefix + "{:.0f}.avi".format(fileNum)) and running is True):
        cap = cv2.VideoCapture(dataDir + dataFilePrefix + "{:.0f}.avi".format(fileNum))
        fileNum = fileNum + 1
        frameNum = 0
        for frameNum in tqdm(range(0,framesPerFile, frameStep), total = framesPerFile/frameStep, desc ="Running file {:.0f}.avi".format(fileNum - 1)):
            cap.set(cv2.CAP_PROP_POS_FRAMES, frameNum)
            ret, frame = cap.read()

            if (vignetteCreated is False):
                rows, cols = frame.shape[:2] 
                X_resultant_kernel = cv2.getGaussianKernel(cols,cols/4) 
                Y_resultant_kernel = cv2.getGaussianKernel(rows,rows/4) 
                resultant_kernel = Y_resultant_kernel * X_resultant_kernel.T 
                mask = 255 * resultant_kernel / np.linalg.norm(resultant_kernel)
                vignetteCreated = True

            if applyVignette is False:
                mask = mask * 0 + 1
        
            if (ret is False):
                break
            else:
                frame = frame[:,:,1] * mask
            
                dft = cv2.dft(np.float32(frame),flags = cv2.DFT_COMPLEX_OUTPUT)
                dft_shift = np.fft.fftshift(dft)
            
                # sum FFT variable iteratively modfied here 
            
                try:
                    sumFFT = sumFFT + cv2.magnitude(dft_shift[:,:,0],dft_shift[:,:,1])
                except:
                    sumFFT = cv2.magnitude(dft_shift[:,:,0],dft_shift[:,:,1])

    return(sumFFT, rows, cols)




def generateFFTMask(sumFFT, goodRadius, notchHalfWidth, centerHalfHeightToLeave, rows, cols):

    crow,ccol = int(rows/2) , int(cols/2)
    maskFFT = np.zeros((rows,cols,2), np.float32)
    cv2.circle(maskFFT,(crow,ccol),goodRadius,1,thickness=-1)

    maskFFT[(crow+centerHalfHeightToLeave):,(ccol-notchHalfWidth):(ccol+notchHalfWidth),0] = 0
    maskFFT[:(crow-centerHalfHeightToLeave),(ccol-notchHalfWidth):(ccol+notchHalfWidth),0] = 0

    maskFFT[:,:,1] = maskFFT[:,:,0]

    modifiedFFT = sumFFT * maskFFT[:,:,0]

    return(modifiedFFT, maskFFT)


def calculateMeanFluorescencePerFrame(dataDir, dataFilePrefix, startingFileNum, maskFFT, framesPerFile):
    # Makes sure path ends with '/'
    if (dataDir[-1] is not "/"):
        dataDir = dataDir + "/"

    frameStep = 1
    sumFFT = None
    meanFrameList = []
    fileNum = startingFileNum

    while (path.exists(dataDir + dataFilePrefix + "{:.0f}.avi".format(fileNum))):
        cap = cv2.VideoCapture(dataDir + dataFilePrefix + "{:.0f}.avi".format(fileNum))
        fileNum = fileNum + 1
        for frameNum in tqdm(range(0,framesPerFile, frameStep), total = framesPerFile/frameStep, desc ="Running file {:.0f}.avi".format(fileNum - 1)):
            cap.set(cv2.CAP_PROP_POS_FRAMES, frameNum)
            ret, frame = cap.read()

            if (ret is False):
                break

            else:
                frame = frame[:,:,1]
                dft = cv2.dft(np.float32(frame),flags = cv2.DFT_COMPLEX_OUTPUT|cv2.DFT_SCALE)
                dft_shift = np.fft.fftshift(dft)

                fshift = dft_shift * maskFFT
                f_ishift = np.fft.ifftshift(fshift)
                img_back = cv2.idft(f_ishift)
                img_back = cv2.magnitude(img_back[:,:,0],img_back[:,:,1])
                meanFrameList.append(img_back.mean())            

    meanFrame = np.array(meanFrameList)
    return(meanFrame)

def lowpassFilterMeanFluorescence(meanFrame, butterOrder, cutoff, fs):
    
    b, a = butter(butterOrder, cutoff/ (0.5 * fs), btype='low', analog = False)
    meanFiltered = filtfilt(b,a,meanFrame)

    return(meanFiltered)


def applyFFTLowpassFiltering(dataDir, dataFilePrefix, startingFileNum, cutoffHz, compressionCodec, meanFiltered, maskFFT, rows, cols, framesPerFile):
    #Inputs: pass dataDir, dataFilePrefix, startingFileNum, cutoffHz, 
    #   compressionCodec from command line
    #   meanFiltered from lowpass filtering fn 

    mode = 'save'
    frameStep = 1
    #compressionCodec = "GREY"

    fileNum = startingFileNum
    sumFFT = None
    frameCount = 0
    running = True

    # Makes sure path ends with '/'
    if (dataDir[-1] is not "/"):
        dataDir = dataDir + "/"

    if (mode is "save" and frameStep is not 1):
        print("WARNING: You are only saving every {} frame!".format(frameStep))

    codec = cv2.VideoWriter_fourcc(compressionCodec[0],compressionCodec[1],compressionCodec[2],compressionCodec[3])

    if (mode is "save" and not path.exists(dataDir + "Denoised")):
        os.mkdir(dataDir + "Denoised")

    while (path.exists(dataDir + dataFilePrefix + "{:.0f}.avi".format(fileNum)) and running is True):
        cap = cv2.VideoCapture(dataDir + dataFilePrefix + "{:.0f}.avi".format(fileNum))

        if (mode is "save"):
            writeFile = cv2.VideoWriter(dataDir + "Denoised/" + dataFilePrefix + "denoised{:.0f}.avi".format(fileNum),  
                            codec, 60, (cols,rows), isColor=False) 

        fileNum = fileNum + 1

        for frameNum in tqdm(range(0,framesPerFile, frameStep), total = framesPerFile/frameStep, desc ="Running file {:.0f}.avi".format(fileNum - 1)):
            cap.set(cv2.CAP_PROP_POS_FRAMES, frameNum)
            ret, frame = cap.read()

            if (ret is False):
                break

            else: 
                frame = frame[:,:,1]
                dft = cv2.dft(np.float32(frame),flags = cv2.DFT_COMPLEX_OUTPUT|cv2.DFT_SCALE)
                dft_shift = np.fft.fftshift(dft)
             
                fshift = dft_shift * maskFFT
                f_ishift = np.fft.ifftshift(fshift)
                img_back = cv2.idft(f_ishift)
                img_back = cv2.magnitude(img_back[:,:,0],img_back[:,:,1])

                meanF = img_back.mean()
                img_back = img_back * (1 + (meanFiltered[frameCount] - meanF)/meanF)
                img_back[img_back >255] = 255
                img_back = np.uint8(img_back)

            if (mode is "save"):
                writeFile.write(img_back)

            if (mode is "display"):
                im_diff = (128 + (frame - img_back)*2)
                im_v = cv2.hconcat([frame, img_back])
                im_v = cv2.hconcat([im_v, im_diff])

                im_v = cv2.hconcat([frame, img_back, im_diff])
                #cv2.imshow("Cleaned video", im_v/255)
                #if cv2.waitKey(1) & 0xFF == ord('q'):
                #    running = False
                #    cap.release()
                #    break


            frameCount = frameCount + 1

    if (mode is "save"):
        writeFile.release()

    cv2.destroyAllWindows()

    dirOutput = dataDir + "Denoised"

    return(dirOutput)










