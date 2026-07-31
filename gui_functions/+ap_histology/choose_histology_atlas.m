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

% ~~ Set up figure
gui_position = histology_gui.Position;
gui_fig = uifigure('Name','Atlas slice chooser', ...
    'WindowScrollWheelFcn',@scroll_atlas_slice, ...
    'WindowKeyPressFcn',@keypress,'WindowKeyReleaseFcn',@keyrelease, ...
    'Units','normalized','Position',gui_position, ...
    'CloseRequestFcn',@close_gui,'HandleVisibility','on');

gui_grid = uigridlayout(gui_fig,[4,1], ...
    'RowHeight',{'1x','5x','1x','1x'},'BackgroundColor','w');

tilt_panel = uipanel(gui_grid,'Title','Tilt atlas');
gui_data.atlas_ax = uiaxes(gui_grid,'Interactions',[]);
slice_panel = uipanel(gui_grid,'Title','Choose histology slice');
actions_panel = uipanel(gui_grid,'Title','Actions');

% ~~ Add buttons

% Add tilt buttons
tilt_panel_grid = uigridlayout(tilt_panel,[1,4]);
button_strings = {'Left','Right','Up','Down'};
for curr_button = 1:length(button_strings)
    gui_data.tilt_button(curr_button) = ...
        uibutton(tilt_panel_grid, ...
        'Text',button_strings{curr_button}, ...
        'ButtonPushedFcn',{@tilt_atlas,gui_fig,curr_button});
end

% Add histology slice buttons
button_strings = {'<-- Histology slice','Histology slice -->'};
button_functions = {@previous_slice,@next_slice};
slice_panel_grid = uigridlayout(slice_panel,[2,length(button_strings)], ...
    'RowHeight',{'0.6x','0.8x'});

gui_data.slice_label = ...
    uilabel(slice_panel_grid,'Text','HISTOLOGY SLICE STATUS', ...
    'FontSize',14,'FontWeight','bold','HorizontalAlignment','center', ...
    'Layout',matlab.ui.layout.GridLayoutOptions( ...
    'Row',1,'Column',[1,length(slice_panel_grid.ColumnWidth)]));
for curr_button = 1:length(button_strings)
    uibutton(slice_panel_grid, ...
        'Text',button_strings{curr_button}, ...
        'ButtonPushedFcn',{button_functions{curr_button},gui_fig});
end

% Add action buttons
button_strings = {'Set','Clear','Clear all','Interpolate','Atlas mode','Quick Align','Save'};
button_functions = {@set_slice,@clear_slice,@clear_all_slices,@interpolate_slice,@atlas_mode,@quick_align,@save_slices};
actions_panel_grid = uigridlayout(actions_panel,[1,length(button_strings)]);
for curr_button = 1:length(button_strings)
    uibutton(actions_panel_grid, ...
        'Text',button_strings{curr_button}, ...
        'ButtonPushedFcn',{button_functions{curr_button},gui_fig});
end
% (green save button)
actions_panel_grid.Children(end).BackgroundColor = [0.6,1,0.6];

% ~~ Set up atlas viewer
set(gui_data.atlas_ax, ...
    'ZDir','reverse','color','k', ...
    'XTick',[1,size(gui_data.av,1)],'XTickLabel',{'Front','Back'}, ...
    'YTick',[1,size(gui_data.av,3)],'YTickLabel',{'Left','Right'}, ...
    'ZTick',[1,size(gui_data.av,2)],'ZTickLabel',{'Top','Bottom'});
axis(gui_data.atlas_ax,'vis3d','equal','manual')
view(gui_data.atlas_ax,[90,0]);
title(gui_data.atlas_ax,'Scroll (+shift): move slice')

[ap_max,dv_max,ml_max] = size(gui_data.tv);
xlim([1,ap_max]); ylim([1,ml_max]); zlim([1,dv_max]);
colormap(gui_data.atlas_ax,'gray');
clim(gui_data.atlas_ax,[0,400]);

% Create CCF colormap
gui_data.ccf_cmap = hex2rgb("#"+string(gui_data.st.color_hex_triplet));

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

end 

function keypress(gui_fig,eventdata)
% Get guidata
gui_data = guidata(gui_fig);

% (set flag for shift on for atlas quick-scroll)
shift_on = any(strcmp(eventdata.Modifier,'shift'));
gui_data.shift_pressed = shift_on;
guidata(gui_fig, gui_data);
end

function keyrelease(gui_fig,eventdata)
% Get guidata
gui_data = guidata(gui_fig);

% (flag for shift release)
shift_on = any(strcmp(eventdata.Modifier,'shift'));
gui_data.shift_pressed = shift_on;
guidata(gui_fig, gui_data);
end

function update_histology_slice(gui_fig)
% Draw histology slice (and move atlas if saved position)

% Get guidata
gui_data = guidata(gui_fig);

% If there's a saved atlas position, move atlas to there
curr_slice = gui_data.image_order(gui_data.curr_slice);
if all(~isnan(gui_data.slice_points(curr_slice,:)))
    gui_data.atlas_slice_point = gui_data.slice_points(curr_slice,:);

    gui_data.slice_label.Text = sprintf('Histology slice %d: SET',gui_data.curr_slice);
    gui_data.slice_label.FontColor = [0,0.7,0];

    guidata(gui_fig,gui_data);
    update_atlas_slice(gui_fig);
