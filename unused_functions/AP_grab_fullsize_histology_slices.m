function AP_grab_fullsize_histology_slices(im_path)
% AP_grab_fullsize_histology_slices(im_path)
%
% Grab and save slices from original fullsize images
% Andy Peters (peters.andrew.j@gmail.com)

% Get and sort image files
im_path_dir = dir([im_path filesep '*.tif*']);
im_fn = natsortfiles(cellfun(@(path,fn) [path filesep fn], ...
    {im_path_dir.folder},{im_path_dir.name},'uni',false));

% Get slice slide_locations
slice_dir = [im_path filesep 'slices'];
slice_slide_locations_fn = [slice_dir filesep 'slice_slide_locations.mat'];
load(slice_slide_locations_fn);

% Load slides, pull full resolution slices, save

slice_fullsize_dir = [im_path filesep 'slices_fullres'];
if ~exist(slice_fullsize_dir,'dir')
    mkdir(slice_fullsize_dir)
end

curr_slice_write = 1; % Counter for naming slices
n_im = length(im_fn);

h = waitbar(0,'Grabbing full resolution slices...');
for curr_im = 1:n_im
    
    % Load slide
    im_info = imfinfo(im_fn{curr_im});
    curr_slide_im = zeros(im_info(1).Height,im_info(1).Width,3,'uint16');
    for curr_channel = 1:3
        curr_slide_im(:,:,curr_channel) = imread(im_fn{curr_im},curr_channel);
    end
    
    % Pull each slice, save, increment slice counter  
    for curr_slice = 1:length(slice_slide_locations{curr_im})
        
        curr_y = slice_slide_locations{curr_im}{curr_slice}{1};
        curr_x = slice_slide_locations{curr_im}{curr_slice}{2};
        
        [grab_px_x,grab_px_y,grab_px_z] = meshgrid(curr_x,curr_y,1:3);
        grab_px_ind = sub2ind(size(curr_slide_im),grab_px_y(:),grab_px_x(:),grab_px_z(:));
        
        curr_slice_im = reshape(curr_slide_im(grab_px_ind),length(curr_y),length(curr_x),3);
        
        curr_slice_fn = [slice_fullsize_dir filesep num2str(curr_slice_write) '.tif'];
        imwrite(curr_slice_im,curr_slice_fn,'tif');
        
        curr_slice_write = curr_slice_write + 1;
        
        waitbar(curr_im/n_im,h,['Loading and resizing images (' ...
            num2str(curr_slice) '/' num2str(length(slice_slide_locations{curr_im})) ' on slide)...']);
        
    end
    
end

close(h);




