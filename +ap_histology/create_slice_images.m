function create_slice_images(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% 1) Resize images by downsampling (if selected)
% 2) Set white balance and color for each channel
% 3) Extract individual slices (if slide images)

% Get data from GUI
histology_toolbar_guidata = guidata(histology_toolbar_gui);

% Check that paths are set and images exist
if isempty(histology_toolbar_guidata.image_path)
    error('No image path set (File selection > Set image path)')
end
if isempty(histology_toolbar_guidata.save_path)
    error('No save path set (File selection > Set save path)')
end

% Get and sort image files
histology_toolbar_guidata.image_path_dir = dir(fullfile(histology_toolbar_guidata.image_path,'*.tif'));
% (error if none found)
if isempty(histology_toolbar_guidata.image_path_dir)
    error('No TIFF images found in %s',histology_toolbar_guidata.image_path)
end
im_fn = natsortfiles(cellfun(@(path,fn) fullfile(path,fn), ...
    {histology_toolbar_guidata.image_path_dir.folder},{histology_toolbar_guidata.image_path_dir.name},'uni',false));

% Get user settings
im_settings = inputdlg({'Image downsample factor: (resize to 1/X)', ...
    'Are images individual slices? (1 = yes, 0 = no)'},'Image preprocessing settings',1, ...
    {'1','1'});
downsample_factor = str2double(im_settings{1});
slice_images = str2double(im_settings{2});

% If image is RGB, set flag
im_info = imfinfo(im_fn{1});
im_is_rgb = strcmp(im_info(1).PhotometricInterpretation,'RGB');

% Load and resize images
n_im = length(im_fn);

h = waitbar(0,'Loading and resizing images...');
if ~im_is_rgb
    % If channels separated as b/w, load in separately and white balance
    
    n_channels = sum(any([im_info.Height;im_info.Width],1));
    im_resized = cell(n_im,n_channels);
    
    for curr_im = 1:n_im
        for curr_channel = 1:n_channels
            im_resized{curr_im,curr_channel} = imresize(imread(im_fn{curr_im},curr_channel),1/downsample_factor);
        end
        waitbar(curr_im/n_im,h,['Loading and resizing images (' num2str(curr_im) '/' num2str(n_im) ')...']);
    end
    close(h);
    
    % Estimate white balance within each channel
    % (dirty: assume one peak for background, one for signal)
    h = figure;
    im_montage = cell(n_channels,1);
    channel_caxis = nan(n_channels,2);
    channel_color = cell(n_channels,1);
    for curr_channel = 1:n_channels
        
        curr_montage = montage(im_resized(:,curr_channel));
        
        im_montage{curr_channel} = curr_montage.CData;
        
        im_hist = histcounts(im_montage{curr_channel}(im_montage{curr_channel} > 0),0:max(im_montage{curr_channel}(:)));
        im_hist_smoothed = smooth(im_hist,50,'loess');
        im_hist_deriv = [0;diff(im_hist_smoothed)];
        
        % The signal minimum is the valley between background and signal
        [~,bg_down] = min(im_hist_deriv);
        bg_signal_min = find(im_hist_deriv(bg_down:end) > 0,1) + bg_down;
        % The signal maximum is < 1% median value
        [~,bg_median_rel] = max(im_hist_smoothed(bg_signal_min:end));
        signal_median = bg_median_rel + bg_signal_min - 1;
        signal_high_cutoff = im_hist_smoothed(signal_median)*0.01;
        signal_high_rel = find(im_hist_smoothed(signal_median:end) < signal_high_cutoff,1);
        signal_high = signal_high_rel + signal_median;
        % (if no < 1%, just take max)
        if(isempty(signal_high))
            signal_high = length(im_hist_smoothed);
        end
        
        cmin = bg_signal_min;
        cmax = signal_high;
        caxis([cmin,cmax]);
        
        check_contrast = questdlg('Contrast ok?','Set contrast','Yes','Manual','Yes');
        if strcmp(check_contrast,'Manual')
            waitfor(imcontrast(gcf));
            [cmin,cmax] = caxis;
        end
        
        channel_caxis(curr_channel,:) = [cmin,cmax];
        
        % Choose channel color
        channel_color{curr_channel} = uisetcolor([],'Pick channel color');
        
    end
    close(h)

    % Store RGB for each slide
    color_vector = permute(cell2mat(channel_color),[3,4,1,2]);
    im_rgb = cellfun(@(x) zeros(size(x,1),size(x,2),3),im_resized(:,1),'uni',false);
    for curr_im = 1:n_im
        rescaled_balanced_combined_im = ...
            cell2mat(arrayfun(@(ch) rescale(im_resized{curr_im,ch}, ...
            'InputMin',channel_caxis(ch,1),'InputMax',channel_caxis(ch,2)), ...
            permute(1:n_channels,[1,3,2]),'uni',false));
        
        im_rgb{curr_im} = min(permute(sum(rescaled_balanced_combined_im.* ...
            color_vector,3),[1,2,4,3]),1);     
    end

