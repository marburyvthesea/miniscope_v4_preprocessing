
%for local machine, specify path to ffmpeg
%currentPath = getenv('PATH');
%ffmpegPath = '/opt/homebrew/bin' ; 
% Update the PATH for MATLAB
%setenv('PATH', [currentPath ':' ffmpegPath]);
%% Specify the directory path
%folderPath = '/Users/johnmarshall/Documents/MATLAB/aviToTiffMATLAB';

% Use dir to get all .avi files with "denoised" in their name
filePattern = fullfile(folderPath, '*denoised*.avi');
aviFiles = dir(filePattern);


% Output folder for the TIFF files
outputFolder = fullfile(folderPath, 'TIFF_frames');
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end
disp(folderPath);
% Loop through each .avi file and convert to a multipage TIFF
for i = 1:length(aviFiles)
    disp(aviFiles(i).name);
    % Get the full path of the input .avi file
    inputFile = fullfile(aviFiles(i).folder, aviFiles(i).name);
    
    % Create the output TIFF file path
    [~, fileBaseName, ~] = fileparts(inputFile);
    outputTiffFile = fullfile(outputFolder, [fileBaseName, '.tiff']);
    
    % FFmpeg command to extract frames to MATLAB memory and process
    % Extract the video as raw RGB frames to be loaded in MATLAB
    tempDir = fullfile(outputFolder, 'temp_frames');
    if ~exist(tempDir, 'dir')
        mkdir(tempDir);
    end
    tempPattern = fullfile(tempDir, 'frame_%04d.png');
    command = sprintf('ffmpeg -i "%s" "%s"', inputFile, tempPattern);
    
    % Run the FFmpeg command to extract frames as temporary PNG files
    status = system(command);
    
    if status == 0
        % Get a list of the extracted PNG frames
        frameFiles = dir(fullfile(tempDir, '*.png'));
        
        if isempty(frameFiles)
            fprintf('No frames found for %s\n', aviFiles(i).name);
            continue;
        end
        
        % Loop through the extracted frames and write them to the multipage TIFF
        for j = 1:length(frameFiles)
            % Read the current frame
            frameIn = imread(fullfile(tempDir, frameFiles(j).name));
            frame = im2uint16(im2gray(frameIn));  % Convert to 16-bit grayscale

            % Write the frame to the multipage TIFF
            if j == 1
                % For the first frame, create the TIFF file
                imwrite(frame, outputTiffFile, 'tiff', 'WriteMode', 'overwrite', 'Compression', 'none');
            else
                % Append subsequent frames to the multipage TIFF
                imwrite(frame, outputTiffFile, 'tiff', 'WriteMode', 'append', 'Compression', 'none');
            end
        end
        
        % Remove temporary files after writing the TIFF
        delete(fullfile(tempDir, '*.png'));
        
        fprintf('Successfully converted %s to a multipage TIFF.\n', aviFiles(i).name);
    else
        fprintf('Failed to extract frames from %s.\n', aviFiles(i).name);
    end
end

% Cleanup temp folder
rmdir(tempDir, 's');