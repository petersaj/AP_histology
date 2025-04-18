function AP_histology(image_path,channel_colors)
% AP_histology(images,channel_colors)
%
% GUI for viewing and processing histology

%
% TO DO: 
% if image path set, open images
% if colors set, use colors


%% Create gui data structure

gui_data = struct;

%% Create GUI

% Create figure for scrolling and ROIs
fig_position = [0.025,0.15,0.3,0.7];
gui_fig = figure('Color',[0.5,0.5,0.5],'Name','AP histology', ...
    'Units','normalized','position',fig_position);
set(gui_fig,'WindowScrollWheelFcn',{@scrollbar_image_MouseWheel, gui_fig});

% Make figure toolbar available 
% (with only zoom and pan - must be a better way to do this)
set(gui_fig,'MenuBar','none','ToolBar','figure');

set(groot,'ShowHiddenHandles','on');
addToolbarExplorationButtons(gui_fig)
toolbar_h = findobj(gui_fig.Children,'Type','uitoolbar');
toolbar_zoomin_h = findobj(toolbar_h.Children,'Tag','Exploration.ZoomIn');
toolbar_zoomout_h = findobj(toolbar_h.Children,'Tag','Exploration.ZoomOut');
toolbar_pan_h = findobj(toolbar_h.Children,'Tag','Exploration.Pan');
delete(setdiff(toolbar_h.Children,[toolbar_zoomin_h,toolbar_zoomout_h,toolbar_pan_h]));
set(groot,'ShowHiddenHandles','off');

%%%% Menus

% Image menu
gui_data.menu.images = uimenu(gui_fig,'Text','Images');
uimenu(gui_data.menu.images,'Text','Load images','MenuSelectedFcn', ...
    {@load_images,gui_fig});
uimenu(gui_data.menu.images,'Text','Set channel colors','MenuSelectedFcn', ...
    {@channel_colorpicker,gui_fig});

% Preprocessing menu
gui_data.menu.preprocess = uimenu(gui_fig,'Text','Preprocessing');
uimenu(gui_data.menu.preprocess,'Text','Re-order slices','MenuSelectedFcn', ...
    {@ap_histology.reorder_slices,gui_fig});
uimenu(gui_data.menu.preprocess,'Text','Rotate & center slices','MenuSelectedFcn', ...
    {@ap_histology.rotate_center_slices,gui_fig});
uimenu(gui_data.menu.preprocess,'Text','Flip slices','MenuSelectedFcn', ...
    {@ap_histology.flip_slices,gui_fig});

% Atlas menu
gui_data.menu.atlas = uimenu(gui_fig,'Text','Atlas');
uimenu(gui_data.menu.atlas,'Text','Load histology atlas slices','MenuSelectedFcn', ...
    {@load_aligned_atlas,gui_fig});
uimenu(gui_data.menu.atlas,'Text','Choose histology atlas slices','MenuSelectedFcn', ...
    {@ap_histology.choose_histology_atlas,gui_fig});

gui_data.menu.atlas_align = uimenu(gui_data.menu.atlas,'Text','Align','Enable','off');
uimenu(gui_data.menu.atlas_align,'Text','Automatic','MenuSelectedFcn', ...
    {@ap_histology.align_auto_histology_atlas,gui_fig});
uimenu(gui_data.menu.atlas_align,'Text','Manual','MenuSelectedFcn', ...
    {@ap_histology.align_manual_histology_atlas_v2,gui_fig});

% Annotation menu
gui_data.menu.annotation = uimenu(gui_fig,'Text','Annotation');
uimenu(gui_data.menu.annotation,'Text','Probes','MenuSelectedFcn', ...
    {@ap_histology.annotate_probes,gui_fig});

% View menu
gui_data.menu.view = uimenu(gui_fig,'Text','View');
uimenu(gui_data.menu.view,'Text','Aligned atlas','Checked','off', ...
    'MenuSelectedFcn',{@menu_check,gui_fig},'Enable','off');
uimenu(gui_data.menu.view,'Text','Annotations','Checked','on', ...
    'MenuSelectedFcn',{@menu_check,gui_fig},'Enable','on');

%%%% 

% Set up scrollbars
scrollbar_height = 0.02;
scrollbar_label_width = 0.1;

