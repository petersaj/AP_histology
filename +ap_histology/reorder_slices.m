function reorder_slices(~,~,histology_gui)

% User confirm
user_confirm = questdlg('Set new slice order?','Confirm','Yes','No','No');
if strcmpi(user_confirm,'no')
    return
end

% Get gui data
histology_guidata = guidata(histology_gui);

% Plot all images (downsampled)
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

% Plot images (grab BW from histology scroller)
tile_h = tiledlayout('flow','TileSpacing','none');
image_h = gobjects(length(histology_guidata.data),1);

downsample_factor = 1/10;
for curr_slice = 1:length(histology_guidata.data)
    nexttile; 
    curr_slice_bw = ...
        max(min(histology_guidata.data{curr_slice} - permute(histology_guidata.clim(:,1),[2,3,1]), ...
        permute(diff(histology_guidata.clim,[],2),[2,3,1])),[],3);
    image_h(curr_slice) = imagesc(imresize(curr_slice_bw,downsample_factor));
    axis image off;
    colormap(gray);
    drawnow;
end

% Set click function
[image_h.ButtonDownFcn] = deal({@click_slice,gui_fig});

% Title with directions
title(tile_h,'Click to assign/un-assign slice order','FontSize',12);

% Package image handles and slice number index in figure
gui_data = struct;

gui_data.histology_gui = histology_gui;
gui_data.image_h = image_h;
gui_data.slice_idx = nan(length(histology_guidata.data),1);
guidata(gui_fig,gui_data)

end

function click_slice(obj,eventdata,gui_fig)

% Get gui data
gui_data = guidata(gui_fig);

% Get current index of slice
curr_ax = find(gui_data.image_h == obj);

if ~any(gui_data.slice_idx == curr_ax)
    % If slice isn't assigned, assigned next number

    % Get number to assign
    curr_idx_assign = find(isnan(gui_data.slice_idx),1);

    % Assign number to currently ordered slice
    gui_data.slice_idx(curr_idx_assign) = curr_ax;

    % Write number on axis
    text(get(obj,'parent'),20,20,num2str(curr_idx_assign),'FontSize',20,'Color','w')

else
    % If slice is already assigned, remove assignment
    gui_data.slice_idx(gui_data.slice_idx == curr_ax) = NaN;

    % Clear number from axis 
    delete(findobj(get(obj,'parent'),'type','text'));
end

% Upload gui data
guidata(gui_fig,gui_data)

% If all slices assigned, close and save
if ~any(isnan(gui_data.slice_idx))
    close(gui_fig);
    save_reordered_slices(gui_data);
end

end

function save_reordered_slices(gui_data)

% Get histology toolbar data
histology_guidata = guidata(gui_data.histology_gui);

% Load processing and save re-ordering
load(histology_guidata.histology_processing_filename);

AP_histology_processing.image_order = gui_data.slice_idx;

save(histology_guidata.histology_processing_filename,'AP_histology_processing');

end





