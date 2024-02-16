function reorder_slices(~,~,histology_toolbar_gui)

% Get images (from path in GUI)
histology_toolbar_guidata = guidata(histology_toolbar_gui);

slice_dir = dir(fullfile(histology_toolbar_guidata.save_path,'*.tif'));
slice_fn = natsortfiles(cellfun(@(path,fn) fullfile(path,fn), ...
    {slice_dir.folder},{slice_dir.name},'uni',false));

slice_im = cell(length(slice_fn),1);
for curr_slice = 1:length(slice_fn)
   slice_im{curr_slice} = imread(slice_fn{curr_slice});  
end

% Plot all (downsampled) images
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
tile_h = tiledlayout('flow','TileSpacing','none');
image_h = gobjects(length(slice_im),1);
for curr_slice = 1:length(slice_fn)
    nexttile; 
    image_h(curr_slice) = imagesc(imresize(slice_im{curr_slice},1/10,'nearest'));
    axis image off;
end

% Set click function
[image_h.ButtonDownFcn] = deal({@click_slice,gui_fig});

% Title with directions
title(tile_h,'Click to assign/un-assign slice order','FontSize',12);

% Package image handles and slice number index in figure
gui_data = struct;

gui_data.slice_fn = slice_fn;

gui_data.image_h = image_h;
gui_data.slice_idx = nan(length(slice_im),1);
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

% Make re-ordered filenames (with '_reorder to avoid overwriting)
reordered_source_filenames = gui_data.slice_fn(gui_data.slice_idx);
reorder_target_filenames = strrep(gui_data.slice_fn,'.tif','_reorder.tif');

% Rename files (with '_reorder')
for curr_im = 1:length(gui_data.slice_fn)
    movefile(reordered_source_filenames{curr_im},reorder_target_filenames{curr_im});
end

% Rename files (with original filenames)
for curr_im = 1:length(gui_data.slice_fn)
    movefile(reorder_target_filenames{curr_im},gui_data.slice_fn{curr_im});
end

disp('Saved re-ordered slices');

end