elseif im_is_rgb
    % If images are already RGB, just load in and resize
    im_rgb = cell(n_im,1);
    for curr_im = 1:n_im
        im_rgb{curr_im} = imresize(imread(im_fn{curr_im}),downsample_factor);
        waitbar(curr_im/n_im,h,['Loading and resizing images (' num2str(curr_im) '/' num2str(n_im) ')...']);
    end
    close(h)
end

if ~slice_images
    % If slide images, set up GUI to pick slices on slide to extract
    
    slice_fig = figure('KeyPressFcn',@slice_keypress);
    
    % Initialize data
    gui_data = struct;
    gui_data.histology_toolbar_gui = histology_toolbar_gui;
    gui_data.image_path = histology_toolbar_guidata.image_path;
    gui_data.im_fn = im_fn;
    gui_data.im_rescale_factor = downsample_factor;
    gui_data.im_rgb = im_rgb;
    gui_data.curr_slide = 0;
    gui_data.slice_mask = cell(0,0);
    gui_data.slice_rgb = cell(0,0);
    
    % Update gui data
    guidata(slice_fig, gui_data);
    
    % Update slide
    update_slide(slice_fig);
    
elseif slice_images
    % If slice images, save all images as-is
    
    % Set save directory as subdirectory within original
    if ~exist(histology_toolbar_guidata.save_path,'dir')
        mkdir(histology_toolbar_guidata.save_path)
    end
    
    % Write all slice images to separate files
    disp('Saving slice images...');
    for curr_im = 1:length(im_rgb)
        curr_im_filename = fullfile(histology_toolbar_guidata.save_path,sprintf('slice_%d.tif',curr_im));
        imwrite(im_rgb{curr_im},curr_im_filename,'tif');
    end
    disp('Done.');

    % Update toolbar GUI
    ap_histology.update_toolbar_gui(histology_toolbar_gui);

end

end

function slice_click(slice_fig,eventdata)
% On slice click, mark to extract

gui_data = guidata(slice_fig);

if eventdata.Button == 1
    
    selected_slice_bw = bwselect(gui_data.mask,eventdata.IntersectionPoint(1),eventdata.IntersectionPoint(2));
    
    % If the selected slice is already part of a user mask, delete that ROI
    if size(gui_data.user_masks,3) > 0
        clicked_mask = false(size(gui_data.mask));
        clicked_mask(round(eventdata.IntersectionPoint(2)),round(eventdata.IntersectionPoint(1))) = true;
        overlap_roi = any(clicked_mask(:) & reshape(gui_data.user_masks,[],size(gui_data.user_masks,3)),1);
        if any(overlap_roi)
            % Clear overlapping mask
            gui_data.user_masks(:,:,overlap_roi) = [];
            
            % Delete and clear bounding box
            delete(gui_data.user_rectangles(overlap_roi));
            gui_data.user_rectangles(overlap_roi) = [];
            
            % Update gui data
            guidata(slice_fig, gui_data);
            return
        end
    end
    
    % If left button pressed, create new slice ROI
    roi_num = size(gui_data.user_masks,3) + 1;
    
    % Make new mask with object
    gui_data.user_masks(:,:,roi_num) = selected_slice_bw;
    
    % Draw bounding box around object
    box_x = find(any(gui_data.user_masks(:,:,roi_num),1),1);
    box_y = find(any(gui_data.user_masks(:,:,roi_num),2),1);
    box_w = find(any(gui_data.user_masks(:,:,roi_num),1),1,'last') - box_x;
    box_h = find(any(gui_data.user_masks(:,:,roi_num),2),1,'last') - box_y;
    gui_data.user_rectangles(roi_num) = ...
        rectangle('Position',[box_x,box_y,box_w,box_h],'EdgeColor','w');
    
elseif eventdata.Button == 3
    % If right button pressed, manually draw rectangle ROI
    roi_num = size(gui_data.user_masks,3) + 1;
    
    % Draw ROI
    manual_roi = imrect;
    
    % Make new mask with object
    gui_data.user_masks(:,:,roi_num) = manual_roi.createMask;
    
    % Draw bounding box
    gui_data.user_rectangles(roi_num) = ...
        rectangle('Position',manual_roi.getPosition,'EdgeColor','w');
    
    % Delete the ROI
    manual_roi.delete;
    
end

% Update gui data
guidata(slice_fig, gui_data);

end

function slice_keypress(slice_fig,eventdata)
% Move to next slide with spacebar

if strcmp(eventdata.Key,'space')
    update_slide(slice_fig)
end

end

function update_slide(slice_fig)
% Find slices on slide by over-threshold objects of a large enough size

gui_data = guidata(slice_fig);

% Pull the images from selected slices (not during initialization)
if gui_data.curr_slide > 0
    extract_slice_rgb(slice_fig);
    gui_data = guidata(slice_fig);
end

% After the last slice, save the images and close out
if gui_data.curr_slide == length(gui_data.im_rgb)
    save_slice_rgb(slice_fig);
    close(slice_fig);
    return
end