else
    gui_data.slice_label.Text = sprintf('Histology slice %d: NOT SET',gui_data.curr_slice);
    gui_data.slice_label.FontColor = [0.7,0,0];
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
% (one slice per scroll, 20 slice per scroll+shift)
if ~isfield(gui_data,'shift_pressed')
    gui_data.shift_pressed = false;
end
n_slices_move = max(1,gui_data.shift_pressed*20)*eventdata.VerticalScrollCount;

gui_data.atlas_slice_point = gui_data.atlas_slice_point + ...
    n_slices_move*cam_vector;

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
histology_guidata = guidata(gui_data.histology_gui);

% Change slice based on histology
slice_idx = 1:length(histology_guidata.data);
new_slice = slice_idx(circshift(slice_idx == histology_guidata.curr_slice,-1));

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
histology_guidata = guidata(gui_data.histology_gui);

% Change slice based on histology
slice_idx = 1:length(histology_guidata.data);
new_slice = slice_idx(circshift(slice_idx == histology_guidata.curr_slice,1));
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
    user_confirm = uiconfirm(gui_fig, ...
        'Change atlas tilt and clear set slices?','Confirm', ...
        'Icon','warning');
    if ~strcmpi(user_confirm,'Yes')
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

function quick_align(currentObject, eventdata, gui_fig)

% Do quick alignment to check histology vs atlas
gui_data = guidata(gui_fig);

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

% Do alignment on downsampled images (faster and more accurate)
downsample_factor = round(max(size(curr_histology_slice))/300);

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
figure('color','w');
h = tiledlayout(1,2,'TileSpacing','none');

histology_ax1 = nexttile(h);
imagesc(histology_ax1,curr_histology_slice);
colormap(histology_ax1,'gray'); axis image off;

atlas_ax = nexttile(h); atlas_ax.Layout.Tile = 1;
imagesc(atlas_ax,curr_atlas_slice_warp,'AlphaData',0.2);
linkaxes([histology_ax1,atlas_ax],'xy');

colormap(atlas_ax,gui_data.ccf_cmap);
clim(atlas_ax,[1,size(gui_data.ccf_cmap,1)]);
axis image off;

nexttile(h);
curr_atlas_slice_warp_mask = imdilate(boundarymask(curr_atlas_slice_warp),ones(3));
curr_overlay = imoverlay(double(curr_histology_slice)./ ...
    double(max(curr_histology_slice,[],'all')), ...
    curr_atlas_slice_warp_mask,'r');
imagesc(curr_overlay);
axis image off;

end

function clear_slice(currentObject, eventdata, gui_fig)

gui_data = guidata(gui_fig);
curr_slice = find(gui_data.image_order == gui_data.curr_slice);
gui_data.slice_points(curr_slice,:) = NaN;
disp('cleared current save point');
guidata(gui_fig,gui_data);
update_histology_slice(gui_fig);

end

function clear_all_slices(currentObject, eventdata, gui_fig)

% Get user confirmation
user_confirm = uiconfirm(gui_fig, ...
    'Clear all saved slices?','Confirm clear', ...
    'Icon','question');
if ~strcmpi(user_confirm,'ok')
    return
end

gui_data = guidata(gui_fig);
gui_data.slice_points(:) = NaN;
guidata(gui_fig,gui_data);
update_histology_slice(gui_fig);

end

function save_slices(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);
histology_guidata = guidata(gui_data.histology_gui);

% Check that a CCF slice point exists for each histology slice
if any(isnan(gui_data.slice_points(:)))
    uialert(gui_fig, 'Not all slices set: must be complete to save','Incomplete slice set');
    return
end

% Get user confirmation
user_confirm = uiconfirm(gui_fig, ...
    'Save and auto-align atlas slices?','Confirm save', ...
    'Icon','question');
if ~strcmpi(user_confirm,'ok')
    return
end

progress_box = uiprogressdlg(gui_fig,'Message','','indeterminate','on');

% Save slices
progress_box.Message = 'Saving slices...';
load(histology_guidata.histology_processing_filename);
AP_histology_processing.histology_ccf.slice_vector = gui_data.slice_vector;
AP_histology_processing.histology_ccf.slice_points = gui_data.slice_points;
save(histology_guidata.histology_processing_filename,'AP_histology_processing');

% Auto-align slices
progress_box.Message = 'Auto-aligning slices...';
ap_histology.align_auto_histology_atlas([],[],gui_data.histology_gui,false);

% Update histology GUI and load saved histology slices
histology_guidata.update([],[],gui_data.histology_gui);

end

function close_gui(gui_fig, eventdata)

% Get guidata
gui_data = guidata(gui_fig);
histology_guidata = guidata(gui_data.histology_gui);

% Re-enable image scrolling in histology gui
histology_guidata.scrollbar_image.Enable = 'on';
drawnow;

% Close figure
delete(gui_fig);

end
