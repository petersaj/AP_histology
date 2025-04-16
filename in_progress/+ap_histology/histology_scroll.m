function gui_fig = histology_scroll(image_path,channel_colors)
% gui_fig = histology_scroll(images,channel_colors)
%
%%% CURRENTLY WORKING

% Viewer for histology
% fold into AP_histology

%% Pick directory if none input

if isempty(image_path)
    image_path = uigetdir;
end

%% Set up gui data structure

gui_data = struct;
gui_data.image_path = image_path;

%% Load images

image_dir = dir(fullfile(image_path,'*.tif'));

image_filenames = cellfun(@(path,name) fullfile(path,name), ...
    {image_dir.folder},{image_dir.name},'uni',false);
[~,sort_idx] = natsortfiles(image_filenames);

% Load images
waitbar_h = waitbar(0);
images = cell(size(image_dir));
for curr_im = 1:length(sort_idx)
    waitbar(curr_im/length(sort_idx),waitbar_h, ...
        sprintf('Loading images (%d/%d)',curr_im,length(sort_idx)));

    images{curr_im} = tiffreadVolume( ...
        image_filenames{sort_idx(curr_im)});
end
close(waitbar_h);

gui_data.data = images;
gui_data.curr_im = 1;

%% Create GUI

% Get number of channels and color limits
n_channels = size(images{1},3);
clim_min = squeeze(min(cell2mat(cellfun(@(x) min(x,[],[1,2]),images,'uni',false)),[],1));
clim_max = squeeze(max(cell2mat(cellfun(@(x) max(x,[],[1,2]),images,'uni',false)),[],1));

gui_data.clim = [clim_min,clim_max];

if ~exist('channel_colors','var') || isempty(channel_colors)
    % Default channel colors to RGB
    channel_colors = [1,0,0;0,1,0;0,0,1];
end
gui_data.colors = channel_colors(1:n_channels,:);

% Create figure for scrolling and ROIs
fig_position = [0.025,0.15,0.3,0.7];
gui_fig = figure('Color',[0.5,0.5,0.5],'Name','Histology scroller', ...
    'Units','normalized','position',fig_position);
set(gui_fig,'WindowScrollWheelFcn',{@scrollbar_image_MouseWheel, gui_fig});
set(gui_fig, 'KeyPressFcn', {@im_keypress, gui_fig});

% Make figure toolbar available 
% (with only zoom and pan - must be a better way to do this)
set(gui_fig,'MenuBar','none')
set(gui_fig,'ToolBar','figure');

set(groot,'ShowHiddenHandles','on');
toolbar_h = findobj(gui_fig.Children,'Type','uitoolbar');
toolbar_zoomin_h = findobj(toolbar_h.Children,'Tag','Exploration.ZoomIn');
toolbar_zoomout_h = findobj(toolbar_h.Children,'Tag','Exploration.ZoomOut');
toolbar_pan_h = findobj(toolbar_h.Children,'Tag','Exploration.Pan');
delete(setdiff(toolbar_h.Children,[toolbar_zoomin_h,toolbar_zoomout_h,toolbar_pan_h]));
set(groot,'ShowHiddenHandles','off');

%%%%%%%% Menus

% Test menu
gui_data.menu.preprocess = uimenu(gui_fig,'Text','Menu');

uimenu(gui_data.menu.preprocess,'Text','Menu option 1','MenuSelectedFcn', ...
    {@(x) [],gui_fig});

uimenu(gui_data.menu.preprocess,'Text','Load aligned atlas','MenuSelectedFcn', ...
    {@load_aligned_atlas,gui_fig});

%%%%%%%%%% 

% Set up scrollbars
scrollbar_height = 0.02;
scrollbar_label_width = 0.1;

% (image scrollbar)
ypos = [scrollbar_label_width, 0*scrollbar_height, 1-scrollbar_label_width, scrollbar_height];
gui_data.scrollbar_image = uicontrol('style','slider','units','normalized', ...
    'position',ypos,'min',1,'max',length(images),'value',1, ...
    'sliderstep',repmat(1/length(images),1,2));
set(gui_data.scrollbar_image,'Callback',{@scrollbar_image_listener, gui_fig});
uicontrol('style','text','units','normalized', ...
    'position',[0,ypos(2),scrollbar_label_width,ypos(4)], ...
    'String','Image')

% (channel scrollbar)
ypos = [scrollbar_label_width, 1*scrollbar_height, 1-scrollbar_label_width, scrollbar_height];
gui_data.scrollbar_channel = uicontrol('style','slider','units','normalized', ...
    'position',ypos,'min',1,'max',n_channels,'value',1, ...
    'sliderstep',repmat(1/(n_channels-1),1,2));
gui_data.scrollbar_channel.BackgroundColor = gui_data.colors(1,:);
set(gui_data.scrollbar_channel,'Callback',{@scrollbar_channel_listener, gui_fig});
uicontrol('style','text','units','normalized', ...
    'position',[0,ypos(2),scrollbar_label_width,ypos(4)], ...
    'String','Channel')