% (image scrollbar)
ypos = [scrollbar_label_width, 0*scrollbar_height, 1-scrollbar_label_width, scrollbar_height];
gui_data.scrollbar_image = uicontrol('style','slider','units','normalized','position',ypos);
set(gui_data.scrollbar_image,'Callback',{@scrollbar_image_listener, gui_fig});
uicontrol('style','text','units','normalized', ...
    'position',[0,ypos(2),scrollbar_label_width,ypos(4)], ...
    'String','Image')

% (channel scrollbar)
ypos = [scrollbar_label_width, 1*scrollbar_height, 1-scrollbar_label_width, scrollbar_height];
gui_data.scrollbar_channel = uicontrol('style','slider','units','normalized','position',ypos);
gui_data.scrollbar_channel.BackgroundColor = 'g';
set(gui_data.scrollbar_channel,'Callback',{@scrollbar_channel_listener, gui_fig});
uicontrol('style','text','units','normalized', ...
    'position',[0,ypos(2),scrollbar_label_width,ypos(4)], ...
    'String','Channel')

% (white scrollbar)
ypos = [scrollbar_label_width, 2*scrollbar_height, 1-scrollbar_label_width, scrollbar_height];
gui_data.scrollbar_white = uicontrol('style','slider','units','normalized','position',ypos);
gui_data.scrollbar_white.BackgroundColor = 'w';
set(gui_data.scrollbar_white,'Callback',{@scrollbar_white_listener, gui_fig});
uicontrol('style','text','units','normalized', ...
    'position',[0,ypos(2),scrollbar_label_width,ypos(4)], ...
    'String','Color max')

% (black scrollbar)
ypos = [scrollbar_label_width, 3*scrollbar_height, 1-scrollbar_label_width, scrollbar_height];
gui_data.scrollbar_black = uicontrol('style','slider','units','normalized','position',ypos);
gui_data.scrollbar_black.BackgroundColor = 'k';
set(gui_data.scrollbar_black,'Callback',{@scrollbar_black_listener, gui_fig});
uicontrol('style','text','units','normalized', ...
    'position',[0,ypos(2),scrollbar_label_width,ypos(4)], ...
    'String','Color min')

% Draw image, set hover function (for CCF)
im_ax = axes('Units','normalized','Position',[0,4*scrollbar_height,1,1-4*scrollbar_height]);
gui_data.im_h = imagesc(im_ax,NaN);
axis image off;
gui_fig.WindowButtonMotionFcn = {@hover_label,gui_fig};

% Create text object
gui_data.im_text = text( ...
    interp1([0,1],gui_data.im_h.Parent.XLim,0.05), ...
    interp1([0,1],gui_data.im_h.Parent.YLim,0.05), ...
    '','color','w','BackgroundColor','k','FontSize',14);

% Save update function handle for external calling
gui_data.update = @update_image;

% Set default gui data for restoring on load
gui_data.default_gui_data = gui_data;

% Update gui data
guidata(gui_fig,gui_data);

end