gui_data.curr_slide = gui_data.curr_slide + 1;

% Minimum slice size
min_slice = 1000; %(1000/10)^2; % (um/10(CCF units))^2

% Estimate slice white threshold
curr_im_bw = nanmean(gui_data.im_rgb{gui_data.curr_slide},3);
[im_hist,im_hist_edges] = histcounts(curr_im_bw, ...
    linspace(min(curr_im_bw(:)),max(curr_im_bw(:)),100));
im_hist_deriv = [0;diff(smooth(im_hist,3))];
[~,bg_down] = min(im_hist_deriv);
bg_signal_min = find(im_hist_deriv(bg_down:end) > 0,1) + bg_down;
slice_threshold = im_hist_edges(bg_signal_min)*0.5; % err on the smaller side

slice_mask = imfill(bwareaopen(mean( ...
    gui_data.im_rgb{gui_data.curr_slide},3) > slice_threshold,min_slice),'holes');
slice_conncomp = bwconncomp(slice_mask);

im_handle = imshow(gui_data.im_rgb{gui_data.curr_slide});
set(im_handle,'ButtonDownFcn',@slice_click);
title('Finding slice boundaries...');
drawnow;

slice_boundaries = bwboundaries(slice_mask);
slice_lines = gobjects(length(slice_boundaries),1);
for curr_slice = 1:length(slice_boundaries)
    slice_lines(curr_slice) = line(slice_boundaries{curr_slice}(:,2), ...
        slice_boundaries{curr_slice}(:,1),'color','w','linewidth',2,'LineSmoothing','on','linestyle','--');
end
title('Click to save/remove (left = auto, right = manual), spacebar to finish slide');

gui_data.im_h = im_handle;
gui_data.mask = slice_mask;
gui_data.lines = slice_lines;
gui_data.user_masks = zeros(size(slice_mask,1),size(slice_mask,2),0,'logical');
gui_data.user_rectangles = gobjects(0);

% Update gui data
guidata(slice_fig, gui_data);

end


function extract_slice_rgb(slice_fig)
% When changing slide, extract the selected slice images

gui_data = guidata(slice_fig);

n_slices = size(gui_data.user_masks,3);
curr_slice_mask = cell(n_slices,1);
curr_slice_rgb = cell(n_slices,1);
for curr_slice = 1:n_slices
    % Pull a rectangular area, exclude spaces (e.g. between torn piece)
    dilate_size = 30;
    curr_mask = imdilate(logical(any(gui_data.user_masks(:,:,curr_slice),2).* ...
        any(gui_data.user_masks(:,:,curr_slice),1)),ones(dilate_size));
    
    curr_rgb = reshape(gui_data.im_rgb{gui_data.curr_slide}( ...
        repmat(curr_mask,1,3)),sum(any(curr_mask,2)),sum(any(curr_mask,1)),3);
    
    curr_slice_mask{curr_slice} = curr_mask;
    curr_slice_rgb{curr_slice} = curr_rgb;
    
end

% Store the image and mask for each slice
gui_data.slice_mask{gui_data.curr_slide} = curr_slice_mask;
gui_data.slice_rgb{gui_data.curr_slide} = curr_slice_rgb;

% Update gui data
guidata(slice_fig, gui_data);

end


function save_slice_rgb(slice_fig)
% After the last slide, save the slice images

gui_data = guidata(slice_fig);

% Set save directory as subdirectory within original
save_dir = fullfile(gui_data.image_path,'slices');
if ~exist(save_dir,'dir')
    mkdir(save_dir)
end

% Concatenate all slice images
slice_rgb_cat = vertcat(gui_data.slice_rgb{:});

% Write all slice images to separate files
for curr_im = 1:length(slice_rgb_cat)
    curr_fn = fullfile(save_dir,sprintf('slice_%d.tif',curr_im));
    imwrite(slice_rgb_cat{curr_im},curr_fn,'tif');
end

% Get rows and columns for each slice corresponding to full size image
slice_slide_locations = cell(size(gui_data.slice_mask));
for curr_slide = 1:length(gui_data.slice_mask)
    for curr_slice = 1:length(gui_data.slice_mask{curr_slide})
        
        curr_mask = gui_data.slice_mask{curr_slide}{curr_slice};
        
        mask_x = find(interp1(1:size(curr_mask,2),+any(curr_mask,1), ...
            linspace(1,size(curr_mask,2), ...
            round(size(curr_mask,2)/gui_data.im_rescale_factor)),'nearest'));
        mask_y = find(interp1(1:size(curr_mask,1),+any(curr_mask,2), ...
            linspace(1,size(curr_mask,1), ...
            round(size(curr_mask,1)/gui_data.im_rescale_factor)),'nearest'));
        
        slice_slide_locations{curr_slide}{curr_slice} = ...
            {mask_y,mask_x};
        
    end
end

slice_slide_locations_fn = fullfile(save_dir,'slice_slide_locations.mat');
save(slice_slide_locations_fn,'slice_slide_locations');

disp(['Slices saved in ' save_dir]);

end



