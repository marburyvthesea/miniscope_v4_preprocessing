
%AVI from miniscope to mutliframe tiff
%   Input: full path to move file


movie_start = str2num(movie_start);
movie_end = str2num(movie_end);

disp('movie start');
disp(movie_start);
disp('movie end'); 
disp(movie_end); 




%loop through videos  
if parallel == true
   
    disp('processing in parallel');

    parfor x = movie_start:movie_end
	disp(x);	
        img_path = fullfile(dirpath, sprintf('%s%d.tif', regExp, x));
        convertMultiTiffToGrayFn(img_path);
    end
    
else

    disp('parellel off');

    for x = movie_start:movie_end
	disp(x);
        img_path = fullfile(dirpath, sprintf('%s%d.tif', regExp, x));
        convertMultiTiffToGrayFn(img_path);

    end    
end