function load_images(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

% Restore default guidata and turn off all views
default_gui_data = gui_data.default_gui_data;
gui_data = gui_data.default_gui_data;
gui_data.default_gui_data = default_gui_data;
[gui_data.menu.view.Children.Checked] = deal(false);

% Pick image path
gui_data.image_path = uigetdir([],'Select path with raw images');
if gui_data.image_path == 0
    return
end

% Set save filename, create file if it doesn't exist
gui_data.histology_processing_filename = fullfile(gui_data.image_path,'AP_histology_processing.mat');

if ~exist(gui_data.histology_processing_filename,'file')
    AP_histology_processing = struct;
    save(gui_data.histology_processing_filename,'AP_histology_processing');
end

% Load images
image_dir = dir(fullfile(gui_data.image_path,'*.tif'));
image_filenames = cellfun(@(path,name) fullfile(path,name), ...
    {image_dir.folder},{image_dir.name},'uni',false);
[~,sort_idx] = ap_histology.natsortfiles(image_filenames);

images = cell(size(image_dir));
for curr_im = 1:length(sort_idx)
    curr_text = sprintf('Loading images (%d/%d)',curr_im,length(sort_idx));
    set(gui_data.im_text, 'Position', ...
    [interp1([0,1],gui_data.im_h.Parent.XLim,0.05), ...
    interp1([0,1],gui_data.im_h.Parent.YLim,0.05),0], ...
    'String',curr_text); 
    drawnow;

    images{curr_im} = tiffreadVolume( ...
        image_filenames{sort_idx(curr_im)});
end
gui_data.im_text.String = '';

% Get number of channels, color limits, colors
n_channels = size(images{1},3);
clim_min = squeeze(min(cell2mat(cellfun(@(x) min(x,[],[1,2]),images,'uni',false)),[],1));
clim_max = squeeze(max(cell2mat(cellfun(@(x) max(x,[],[1,2]),images,'uni',false)),[],1));
gui_data.clim = [clim_min,clim_max];

if ~exist('channel_colors','var') || isempty(channel_colors)
    % Default channel colors
    channel_colors = ...
        [1,0,0;0,1,0;0,0,1; ... % RGB
        0,1,1;1,0,1;1,1,0];     % CYM
    if n_channels > 6
        channel_colors = hsv(n_channels);
    end
end
gui_data.colors = channel_colors(1:n_channels,:);

% Set scrollbar properties
set(gui_data.scrollbar_image, ...
    'min',1,'max',length(images),'value',1, ...
    'sliderstep',repmat(1/(length(images)-1),1,2));

set(gui_data.scrollbar_channel, ...
    'min',1,'max',n_channels,'value',1, ...
    'sliderstep',repmat(1/(n_channels-1),1,2), ...
    'backgroundcolor',gui_data.colors(1,:));

set(gui_data.scrollbar_white, ...
    'min',0,'max',max(clim_max),'value',max(gui_data.clim(:,2)), ...
    'sliderstep',repmat(1/double(max(gui_data.clim(:,2))),1,2));

set(gui_data.scrollbar_black, ...
    'min',0,'max',max(clim_max),'value',0, ...
    'sliderstep',repmat(1/double(max(gui_data.clim(:,2))),1,2));

% Package data
gui_data.data = images;
gui_data.curr_slice = 1;
gui_data.curr_im_idx = 1;

% Update guidata
guidata(gui_fig,gui_data);

% Update first image
update_image([], [], gui_fig);

end

function channel_colorpicker(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);
n_channels = size(gui_data.colors,1);

% Loop through channels, select colors
for curr_chan = 1:n_channels
    gui_data.colors(curr_chan,:) = ...
        uisetcolor(gui_data.colors(curr_chan,:),sprintf('Channel %d',curr_chan));
end

% Update guidata and image
guidata(gui_fig,gui_data);
update_image([], [], gui_fig);

end

function menu_check(currentObject, eventdata, gui_fig)
% Flip check of whatever was selected
currentObject.Checked = ~currentObject.Checked;
% Update image
update_image([], [], gui_fig);
end

function update_image(currentObject, eventdata, gui_fig, gui_text)

% Get guidata
gui_data = guidata(gui_fig);

% Look for histology processing, load if exists
% (change this later: only load given flag reload_processing?)
% (so small and fast to load, maybe it doesn't matter)
AP_histology_processing_fn = fullfile(gui_data.image_path,'AP_histology_processing');
if ~exist(AP_histology_processing_fn,'file')
    load(AP_histology_processing_fn);
end
gui_data.AP_histology_processing = AP_histology_processing;
guidata(gui_fig, gui_data);

% Check for processed re-ordering
if exist('AP_histology_processing','var') && ...
        isfield(AP_histology_processing,'image_order')
    curr_im_idx = AP_histology_processing.image_order(gui_data.curr_slice);
else
    curr_im_idx = gui_data.curr_slice;
end
gui_data.curr_im_idx = curr_im_idx;

% Set color and color limit
color_vector = permute(gui_data.colors,[3,4,1,2]);
clim_permute = permute(gui_data.clim,[2,3,1]);

im_rescaled = double(min(max(gui_data.data{curr_im_idx} - ...
    clim_permute(1,1,:),0),clim_permute(2,1,:)))./ ...
    double(clim_permute(2,1,:));

im_rgb = min(permute(sum(im_rescaled.*color_vector,3),[1,2,4,3]),1);

% Apply rigid transform
im_display = ap_histology.rigid_transform(im_rgb,curr_im_idx,AP_histology_processing);

%%% Add overlays

overlay_dilation = 3;

% Atlas boundaries 
atlas_menu_idx = contains({gui_data.menu.view.Children.Text},'atlas','IgnoreCase',true);
atlas_view = strcmp(gui_data.menu.view.Children(atlas_menu_idx).Checked,'on');
if atlas_view && isfield(gui_data,'atlas_slices')

    % Apply atlas to histology alignment (remove NaN/0's from alignment)
    % (manual if >3 paired control points, automatic otherwise)
    if isfield(AP_histology_processing.histology_ccf,'control_points') && ...
            (size(AP_histology_processing.histology_ccf.control_points.histology{curr_im_idx},1) == ...
            size(AP_histology_processing.histology_ccf.control_points.atlas{curr_im_idx},1)) && ...
            size(AP_histology_processing.histology_ccf.control_points.histology{curr_im_idx},1) >= 3
        % Manual alignment
        atlas_tform = fitgeotform2d( ...
            AP_histology_processing.histology_ccf.control_points.atlas{curr_im_idx}, ...
            AP_histology_processing.histology_ccf.control_points.histology{curr_im_idx},'pwl');
    else
        % Automatic alignment
        atlas_tform = AP_histology_processing.histology_ccf.atlas2histology_tform{curr_im_idx};
    end

    atlas_slice_aligned = max(1,imwarp(gui_data.atlas_slices{curr_im_idx}, ...
        atlas_tform,'nearest','OutputView', ...
        imref2d(AP_histology_processing.histology_ccf.atlas2histology_size{curr_im_idx})));

    % Store aligned atlas slice for quick referencing on hover
    gui_data.curr_atlas_slice = atlas_slice_aligned;

    ccf_borders = imdilate(boundarymask(atlas_slice_aligned),ones(overlay_dilation));
    im_display = imoverlay(im_display,ccf_borders,'w');

end

% Annotations
annotations_menu_idx = contains({gui_data.menu.view.Children.Text},'annotations','IgnoreCase',true);
annotations_view = strcmp(gui_data.menu.view.Children(annotations_menu_idx).Checked,'on');
if annotations_view && isfield(AP_histology_processing,'annotation')
    for curr_probe = 1:length(AP_histology_processing.annotation.probe)
        
        curr_segment = AP_histology_processing.annotation.probe(curr_probe).segments{gui_data.curr_slice};
        if isempty(curr_segment)
            continue
        end

        % Add line
        segment_line = images.roi.Line('Position', ...
            AP_histology_processing.annotation.probe(curr_probe).segments{gui_data.curr_slice});
        segment_mask = imdilate(createMask(segment_line,false(size(im_display))),ones(overlay_dilation));
        im_display = imoverlay(im_display,segment_mask,'y');

        % Add label
        im_display = insertText(im_display, ...
            mean(AP_histology_processing.annotation.probe(curr_probe).segments{gui_data.curr_slice},1), ...
            AP_histology_processing.annotation.probe(curr_probe).label, ...
            'FontSize',min(200,round(max(size(im_display))*0.03)));

    end
end

%%%

% Set image
gui_data.im_h.CData = im_display;

% Update text
if ~exist('gui_text','var')
    gui_text = [];
end
set(gui_data.im_text, 'Position', ...
    [interp1([0,1],gui_data.im_h.Parent.XLim,0.05), ...
    interp1([0,1],gui_data.im_h.Parent.YLim,0.05),0], ...
    'String',gui_text);

% Ensure image scrollbar matches image number (if update called externally)
gui_data.scrollbar_image.Value = gui_data.curr_slice;

% Prioritze drawing this figure
drawnow;

% Update guidata
guidata(gui_fig, gui_data);

end


function scrollbar_image_listener(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

% Get frame number from slider, round and snap
new_im = round(get(gui_data.scrollbar_image,'Value'));

gui_data.scrollbar_image.Value = new_im;
gui_data.curr_slice = new_im;

% Update guidata
guidata(gui_fig, gui_data);

% Update image
update_image(currentObject, eventdata, gui_fig);

end


function scrollbar_black_listener(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

% Set selected channel cmax
curr_channel = gui_data.scrollbar_channel.Value;
new_clim_min = gui_data.scrollbar_black.Value;

gui_data.clim(curr_channel,1) = new_clim_min;

% Update guidata
guidata(gui_fig, gui_data);

% Update image
update_image(currentObject, eventdata, gui_fig);

end


function scrollbar_white_listener(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

% Set selected channel cmax
curr_channel = gui_data.scrollbar_channel.Value;
new_clim_max = gui_data.scrollbar_white.Value;

gui_data.clim(curr_channel,2) = new_clim_max;

% Update guidata
guidata(gui_fig, gui_data);

% Update image
update_image(currentObject, eventdata, gui_fig);

end


function scrollbar_channel_listener(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

% Snap scrollbar to selected channel, set color
curr_channel = round(gui_data.scrollbar_channel.Value);
gui_data.scrollbar_channel.Value = curr_channel;
gui_data.scrollbar_channel.BackgroundColor = ...
    gui_data.colors(curr_channel,:);

% Set black/white scrollbars for selected channel
gui_data.scrollbar_black.Value = gui_data.clim(curr_channel,1);
gui_data.scrollbar_white.Value = gui_data.clim(curr_channel,2);

end


function scrollbar_image_MouseWheel(currentObject, eventdata, gui_fig)
% Change slice on mouse wheel turn 

% Get guidata
gui_data = guidata(gui_fig);

% Do nothing if scrollbar is disabled
if strcmpi(gui_data.scrollbar_image.Enable,'off')
    return
end

% Update image slide based on mouse wheel
mouse_wheel_count = eventdata.VerticalScrollCount;

new_im = gui_data.scrollbar_image.Value + mouse_wheel_count;
if new_im < 1
    new_im = 1;
elseif new_im > length(gui_data.data)
    new_im = length(gui_data.data);
end

gui_data.scrollbar_image.Value = new_im;
gui_data.curr_slice = new_im;

% Update guidata
guidata(gui_fig, gui_data);

% Update image
update_image(currentObject, eventdata, gui_fig);

end


function load_aligned_atlas(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

% Load histology processing file
load(gui_data.histology_processing_filename);

% Display status
set(gui_data.im_text, 'Position', ...
    [interp1([0,1],gui_data.im_h.Parent.XLim,0.05), ...
    interp1([0,1],gui_data.im_h.Parent.YLim,0.05),0], ...
    'String','Loading aligned atlas...');
drawnow;

% Load atlas
[av,tv,gui_data.st] = ap_histology.load_ccf;

% Grab atlas images
slice_atlas = struct('tv',cell(size(gui_data.data)), 'av',cell(size(gui_data.data)));
for curr_slice = 1:length(gui_data.data)
    slice_atlas(curr_slice) = ...
        ap_histology.grab_atlas_slice(av,tv, ...
        AP_histology_processing.histology_ccf.slice_vector, ...
        AP_histology_processing.histology_ccf.slice_points(curr_slice,:), 1);
end

gui_data.atlas_slices = {slice_atlas.av}';

% Update guidata
guidata(gui_fig, gui_data);

% Enable and check histology view
atlas_align_menu_idx = contains({gui_data.menu.atlas.Children.Text},'align','IgnoreCase',true);
[gui_data.menu.atlas.Children(atlas_align_menu_idx).Enable] = deal('on');

atlas_menu_idx = contains({gui_data.menu.view.Children.Text},'atlas','IgnoreCase',true);
gui_data.menu.view.Children(atlas_menu_idx).Enable = 'on';
gui_data.menu.view.Children(atlas_menu_idx).Checked = 'on';

% Update image
gui_data.im_text.String = '';
update_image(currentObject, eventdata, gui_fig);

end


function hover_label(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

% Do nothing if scrollbar is disabled (companion gui open)
if strcmpi(gui_data.scrollbar_image.Enable,'off')
    return
end

% If atlas is checked, display CCF label
atlas_menu_idx = contains({gui_data.menu.view.Children.Text},'atlas','IgnoreCase',true);
atlas_view = strcmp(gui_data.menu.view.Children(atlas_menu_idx).Checked,'on');

if atlas_view

    % Get mouse position
    hover_position = get(gui_data.im_h.Parent,'CurrentPoint');
    hover_x = round(hover_position(1,1));
    hover_y = round(hover_position(1,2));

    % Don't use if mouse out of bounds
    if ...
            hover_x < gui_data.im_h.Parent.XLim(1) || ...
            hover_x > gui_data.im_h.Parent.XLim(2) || ...
            hover_y < gui_data.im_h.Parent.YLim(1) || ...
            hover_y > gui_data.im_h.Parent.YLim(2)
        gui_data.im_text.String = '';
        return
    end

    % Get CCF area at mouse position
    ccf_idx = gui_data.curr_atlas_slice(hover_y,hover_x);
    area_name = gui_data.st(ccf_idx,:).name;

    % Display area name
    set(gui_data.im_text,'Position', ...
        [interp1([0,1],gui_data.im_h.Parent.XLim,0.05), ...
        interp1([0,1],gui_data.im_h.Parent.YLim,0.05),0], ...
        'String',area_name);

end

end