% (white scrollbar)
ypos = [scrollbar_label_width, 2*scrollbar_height, 1-scrollbar_label_width, scrollbar_height];
gui_data.scrollbar_white = uicontrol('style','slider','units','normalized', ...
    'position',ypos,'min',0,'max',max(clim_max),'value',max(gui_data.clim(:,2)), ...
    'sliderstep',repmat(1/double(max(gui_data.clim(:,2))),1,2));
gui_data.scrollbar_white.BackgroundColor = 'w';
set(gui_data.scrollbar_white,'Callback',{@scrollbar_white_listener, gui_fig});
uicontrol('style','text','units','normalized', ...
    'position',[0,ypos(2),scrollbar_label_width,ypos(4)], ...
    'String','Color max')

% (black scrollbar)
ypos = [scrollbar_label_width, 3*scrollbar_height, 1-scrollbar_label_width, scrollbar_height];
gui_data.scrollbar_black = uicontrol('style','slider','units','normalized', ...
    'position',ypos,'min',0,'max',max(clim_max),'value',0, ...
    'sliderstep',repmat(1/double(max(gui_data.clim(:,2))),1,2));
gui_data.scrollbar_black.BackgroundColor = 'k';
set(gui_data.scrollbar_black,'Callback',{@scrollbar_black_listener, gui_fig});
uicontrol('style','text','units','normalized', ...
    'position',[0,ypos(2),scrollbar_label_width,ypos(4)], ...
    'String','Color min')

% Draw image
im_ax = axes('Units','normalized','Position',[0,4*scrollbar_height,1,1-4*scrollbar_height]);
gui_data.im_h = imagesc(im_ax,NaN);
axis image off;

% Save update function handle for external calling
gui_data.update = @update_image;

% Update gui data
guidata(gui_fig,gui_data);

% Update first image
update_image([], [], gui_fig);

end



function update_image(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

% Look for histology processing, load if exists
% (change this later: only load if creation date larger than last loaded?)
AP_histology_processing_fn = fullfile(gui_data.image_path,'AP_histology_processing');
if ~exist(AP_histology_processing_fn,'file')
    load(AP_histology_processing_fn);
end

% Check for processed re-ordering
if exist('AP_histology_processing','var') && ...
        isfield(AP_histology_processing,'image_order')
    curr_im = AP_histology_processing.image_order(gui_data.curr_im);
else
    curr_im = gui_data.curr_im;
end

% Set color and color limit
color_vector = permute(gui_data.colors,[3,4,1,2]);
clim_permute = permute(gui_data.clim,[2,3,1]);

im_rescaled = double(min(max(gui_data.data{curr_im} - ...
    clim_permute(1,1,:),0),clim_permute(2,1,:)))./ ...
    double(clim_permute(2,1,:));

im_rgb = min(permute(sum(im_rescaled.*color_vector,3),[1,2,4,3]),1);

% Apply rigid transform
im_display = ap_histology.rigid_transform(im_rgb,curr_im,AP_histology_processing);

% Set image
gui_data.im_h.CData = im_display;

% Ensure image scrollbar matches image number (if update called externally)
gui_data.scrollbar_image.Value = gui_data.curr_im;

end


function scrollbar_image_listener(currentObject, eventdata, gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

% Get frame number from slider, round and snap
new_im = round(get(gui_data.scrollbar_image,'Value'));

gui_data.scrollbar_image.Value = new_im;
gui_data.curr_im = new_im;

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

% Update image slide based on mouse wheel
mouse_wheel_count = eventdata.VerticalScrollCount;

new_im = gui_data.scrollbar_image.Value + mouse_wheel_count;
if new_im < 1
    new_im = 1;
elseif new_im > length(gui_data.data)
    new_im = length(gui_data.data);
end

gui_data.scrollbar_image.Value = new_im;
gui_data.curr_im = new_im;

% Update guidata
guidata(gui_fig, gui_data);

% Update image
update_image(currentObject, eventdata, gui_fig);

end


function load_aligned_atlas(currentObject, eventdata, gui_fig)

%%% WORKING HERE

% Load histology processing file
test_fn = "\\qnap-ap001.dpag.ox.ac.uk\APlab\Data\AM010\histology\raw\AP_histology_processing.mat";
load(test_fn);

%%%

% Get guidata
gui_data = guidata(gui_fig);

% Load atlas
[av,tv,st] = ap_histology.load_ccf;

% Grab atlas images
slice_atlas = struct('tv',cell(size(gui_data.data)), 'av',cell(size(gui_data.data)));
for curr_slice = 1:length(gui_data.data)
    slice_atlas(curr_slice) = ...
        ap_histology.grab_atlas_slice(av,tv, ...
        AP_histology_processing.histology_ccf.slice_vector, ...
        AP_histology_processing.histology_ccf.slice_points(curr_slice,:), 1);
end

% Update guidata
guidata(gui_fig, gui_data);

end






