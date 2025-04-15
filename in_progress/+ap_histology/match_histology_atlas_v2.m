function match_histology_atlas_v2(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Choose CCF atlas slices corresponding to histology slices

% Initialize guidata
gui_data = struct;
gui_data.curr_histology_slice = 1;

% Get GUI data and store GUI handles
histology_toolbar_guidata = guidata(histology_toolbar_gui);
histology_scroll_guidata = guidata(histology_toolbar_guidata.histology_scroll);

gui_data.histology_toolbar_gui = histology_toolbar_gui;
gui_data.histology_scroll_gui = histology_toolbar_guidata.histology_scroll;

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

% Create figure, set button functions
gui_position = histology_toolbar_guidata.histology_scroll.Position;
gui_fig = figure('WindowScrollWheelFcn',@scroll_atlas_slice, ...
    'KeyPressFcn',@keypress,'Toolbar','none','Menubar','none','color','w', ...
    'Units','normalized','Position',gui_position, ...
    'CloseRequestFcn',@close_gui);

% Set up 3D atlas axis
gui_data.atlas_ax = axes(gui_fig,'units','normalized','position',[0,0,1,1], ...
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
gui_data.atlas_title = title(gui_data.atlas_ax,sprintf('Slice %d: NOT SET',1));

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
gui_data.slice_points = nan(length(histology_scroll_guidata.data),3);

% Load and set pre-saved data if it exists
load(histology_toolbar_guidata.histology_processing_filename);
if isfield(AP_histology_processing,'histology_ccf')
    % Grab slice positions
    gui_data.slice_vector = AP_histology_processing.histology_ccf.slice_vector;
    gui_data.slice_points = AP_histology_processing.histology_ccf.slice_points;

    % Set camera angle
    curr_camdist = norm(camtarget(gui_data.atlas_ax) - campos(gui_data.atlas_ax));
    campos(gui_data.atlas_ax,camtarget - (gui_data.slice_vector*curr_camdist))
end

% Upload gui data
guidata(gui_fig,gui_data);

% Set the first slice in both GUIs
histology_scroll_guidata.curr_im = 1;
guidata(gui_data.histology_scroll_gui,histology_scroll_guidata);
histology_scroll_guidata.update([],[],gui_data.histology_scroll_gui);
update_histology_slice(gui_fig);

% Print controls
CreateStruct.Interpreter = 'tex';
CreateStruct.WindowStyle = 'non-modal';
msgbox( ...
    {'\fontsize{12}' ...
    '\bf Controls: \rm' ...
    'Left/right arrows: cycle histology slice', ...
    'Shift + arrows: change atlas rotation', ...
    'm : change atlas display mode (TV/TV with borders/AV overlay)', ...
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

             % Get histology scroll current image, increment 1
            histology_scroll_guidata = guidata(gui_data.histology_scroll_gui);
            new_slice = max(histology_scroll_guidata.curr_im - 1,1);

            gui_data.curr_histology_slice = new_slice;            
            guidata(gui_fig,gui_data);

            histology_scroll_guidata.curr_im = new_slice;
            guidata(gui_data.histology_scroll_gui,histology_scroll_guidata);
            histology_scroll_guidata.update([],[],gui_data.histology_scroll_gui);

            update_histology_slice(gui_fig);

        elseif shift_on
            set(gui_data.atlas_ax,'View',get(gui_data.atlas_ax,'View') + [1,0]);
            update_atlas_slice(gui_fig)
        end
    case 'rightarrow'
        if ~shift_on

            % Get histology scroll current image, increment 1
            histology_scroll_guidata = guidata(gui_data.histology_scroll_gui);
            new_slice = min(histology_scroll_guidata.curr_im + 1, ...
                length(histology_scroll_guidata.data));

            gui_data.curr_histology_slice = new_slice;            
            guidata(gui_fig,gui_data);

            histology_scroll_guidata.curr_im = new_slice;
            guidata(gui_data.histology_scroll_gui,histology_scroll_guidata);
            histology_scroll_guidata.update([],[],gui_data.histology_scroll_gui);

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
        atlas_slice_modes = {'TV','TV-AV','AV'};
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

    case 'c'
        disp('clear current save point');
        gui_data.slice_points(gui_data.curr_histology_slice,:) = NaN;
        guidata(gui_fig,gui_data);
        update_histology_slice(gui_fig);

    case 'i'
        %%%% WORKS - FINALIZE
        disp('testing interpolation');

        saved_slice_points = ~any(isnan(gui_data.slice_points),2);

        gui_data.slice_points = ...
            interp1(find(saved_slice_points), ...
            gui_data.slice_points(saved_slice_points,:), ...
            1:size(gui_data.slice_points,1),'linear','extrap');

        guidata(gui_fig,gui_data);
        update_histology_slice(gui_fig);

    case 'a'
        %%%% WORKS - FINALIZE
        disp('Quick aligning');

        % Set optimizer
        [optimizer, metric] = imregconfig('multimodal');
        optimizer.MaximumIterations = 200;
        optimizer.GrowthFactor = 1+1e-3;
        optimizer.InitialRadius = 1e-3;

        histology_scroll_guidata = guidata(gui_data.histology_scroll_gui);
        curr_histology_slice = max(histology_scroll_guidata.im_h.CData,[],3);

        % Grab AV slice (just switch mode there and back and get CData)
        curr_atlas_mode = gui_data.atlas_mode;
        gui_data.atlas_mode = 'AV';
        guidata(gui_fig,gui_data);
        update_atlas_slice(gui_fig);
        curr_atlas_slice = gui_data.atlas_slice_plot.CData;

        gui_data.atlas_mode = curr_atlas_mode;
        guidata(gui_fig,gui_data);
        update_atlas_slice(gui_fig);

        % Resize atlas outline to approximately match histology, affine-align
        resize_factor = min(size(curr_histology_slice)./size(curr_atlas_slice));
        curr_atlas_slice_resize = imresize(curr_atlas_slice,resize_factor,'nearest');

        % Do alignment on downsampled sillhouettes (faster and more accurate)
        downsample_factor = 10;

        tformEstimate_affine_resized = ...
            imregtform( ...
            imresize(curr_atlas_slice_resize,1/downsample_factor,'nearest'), ...
            imresize(curr_histology_slice,1/downsample_factor,'nearest'), ...
            'affine',optimizer,metric,'PyramidLevels',3);

        % Set final transform (scale to histology, downscale, affine, upscale)
        scale_match = eye(3).*[repmat(resize_factor,2,1);1];
        scale_align_down = eye(3).*[repmat(1/downsample_factor,2,1);1];
        scale_align_up = eye(3).*[repmat(downsample_factor,2,1);1];

        tformEstimate_affine = tformEstimate_affine_resized;
        tformEstimate_affine.T = scale_match*scale_align_down* ...
            tformEstimate_affine_resized.T*scale_align_up;

        curr_atlas_slice_warp = imwarp(curr_atlas_slice,tformEstimate_affine,'nearest', ...
            'Outputview',imref2d(size(curr_histology_slice)));
        curr_atlas_slice_warp(curr_atlas_slice_warp == 1) = 0;
       
        % Plot overlay and mask
        figure;
        ax_1 = subplot(1,2,1); axis image off;
        imagesc(ax_1,curr_histology_slice);
        colormap(ax_1,'gray');
        axis image off;
        ax_2 = subplot(1,2,2);
        im_h = imagesc(ax_2,curr_atlas_slice_warp);
        im_h.AlphaData = 0.2;
        colormap(ax_2,'hot');
        axis image off;
        ax_2.Color = 'none';
        ax_2.Position = ax_1.Position;
        linkaxes([ax_1,ax_2]);
        
        subplot(1,2,2);
        curr_atlas_slice_warp_mask = imdilate(boundarymask(curr_atlas_slice_warp),ones(3));
        curr_overlay = imoverlay(double(curr_histology_slice)./ ...
            double(max(curr_histology_slice,[],'all')), ...
            curr_atlas_slice_warp_mask,'r');
        imagesc(curr_overlay);
        axis image off;

end

end

function update_histology_slice(gui_fig)
% Draw histology slice (and move atlas if saved position)

% Get guidata
gui_data = guidata(gui_fig);

% If there's a saved atlas position, move atlas to there
if all(~isnan(gui_data.slice_points(gui_data.curr_histology_slice,:)))
    gui_data.atlas_slice_point = ...
        gui_data.slice_points(gui_data.curr_histology_slice,:);

    gui_data.atlas_title.String = sprintf('Slice %d: Saved',gui_data.curr_histology_slice);
    gui_data.atlas_title.Color = [0,0.7,0];

    guidata(gui_fig,gui_data);
    update_atlas_slice(gui_fig);
else
    gui_data.atlas_title.String = sprintf('Slice %d: NOT SAVED',gui_data.curr_histology_slice);
    gui_data.atlas_title.Color = [0.7,0,0];
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
        colormap(gray);
        clim(gui_data.atlas_ax,[0,516]);
    case 'TV-AV'
        av_boundaries = round(conv2(av_slice,ones(2)./4,'same')) ~= av_slice;
        atlas_slice = imoverlay(mat2gray(tv_slice,[0,516]),av_boundaries,'r');
        clim(gui_data.atlas_ax,[0,1]);
    case 'AV'
        atlas_slice = av_slice;
        colormap(gui_data.ccf_cmap)
        clim(gui_data.atlas_ax,[1,size(gui_data.ccf_cmap,1)])
end
set(gui_data.atlas_slice_plot,'XData',plane_ap,'YData',plane_ml,'ZData',plane_dv,'CData',atlas_slice);

% Upload gui_data
guidata(gui_fig, gui_data);

end

function [tv_slice,av_slice,plane_ap,plane_ml,plane_dv] = grab_atlas_slice(gui_data,slice_px_space)
% Grab anatomical and labelled atlas within slice

[atlas_slice,atlas_coords] = ap_histology.grab_atlas_slice(gui_data.av,gui_data.tv,cam_vector,gui_data.atlas_slice_point,1);

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
% (not used anymore)
plane_offset_mm = plane_offset/100; % CCF = 10um voxels
% set(gui_data.atlas_title,'string', ...
%     sprintf('Slice position: %.2f mm',plane_offset_mm));

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
        % Load processing and save CCF slice data
        histology_toolbar_guidata = guidata(gui_data.histology_toolbar_gui);
        load(histology_toolbar_guidata.histology_processing_filename);

        AP_histology_processing.histology_ccf.slice_vector = gui_data.slice_vector;
        AP_histology_processing.histology_ccf.slice_points = gui_data.slice_points;

        save(histology_toolbar_guidata.histology_processing_filename,'AP_histology_processing');

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











