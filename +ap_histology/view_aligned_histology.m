function view_aligned_histology(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% View histology slices with overlaid aligned CCF areas

% Initialize guidata
gui_data = struct;

% Load atlas structure tree
allen_atlas_path = fileparts(which('template_volume_10um.npy'));
if isempty(allen_atlas_path)
    error('No CCF atlas found (add CCF atlas to path)')
end
gui_data.st = ap_histology.loadStructureTree(fullfile(allen_atlas_path,'structure_tree_safe_2017.csv'));

% Get images (from path in toolbar GUI)
histology_toolbar_guidata = guidata(histology_toolbar_gui);
gui_data.save_path = histology_toolbar_guidata.save_path;

slice_dir = dir(fullfile(gui_data.save_path,'*.tif'));
slice_fn = natsortfiles(cellfun(@(path,fn) fullfile(path,fn), ...
    {slice_dir.folder},{slice_dir.name},'uni',false));

gui_data.slice_im = cell(length(slice_fn),1);
for curr_slice = 1:length(slice_fn)
   gui_data.slice_im{curr_slice} = imread(slice_fn{curr_slice});  
end

% Load corresponding CCF slices
ccf_slice_fn = fullfile(gui_data.save_path,'histology_ccf.mat');
load(ccf_slice_fn);
gui_data.histology_ccf = histology_ccf;

% Load histology/CCF alignment
ccf_alignment_fn = fullfile(gui_data.save_path,'atlas2histology_tform.mat');
load(ccf_alignment_fn);
gui_data.histology_ccf_alignment = atlas2histology_tform;

% Warp area labels by histology alignment
gui_data.histology_aligned_av_slices = cell(length(gui_data.slice_im),1);
for curr_slice = 1:length(gui_data.slice_im)
    curr_av_slice = gui_data.histology_ccf(curr_slice).av_slices;
    curr_av_slice(isnan(curr_av_slice)) = 1;
    curr_slice_im = gui_data.slice_im{curr_slice};
    
    tform = affine2d;
    tform.T = gui_data.histology_ccf_alignment{curr_slice};   
    tform_size = imref2d([size(curr_slice_im,1),size(curr_slice_im,2)]);
    gui_data.histology_aligned_av_slices{curr_slice} = ...
        imwarp(curr_av_slice,tform,'nearest','OutputView',tform_size);
end

% Select atlas overlay color
gui_data.overlay_color = uisetcolor([0,0,1],'Select atlas overlay color');

% Create figure, set button functions
screen_size_px = get(0,'screensize');
gui_aspect_ratio = 1.7; % width/length
gui_width_fraction = 0.6; % fraction of screen width to occupy
gui_width_px = screen_size_px(3).*gui_width_fraction;
gui_position = [...
    (screen_size_px(3)-gui_width_px)/2, ... % left x
    (screen_size_px(4)-gui_width_px/gui_aspect_ratio)/2, ... % bottom y
    gui_width_px,gui_width_px/gui_aspect_ratio]; % width, height

gui_fig = figure('KeyPressFcn',@keypress, ...
    'WindowButtonMotionFcn',@mousehover, ...
    'Menubar','none','Toolbar','figure','color','w', ...
    'Units','pixels','Position',gui_position);

gui_data.curr_slice = 1;
gui_data.overlay_flag = true;

% Set up axis for histology image
gui_data.histology_ax = axes('YDir','reverse'); 
hold on; colormap(gray); axis image off;
gui_data.histology_im_h = image(gui_data.slice_im{1}, ...
    'Parent',gui_data.histology_ax);

% Create title to write area in
gui_data.histology_ax_title = title(gui_data.histology_ax,'','FontSize',14);

% Upload gui data
guidata(gui_fig,gui_data);

% Update the slice
update_slice(gui_fig);

end


function keypress(gui_fig,eventdata)

% Get guidata
gui_data = guidata(gui_fig);

switch eventdata.Key
    
    % Left/right: move slice
    case 'leftarrow'
        gui_data.curr_slice = max(gui_data.curr_slice - 1,1);
        guidata(gui_fig,gui_data);
        update_slice(gui_fig);
        
    case 'rightarrow'
        gui_data.curr_slice = ...
            min(gui_data.curr_slice + 1,length(gui_data.slice_im));
        guidata(gui_fig,gui_data);
        update_slice(gui_fig);
        
    case 'space'
        gui_data.overlay_flag = ~gui_data.overlay_flag;
        guidata(gui_fig,gui_data);
        update_slice(gui_fig);
        
end

end

function mousehover(gui_fig,eventdata)
% Display area of atlas on mouse hover

% Get guidata
gui_data = guidata(gui_fig);

% Get mouse position
mouse_position = get(gui_data.histology_ax,'CurrentPoint');
mouse_x = round(mouse_position(1,1));
mouse_y = round(mouse_position(1,2));

curr_av_slice_warp = gui_data.histology_aligned_av_slices{gui_data.curr_slice};

% Don't use if mouse out of bounds
if ~ismember(mouse_x,1:size(curr_av_slice_warp,2)) || ...
        ~ismember(mouse_y,1:size(curr_av_slice_warp,1))
    return
end
    
curr_av = curr_av_slice_warp(mouse_y,mouse_x);

% Don't use if AV = 0
if curr_av == 0
    return
end

% Grab area name and set title
curr_area_name = gui_data.st.safe_name(curr_av);
set(gui_data.histology_ax_title,'String',curr_area_name);

end


function update_slice(gui_fig)
% Draw histology and CCF slice

% Get guidata
gui_data = guidata(gui_fig);

% Set next histology slice
curr_slice_im = gui_data.slice_im{gui_data.curr_slice};

% Align current atlas slice and get boundaries
curr_av_slice_warp = gui_data.histology_aligned_av_slices{gui_data.curr_slice};
av_warp_boundaries = boundarymask(curr_av_slice_warp);
gui_data.curr_av_warp_boundaries = av_warp_boundaries;

% Plot slice and overlaid atlas boundaries
if gui_data.overlay_flag
    curr_overlay = imoverlay(curr_slice_im,gui_data.curr_av_warp_boundaries, ...
        gui_data.overlay_color);
    set(gui_data.histology_im_h,'CData',curr_overlay);
else
    set(gui_data.histology_im_h,'CData',curr_slice_im);
end

% Upload gui data
guidata(gui_fig, gui_data);

end




















