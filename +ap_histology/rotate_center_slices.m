function rotate_center_slices(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Pad, center, and rotate slice images

% Get images (from path in GUI)
histology_toolbar_guidata = guidata(histology_toolbar_gui);

slice_dir = dir(fullfile(histology_toolbar_guidata.save_path,'*.tif'));
slice_fn = natsortfiles(cellfun(@(path,fn) fullfile(path,fn), ...
    {slice_dir.folder},{slice_dir.name},'uni',false));

slice_im = cell(length(slice_fn),1);
for curr_slice = 1:length(slice_fn)
   slice_im{curr_slice} = imread(slice_fn{curr_slice});  
end

% Pad all slices centrally to the largest slice and make matrix
slice_size_max = max(cell2mat(cellfun(@size,slice_im,'uni',false)),[],1);
slice_im_pad = ...
    cell2mat(cellfun(@(x) x(1:slice_size_max(1),1:slice_size_max(2),:), ...
    reshape(cellfun(@(im) padarray(im, ...
    [ceil((slice_size_max(1) - size(im,1))./2), ...
    ceil((slice_size_max(2) - size(im,2))./2)],0,'both'), ...
    slice_im,'uni',false),1,1,1,[]),'uni',false));

% Draw line to indicate midline for rotation
screen_size_px = get(0,'screensize');
gui_aspect_ratio = 1.7; % width/length
gui_width_fraction = 0.6; % fraction of screen width to occupy
gui_width_px = screen_size_px(3).*gui_width_fraction;
gui_position = [...
    (screen_size_px(3)-gui_width_px)/2, ... % left x
    (screen_size_px(4)-gui_width_px/gui_aspect_ratio)/2, ... % bottom y
    gui_width_px,gui_width_px/gui_aspect_ratio]; % width, height

gui_fig = figure('Toolbar','none','Menubar','none','color','w', ...
    'Units','pixels','Position',gui_position);

align_axis = nan(2,2,length(slice_im));
for curr_im = 1:length(slice_im)
    image(slice_im_pad(:,:,:,curr_im));
    axis equal off;
    title('Click and drag reference line (e.g. midline)')
    curr_line = imline;
    align_axis(:,:,curr_im) = curr_line.getPosition;  
end
close(gui_fig);

% Get angle for all axes
align_angle = squeeze(atan2d(diff(align_axis(:,1,:),[],1),diff(align_axis(:,2,:),[],1)));
align_center = permute(nanmean(align_axis,1),[2,3,1]);

% Set target angle as the nearest multiple of 90
target_angle = round(nanmean(align_angle)/90)*90;

% Set target position as the average center of the reference lines
target_position = nanmean(align_center,2);

im_aligned = zeros(size(slice_im_pad),class(slice_im_pad));

for curr_im = 1:length(slice_im)
    
    angle_diff = target_angle - align_angle(curr_im);
    x_diff = target_position(1) - align_center(1,curr_im);
    y_diff = target_position(2) - align_center(2,curr_im);
    
    im_aligned(:,:,:,curr_im) = ...
        imrotate(imtranslate(slice_im_pad(:,:,:,curr_im), ...
        [x_diff,y_diff]),angle_diff,'bilinear','crop');
    
end

% Overwrite old images with new ones
for curr_im = 1:size(im_aligned,4)
    imwrite(im_aligned(:,:,:,curr_im),slice_fn{curr_im},'tif');
end
disp('Saved rotated and centered slice images');





