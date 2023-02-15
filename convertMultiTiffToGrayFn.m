function [output] = convertMultiTiffToGrayFn(img_path)

%get number of frames
[filepath,name,ext] = fileparts(img_path);
image_info=imfinfo(img_path);
image_structure = size(image_info);
frame_number = image_structure(1,1);
%read first frame, convert to gray, save
img=imread(img_path, 1);
gray_img=rgb2gray(img);
imwrite(gray_img, strcat(filepath,'/',name,'_converted','.tif'));

%save subsequent frames
for i = 2 : frame_number
    img=imread(img_path, i);
    gray_img = rgb2gray(img);
    imwrite(gray_img, strcat(filepath,'/',name,'_converted','.tif'), ...
        'writemode', 'append');
end
    
disp(strcat(filepath,name,'_converted','.tif'));

output='done'; 
