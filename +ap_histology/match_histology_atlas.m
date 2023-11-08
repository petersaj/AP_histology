function match_histology_atlas(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Choose CCF atlas slices corresponding to histology slices

% Initialize guidata
gui_data = struct;

% Store toolbar handle
gui_data.histology_toolbar_gui = histology_toolbar_gui;

% Load atlas
allen_atlas_path = fileparts(which('template_volume_10um.npy'));
if isempty(allen_atlas_path)
    error('No CCF atlas found (add CCF atlas to path)')
end
disp('Loading Allen CCF atlas...')
gui_data.tv = readNPY(fullfile(allen_atlas_path,'template_volume_10um.npy'));
gui_data.av = readNPY(fullfile(allen_atlas_path,'annotation_volume_10um_by_index.npy'));
gui_data.st = ap_histology.loadStructureTree(fullfile(allen_atlas_path,'structure_tree_safe_2017.csv'));
disp('Done.')

% Get images (from path in GUI)
histology_toolbar_guidata = guidata(histology_toolbar_gui);

slice_dir = dir(fullfile(histology_toolbar_guidata.save_path,'*.tif'));
slice_fn = natsortfiles(cellfun(@(path,fn) fullfile(path,fn), ...
    {slice_dir.folder},{slice_dir.name},'uni',false));

gui_data.slice_im = cell(length(slice_fn),1);
for curr_slice = 1:length(slice_fn)
   gui_data.slice_im{curr_slice} = imread(slice_fn{curr_slice});  
end

% Set save path (from toolbar GUI
gui_data.save_path = histology_toolbar_guidata.save_path;

% Create figure, set button functions
screen_size_px = get(0,'screensize');
gui_aspect_ratio = 1.7; % width/length
gui_width_fraction = 0.6; % fraction of screen width to occupy
gui_width_px = screen_size_px(3).*gui_width_fraction;
gui_position = [...
    (screen_size_px(3)-gui_width_px)/2, ... % left x
    (screen_size_px(4)-gui_width_px/gui_aspect_ratio)/2, ... % bottom y
    gui_width_px,gui_width_px/gui_aspect_ratio]; % width, height

gui_fig = figure('WindowScrollWheelFcn',@scroll_atlas_slice, ...
    'KeyPressFcn',@keypress,'Toolbar','none','Menubar','none','color','w', ...
    'Units','pixels','Position',gui_position, ...
    'CloseRequestFcn',@close_gui);

% Set up axis for histology image
gui_data.histology_ax = subplot(1,2,1,'YDir','reverse'); 
hold on; axis image off;
gui_data.histology_im_h = image(gui_data.slice_im{1},'Parent',gui_data.histology_ax);
gui_data.curr_histology_slice = 1;
title(gui_data.histology_ax,'No saved atlas position');

% Set up 3D atlas axis
gui_data.atlas_ax = subplot(1,2,2, ...
    'ZDir','reverse','color','k', ...
    'XTick',[1,size(gui_data.av,1)],'XTickLabel',{'Front','Back'}, ...
    'YTick',[1,size(gui_data.av,3)],'YTickLabel',{'Left','Right'}, ...
    'ZTick',[1,size(gui_data.av,2)],'ZTickLabel',{'Top','Bottom'});
hold on
axis vis3d equal manual
view([90,0]);
[ap_max,dv_max,ml_max] = size(gui_data.tv);
xlim([1,ap_max]);
ylim([1,ml_max]);
zlim([1,dv_max]);
colormap(gui_data.atlas_ax,'gray');
caxis([0,400]);
gui_data.atlas_title = title(sprintf('Slice position: %d',0));

% Create CCF colormap
% (copied from cortex-lab/allenCCF/setup_utils
ccf_color_hex = gui_data.st.color_hex_triplet;
ccf_color_hex(cellfun(@numel,ccf_color_hex)==5) = {'019399'}; % special case where leading zero was evidently dropped
ccf_cmap_c1 = cellfun(@(x)hex2dec(x(1:2)), ccf_color_hex, 'uni', false);
ccf_cmap_c2 = cellfun(@(x)hex2dec(x(3:4)), ccf_color_hex, 'uni', false);
ccf_cmap_c3 = cellfun(@(x)hex2dec(x(5:6)), ccf_color_hex, 'uni', false);
gui_data.ccf_cmap = ...
    horzcat(vertcat(ccf_cmap_c1{:}),vertcat(ccf_cmap_c2{:}),vertcat(ccf_cmap_c3{:}))./255;

% Set mode for atlas view (can be either TV, AV, or TV-AV)
gui_data.atlas_mode = 'TV';

% Create slice object and first slice point
gui_data.atlas_slice_plot = surface(gui_data.atlas_ax,'EdgeColor','none'); % Slice on 3D atlas
gui_data.atlas_slice_point = camtarget;

% Set up atlas parameters to save for histology
gui_data.slice_vector = nan(1,3);
gui_data.slice_points = nan(length(gui_data.slice_im),3);

% Upload gui data
guidata(gui_fig,gui_data);

% Draw the first slice
update_atlas_slice(gui_fig);

% Print controls
CreateStruct.Interpreter = 'tex';
CreateStruct.WindowStyle = 'non-modal';
msgbox( ...
    {'\fontsize{12}' ...
    '\bf Controls: \rm' ...
    'Left/right arrows: cycle histology slice', ...
    'Shift + arrows: change atlas rotation', ...
    'm : change atlas display mode (TV/AV/TV-AV overlay)', ...
    'Scroll wheel: move CCF slice in/out of plane', ...
    'Enter: set current histology and CCF slice pair'}, ...
    'Controls',CreateStruct);

end 

function keypress(gui_fig,eventdata)

% Get guidata
gui_data = guidata(gui_fig);

shift_on = any(strcmp(eventdata.Modifier,'shift'));

switch eventdata.Key
    
    % Left/right: cycle through histology slices
    % (if there's a saved plane point, move atlas to that position)
    % Shift + arrow keys: rotate atlas slice
    case 'leftarrow'
        if ~shift_on
            gui_data.curr_histology_slice = max(gui_data.curr_histology_slice - 1,1);
            guidata(gui_fig,gui_data);
            update_histology_slice(gui_fig);
        elseif shift_on
            set(gui_data.atlas_ax,'View',get(gui_data.atlas_ax,'View') + [1,0]);
            update_atlas_slice(gui_fig)
        end
    case 'rightarrow'
        if ~shift_on
            gui_data.curr_histology_slice = ...
                min(gui_data.curr_histology_slice + 1,length(gui_data.slice_im));
            guidata(gui_fig,gui_data);
            update_histology_slice(gui_fig);
        elseif shift_on
            set(gui_data.atlas_ax,'View',get(gui_data.atlas_ax,'View') + [-1,0]);
            update_atlas_slice(gui_fig)
        end
    case 'uparrow'
        if shift_on
            set(gui_data.atlas_ax,'View',get(gui_data.atlas_ax,'View') + [0,-1]);
            update_atlas_slice(gui_fig)
        end
    case 'downarrow'
        if shift_on
            set(gui_data.atlas_ax,'View',get(gui_data.atlas_ax,'View') + [0,1]);
            update_atlas_slice(gui_fig)
        end

    % M key: switch atlas display mode
    case 'm'
        atlas_slice_modes = {'TV','AV','TV-AV'};
        curr_atlas_mode_idx = strcmp(gui_data.atlas_mode,atlas_slice_modes);
        gui_data.atlas_mode = atlas_slice_modes{circshift(curr_atlas_mode_idx,[0,1])};
        guidata(gui_fig,gui_data);
        update_atlas_slice(gui_fig);

    % Enter: save slice coordinates
    case 'return'        
        % Store camera vector and point
        % (Note: only one camera vector used for all slices, overwrites)
        gui_data.slice_vector = get_camera_vector(gui_data);
        gui_data.slice_points(gui_data.curr_histology_slice,:) = ...
            gui_data.atlas_slice_point;
        guidata(gui_fig,gui_data);
                
        update_histology_slice(gui_fig);
        title(gui_data.histology_ax,'New saved atlas position');
        
end

end

function update_histology_slice(gui_fig)
% Draw histology slice (and move atlas if saved position)

% Get guidata
gui_data = guidata(gui_fig);

% Set next histology slice
set(gui_data.histology_im_h,'CData',gui_data.slice_im{gui_data.curr_histology_slice})

% If there's a saved atlas position, move atlas to there
if all(~isnan(gui_data.slice_points(gui_data.curr_histology_slice,:)))
    gui_data.atlas_slice_point = ...
        gui_data.slice_points(gui_data.curr_histology_slice,:);
    title(gui_data.histology_ax,'Saved atlas position')
    guidata(gui_fig,gui_data);
    update_atlas_slice(gui_fig);
else
    title(gui_data.histology_ax,'No saved atlas position')
end

% Upload gui data
guidata(gui_fig, gui_data);

end

function cam_vector = get_camera_vector(gui_data)
% Get the camera viewing vector to define atlas slice plane

% Grab current camera angle
% (normalized line from the camera to the center)
curr_campos = campos(gui_data.atlas_ax);
curr_camtarget = camtarget(gui_data.atlas_ax);
cam_vector = (curr_camtarget - curr_campos)./norm(curr_camtarget - curr_campos);

end

function scroll_atlas_slice(gui_fig,eventdata)
% Move point to draw atlas slice perpendicular to the camera

% Get guidata
gui_data = guidata(gui_fig);

% Move slice point along camera -> center axis
cam_vector = get_camera_vector(gui_data);

% Move slice point
gui_data.atlas_slice_point = gui_data.atlas_slice_point + ...
    eventdata.VerticalScrollCount*cam_vector;

% Upload gui data
guidata(gui_fig, gui_data);

% Update slice
update_atlas_slice(gui_fig)

end

function update_atlas_slice(gui_fig)
% Draw atlas slice through plane perpendicular to camera through set point

% Get guidata
gui_data = guidata(gui_fig);

% Get slice (larger spacing for faster pulling)
[tv_slice,av_slice,plane_ap,plane_ml,plane_dv] = grab_atlas_slice(gui_data,3);

% Update the slice display (depending on display mode)
switch gui_data.atlas_mode
    case 'TV'
        atlas_slice = tv_slice;
        colormap(gray);caxis([0,516]);
    case 'AV'
        av_boundaries = round(conv2(av_slice,ones(2)./4,'same')) ~= av_slice;
        atlas_slice = imoverlay(mat2gray(tv_slice,[0,516]),av_boundaries,'r');
        caxis([0,1]);
    case 'TV-AV'
        atlas_slice = av_slice;
        colormap(gui_data.ccf_cmap)
        caxis(gui_data.atlas_ax,[1,size(gui_data.ccf_cmap,1)])
end
set(gui_data.atlas_slice_plot,'XData',plane_ap,'YData',plane_ml,'ZData',plane_dv,'CData',atlas_slice);

% Upload gui_data
guidata(gui_fig, gui_data);

end

function [tv_slice,av_slice,plane_ap,plane_ml,plane_dv] = grab_atlas_slice(gui_data,slice_px_space)
% Grab anatomical and labelled atlas within slice

% Get plane normal to the camera -> center axis, grab voxels on plane
cam_vector = get_camera_vector(gui_data);
plane_offset = -(cam_vector*gui_data.atlas_slice_point');

% Define a plane of points to index
% (the plane grid is defined based on the which cardinal plan is most
% orthogonal to the plotted plane. this is janky but it works)

[~,cam_plane] = max(abs(cam_vector./norm(cam_vector)));

switch cam_plane
    
    % Note: ML and DV directions are flipped to match 2D histology and 3D
    % atlas axes, so make ML and DV coordinates go backwards for true CCF
    % coordinates
    
    case 1
        [plane_ml,plane_dv] = ...
            meshgrid(1:slice_px_space:size(gui_data.tv,3), ...
            1:slice_px_space:size(gui_data.tv,2));
        plane_ap = ...
            (cam_vector(2)*plane_ml+cam_vector(3)*plane_dv + plane_offset)/ ...
            -cam_vector(1);
        
    case 2
        [plane_ap,plane_dv] = ...
            meshgrid(1:slice_px_space:size(gui_data.tv,1), ...
            1:slice_px_space:size(gui_data.tv,2));
        plane_ml = ...
            (cam_vector(1)*plane_ap+cam_vector(3)*plane_dv + plane_offset)/ ...
            -cam_vector(2);
        
    case 3
        [plane_ap,plane_ml] = ...
            meshgrid(size(gui_data.tv,1):-slice_px_space:1, ...
            1:slice_px_space:size(gui_data.tv,3));
        plane_dv = ...
            (cam_vector(1)*plane_ap+cam_vector(2)*plane_ml + plane_offset)/ ...
            -cam_vector(3);
        
end

% Get the coordiates on the plane
ap_idx = round(plane_ap);
ml_idx = round(plane_ml);
dv_idx = round(plane_dv);

% Find plane coordinates in bounds with the volume
% (CCF coordinates: [AP,DV,ML])
use_ap = ap_idx > 0 & ap_idx < size(gui_data.tv,1);
use_dv = dv_idx > 0 & dv_idx < size(gui_data.tv,2);
use_ml = ml_idx > 0 & ml_idx < size(gui_data.tv,3);
use_idx = use_ap & use_ml & use_dv;

curr_slice_idx = sub2ind(size(gui_data.tv),ap_idx(use_idx),dv_idx(use_idx),ml_idx(use_idx));

% Find plane coordinates that contain brain
curr_slice_isbrain = false(size(use_idx));
curr_slice_isbrain(use_idx) = gui_data.av(curr_slice_idx) > 0;

% Index coordinates in bounds + with brain
grab_pix_idx = sub2ind(size(gui_data.tv),ap_idx(curr_slice_isbrain),dv_idx(curr_slice_isbrain),ml_idx(curr_slice_isbrain));

% Grab pixels from (selected) volume
tv_slice = nan(size(use_idx));
tv_slice(curr_slice_isbrain) = gui_data.tv(grab_pix_idx);

av_slice = nan(size(use_idx));
av_slice(curr_slice_isbrain) = gui_data.av(grab_pix_idx);

% Update slice position title
plane_offset_mm = plane_offset/100; % CCF = 10um voxels
set(gui_data.atlas_title,'string', ...
    sprintf('Slice position: %.2f mm',plane_offset_mm));

end

function close_gui(gui_fig,~)

% Get guidata
gui_data = guidata(gui_fig);


% Check that a CCF slice point exists for each histology slice
if any(isnan(gui_data.slice_points(:)))
    createmode = struct;
    createmode.Interpreter = 'tex';
    createmode.WindowStyle = 'modal';
    uiwait(msgbox('\fontsize{12} Note: some histology slice(s) not assigned atlas slice', ...
        'Incomplete slice assignment','warn',createmode));
end

opts.Default = 'Yes';
opts.Interpreter = 'tex';
user_confirm = questdlg('\fontsize{14} Save?','Confirm exit',opts);
switch user_confirm
    case 'Yes'
        % Go through each slice, pull full-resolution atlas slice and
        % corrsponding coordinates
        histology_ccf_init = cell(length(gui_data.slice_im),1);
        histology_ccf = struct( ...
            'tv_slices',histology_ccf_init, ...
            'av_slices',histology_ccf_init, ...
            'plane_ap',histology_ccf_init, ...
            'plane_ml',histology_ccf_init, ...
            'plane_dv',histology_ccf_init);

        h = waitbar(0,'Saving atlas slices...');
        for curr_slice = 1:length(gui_data.slice_im)
            gui_data.atlas_slice_point = gui_data.slice_points(curr_slice,:);
            [histology_ccf(curr_slice).tv_slices, ...
                histology_ccf(curr_slice).av_slices, ...
                histology_ccf(curr_slice).plane_ap, ...
                histology_ccf(curr_slice).plane_ml, ...
                histology_ccf(curr_slice).plane_dv] = ...
                grab_atlas_slice(gui_data,1);
            waitbar(curr_slice/length(gui_data.slice_im),h, ...
                ['Saving atlas slices (' num2str(curr_slice) '/' num2str(length(gui_data.slice_im)) ')...']);
        end
        close(h);

        save_fn = fullfile(gui_data.save_path,'histology_ccf.mat');
        save(save_fn,'histology_ccf','-v7.3');
        delete(gui_fig);

    case 'No'
        % Close without saving
        delete(gui_fig);

    case 'Cancel'
        % Do nothing

end 

% Update toolbar GUI
ap_histology.update_toolbar_gui(gui_data.histology_toolbar_gui);

end











