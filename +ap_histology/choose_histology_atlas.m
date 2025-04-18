function choose_histology_atlas(~,~,histology_gui)
% Part of AP_histology toolbox
%
% Choose CCF atlas slices corresponding to histology slices

% Initialize guidata
gui_data = struct;
gui_data.curr_slice = 1;

% Get GUI data and store GUI handles
histology_guidata = guidata(histology_gui);
gui_data.histology_gui = histology_gui;

% Disable image scrolling in histology gui
histology_guidata.scrollbar_image.Enable = 'off';

% Load atlas
[gui_data.av,gui_data.tv,gui_data.st] = ap_histology.load_ccf;

% Create figure, set button functions
gui_position = histology_gui.Position;
gui_fig = figure('Name','Atlas slice chooser', ...
    'WindowScrollWheelFcn',@scroll_atlas_slice, ...
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
gui_data.ccf_cmap = cell2mat(cellfun(@(x) ...
    hex2dec(mat2cell(x,1,[2,2,2]))'./255,gui_data.st.color_hex_triplet,'uni',false));

% Set mode for atlas view (can be either TV, AV, or TV-AV)
gui_data.atlas_mode = 'TV';

% Create slice object and first slice point
gui_data.atlas_slice_plot = surface(gui_data.atlas_ax,'EdgeColor','none'); % Slice on 3D atlas
gui_data.atlas_slice_point = camtarget;

% Set up atlas parameters to save for histology
gui_data.slice_vector = nan(1,3);
gui_data.slice_points = nan(length(histology_guidata.data),3);

% Load and set processing
load(histology_guidata.histology_processing_filename);
% (image order)
if isfield(AP_histology_processing,'image_order')
    gui_data.image_order = AP_histology_processing.image_order;
else
    gui_data.image_order = (1:length(histology_guidata.data))';
end
% (previously saved slices)
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
histology_guidata.curr_slice = 1;
guidata(gui_data.histology_gui,histology_guidata);
histology_guidata.update([],[],gui_data.histology_gui);

update_histology_slice(gui_fig);
update_atlas_slice(gui_fig);

% Buttons: histology-related
button_strings = {'Previous histology slice','Next histology slice','Set slice','Interpolate slices','Atlas mode'};
button_functions = {@previous_slice,@next_slice,@set_slice,@interpolate_slice,@atlas_mode};

button_height = 0.1;
button_width = 1/length(button_strings);
button_x = 0:button_width:1-button_width;

for curr_button = 1:length(button_strings)
    uicontrol(gui_fig,'style','pushbutton','units','normalized', ...
        'Position',[button_x(curr_button),0,button_width,button_height], ...
        'String',button_strings{curr_button}, ...
        'Callback',{button_functions{curr_button},gui_fig});
end

% Buttons: atlas tilt angle
button_strings = {'Tilt atlas left','Tilt atlas right','Tilt atlas up','Tilt atlas down'};

button_height = 0.1;
button_width = 1/length(button_strings);
button_x = 0:button_width:1-button_width;
button_y = 1-button_height;
for curr_button = 1:length(button_strings)
    gui_data.tilt_button(curr_button) = ...
        uicontrol(gui_fig,'style','pushbutton','units','normalized', ...
        'Position',[button_x(curr_button),button_y,button_width,button_height], ...
        'String',button_strings{curr_button}, ...
        'Callback',{@tilt_atlas,gui_fig,curr_button});
end

end 

function keypress(gui_fig,eventdata)
% (this was all moved to buttons - only keeping test functions)

% Get guidata
gui_data = guidata(gui_fig);

shift_on = any(strcmp(eventdata.Modifier,'shift'));

switch eventdata.Key
    case 'c'
        % Clear set
        if shift_on
            gui_data.slice_points(:) = NaN;
            disp('cleared all save points');
        else
            curr_slice = find(gui_data.image_order == gui_data.curr_slice);
            gui_data.slice_points(curr_slice,:) = NaN;
            disp('cleared current save point');
        end
        guidata(gui_fig,gui_data);
        update_histology_slice(gui_fig);

    case 'a'
        % Do quick alignment to check histology vs atlas
        disp('Quick aligning');

        % Set optimizer
        [optimizer, metric] = imregconfig('multimodal');
        optimizer.MaximumIterations = 200;
        optimizer.GrowthFactor = 1+1e-3;
        optimizer.InitialRadius = 1e-3;

        histology_guidata = guidata(gui_data.histology_gui);
        curr_histology_slice = max(histology_guidata.im_h.CData,[],3);

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
curr_slice = gui_data.image_order(gui_data.curr_slice);
if all(~isnan(gui_data.slice_points(curr_slice,:)))
    gui_data.atlas_slice_point = gui_data.slice_points(curr_slice,:);

    gui_data.atlas_title.String = sprintf('Histology slice %d: SET',gui_data.curr_slice);
    gui_data.atlas_title.Color = [0,0.7,0];

    guidata(gui_fig,gui_data);
    update_atlas_slice(gui_fig);
else
    gui_data.atlas_title.String = sprintf('Histology slice %d: NOT SET',gui_data.curr_slice);
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
atlas_spacing = 3;
cam_vector = get_camera_vector(gui_data);
[atlas_slice,atlas_coords] = ...
    ap_histology.grab_atlas_slice(gui_data.av,gui_data.tv, ...
    cam_vector,gui_data.atlas_slice_point,atlas_spacing);

% Update the slice display (depending on display mode)
switch gui_data.atlas_mode
    case 'TV'
        atlas_slice_display = atlas_slice.tv;
        colormap(gray);
        clim(gui_data.atlas_ax,[0,516]);
    case 'TV-AV'
        av_boundaries = boundarymask(max(0,atlas_slice.av));
        atlas_slice_display = imoverlay(mat2gray(atlas_slice.tv,[0,516]),av_boundaries,'r');
        clim(gui_data.atlas_ax,[0,1]);
    case 'AV'
        atlas_slice_display = atlas_slice.av;
        colormap(gui_data.ccf_cmap)
        clim(gui_data.atlas_ax,[1,size(gui_data.ccf_cmap,1)])
end
set(gui_data.atlas_slice_plot, ...
    'XData',atlas_coords.ap, ...
    'YData',atlas_coords.ml, ...
    'ZData',atlas_coords.dv, ...
    'CData',atlas_slice_display);

% Upload gui_data
guidata(gui_fig, gui_data);

end


function previous_slice(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

% Change slice based on histology
histology_guidata = guidata(gui_data.histology_gui);
new_slice = max(histology_guidata.curr_slice - 1,1);

gui_data.curr_slice = new_slice;
guidata(gui_fig,gui_data);

histology_guidata.curr_slice = new_slice;
guidata(gui_data.histology_gui,histology_guidata);
histology_guidata.update([],[],gui_data.histology_gui);

update_histology_slice(gui_fig);

end

function next_slice(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

% Change slice based on histology
histology_guidata = guidata(gui_data.histology_gui);
new_slice = min(histology_guidata.curr_slice + 1, ...
    length(histology_guidata.data));

gui_data.curr_slice = new_slice;
guidata(gui_fig,gui_data);

histology_guidata.curr_slice = new_slice;
guidata(gui_data.histology_gui,histology_guidata);
histology_guidata.update([],[],gui_data.histology_gui);

update_histology_slice(gui_fig);

end

function set_slice(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

curr_slice = gui_data.image_order(gui_data.curr_slice);

gui_data.slice_vector = get_camera_vector(gui_data);
gui_data.slice_points(curr_slice,:) = gui_data.atlas_slice_point;
guidata(gui_fig,gui_data);

update_histology_slice(gui_fig);

end

function interpolate_slice(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

% Interpolate un-set slices from set slices
[~,image_order_idx] = ismember((1:size(gui_data.slice_points,1))',gui_data.image_order);
saved_slice_points = ~any(isnan(gui_data.slice_points),2);

gui_data.slice_points(gui_data.image_order,:) = ...
    interp1(image_order_idx(saved_slice_points), ...
    gui_data.slice_points(saved_slice_points,:), ...
    1:size(gui_data.slice_points,1),'linear','extrap');

guidata(gui_fig,gui_data);
update_histology_slice(gui_fig);

end

function atlas_mode(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

atlas_slice_modes = {'TV','TV-AV','AV'};
curr_atlas_mode_idx = strcmp(gui_data.atlas_mode,atlas_slice_modes);
gui_data.atlas_mode = atlas_slice_modes{circshift(curr_atlas_mode_idx,[0,1])};
guidata(gui_fig,gui_data);
update_atlas_slice(gui_fig);

end

function tilt_atlas(currentObject, eventdata, gui_fig, tilt_direction)

% Get guidata
gui_data = guidata(gui_fig);

% Remove all set slice points if tilt changed (check with user if any set)
if any(~isnan(gui_data.slice_points),'all')
    user_confirm = questdlg('Change atlas tilt and clear set slices?','Confirm','Yes','No','No');
    if strcmpi(user_confirm,'no')
        return
    end
    gui_data.slice_points(:) = NaN;
    guidata(gui_fig,gui_data);
end

switch tilt_direction
    case 1
        tilt_change = [-1,0];
    case 2
        tilt_change = [1,0];
    case 3
        tilt_change = [0,1];
    case 4
        tilt_change = [0,-1];
end

set(gui_data.atlas_ax,'View',get(gui_data.atlas_ax,'View') + tilt_change);
update_atlas_slice(gui_fig)

end


function close_gui(gui_fig,~)

% Get guidata
gui_data = guidata(gui_fig);
histology_guidata = guidata(gui_data.histology_gui);

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
user_confirm = questdlg('\fontsize{14} Save atlas slices?','Confirm exit',opts);
switch user_confirm
    case 'Yes'     
        % Load processing and save CCF slice data
        load(histology_guidata.histology_processing_filename);

        AP_histology_processing.histology_ccf.slice_vector = gui_data.slice_vector;
        AP_histology_processing.histology_ccf.slice_points = gui_data.slice_points;

        save(histology_guidata.histology_processing_filename,'AP_histology_processing');

    case 'No'
        % Close without saving

    case 'Cancel'
        % Do nothing
        return

end 

% Close figure
delete(gui_fig);

% Re-enable image scrolling in histology gui
histology_guidata.scrollbar_image.Enable = 'on';

end
