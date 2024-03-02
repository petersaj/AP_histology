function align_manual_histology_atlas(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Manually align histology slices and matched CCF slices

% Initialize guidata
gui_data = struct;

% Store toolbar handle
gui_data.histology_toolbar_gui = histology_toolbar_gui;

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

% Load automated alignment
auto_ccf_alignment_fn = fullfile(gui_data.save_path,'atlas2histology_tform.mat');
if exist(auto_ccf_alignment_fn,'file')
    load(auto_ccf_alignment_fn);
    gui_data.histology_ccf_auto_alignment = atlas2histology_tform;
end

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
    'Toolbar','none','Menubar','none','color','w', ...
    'Units','pixels','Position',gui_position, ...
    'CloseRequestFcn',@close_gui);

gui_data.curr_slice = 1;

% Set up axis for histology image
gui_data.histology_ax = subplot(1,2,1,'YDir','reverse'); 
set(gui_data.histology_ax,'Position',[0,0,0.5,0.9]);
hold on; colormap(gray); axis image off;
gui_data.histology_im_h = image(gui_data.slice_im{1}, ...
    'Parent',gui_data.histology_ax,'ButtonDownFcn',@mouseclick_histology);

% Set up histology-aligned atlas overlay
% (and make it invisible to mouse clicks)
histology_aligned_atlas_boundaries_init = ...
    zeros(size(gui_data.slice_im{1},1),size(gui_data.slice_im{1},2));
gui_data.histology_aligned_atlas_boundaries = ...
    imagesc(histology_aligned_atlas_boundaries_init,'Parent',gui_data.histology_ax, ...
    'AlphaData',histology_aligned_atlas_boundaries_init,'PickableParts','none');

% Set up axis for atlas slice
gui_data.atlas_ax = subplot(1,2,2,'YDir','reverse'); 
set(gui_data.atlas_ax,'Position',[0.5,0,0.5,0.9]);
hold on; axis image off; colormap(gray); caxis([0,400]);
gui_data.atlas_im_h = imagesc(gui_data.histology_ccf(1).tv_slices, ...
    'Parent',gui_data.atlas_ax,'ButtonDownFcn',@mouseclick_atlas);

% Initialize alignment control points and tform matricies
gui_data.histology_control_points = repmat({zeros(0,2)},length(gui_data.slice_im),1);
gui_data.atlas_control_points = repmat({zeros(0,2)},length(gui_data.slice_im),1);

gui_data.histology_control_points_plot = plot(gui_data.histology_ax,nan,nan,'.w','MarkerSize',20);
gui_data.atlas_control_points_plot = plot(gui_data.atlas_ax,nan,nan,'.r','MarkerSize',20);

% If there was previously auto-alignment, intitialize with that
if isfield(gui_data,'histology_ccf_auto_alignment')
    gui_data.histology_ccf_manual_alignment = gui_data.histology_ccf_auto_alignment;
end

% Upload gui data
guidata(gui_fig,gui_data);

% Initialize alignment
align_ccf_to_histology(gui_fig);

% Print controls
CreateStruct.Interpreter = 'tex';
CreateStruct.WindowStyle = 'non-modal';
msgbox( ...
    {'\fontsize{12}' ...
    '\bf Controls: \rm' ...
    'Left/right: switch slice' ...
    'click: set reference points for manual alignment (3 minimum)', ...
    'space: toggle alignment overlay visibility', ...
    'c: clear reference points', ...
    's: save'}, ...
    'Controls',CreateStruct);

end


function keypress(gui_fig,eventdata)

% Get guidata
gui_data = guidata(gui_fig);

switch eventdata.Key
    
    % left/right arrows: move slice
    case 'leftarrow'
        gui_data.curr_slice = max(gui_data.curr_slice - 1,1);
        guidata(gui_fig,gui_data);
        update_slice(gui_fig);
        
    case 'rightarrow'
        gui_data.curr_slice = ...
            min(gui_data.curr_slice + 1,length(gui_data.slice_im));
        guidata(gui_fig,gui_data);
        update_slice(gui_fig);
        
    % space: toggle overlay visibility
    case 'space'
        curr_visibility = ...
            get(gui_data.histology_aligned_atlas_boundaries,'Visible');
        set(gui_data.histology_aligned_atlas_boundaries,'Visible', ...
            cell2mat(setdiff({'on','off'},curr_visibility)))
        
    % c: clear current points
    case 'c'
        gui_data.histology_control_points{gui_data.curr_slice} = zeros(0,2);
        gui_data.atlas_control_points{gui_data.curr_slice} = zeros(0,2);
        
        guidata(gui_fig,gui_data);
        update_slice(gui_fig);
        
    % s: save
    case 's'
        atlas2histology_tform = ...
            gui_data.histology_ccf_manual_alignment;
        save_fn = fullfile(gui_data.save_path,'atlas2histology_tform.mat');
        save(save_fn,'atlas2histology_tform');
        disp(['Saved ' save_fn]);
        
end

end


function mouseclick_histology(gui_fig,eventdata)
% Draw new point for alignment

% Get guidata
gui_data = guidata(gui_fig);

% Add clicked location to control points
gui_data.histology_control_points{gui_data.curr_slice} = ...
    vertcat(gui_data.histology_control_points{gui_data.curr_slice}, ...
    eventdata.IntersectionPoint(1:2));

set(gui_data.histology_control_points_plot, ...
    'XData',gui_data.histology_control_points{gui_data.curr_slice}(:,1), ...
    'YData',gui_data.histology_control_points{gui_data.curr_slice}(:,2));

% Upload gui data
guidata(gui_fig, gui_data);

% If equal number of histology/atlas control points > 3, draw boundaries
if size(gui_data.histology_control_points{gui_data.curr_slice},1) == ...
        size(gui_data.atlas_control_points{gui_data.curr_slice},1) || ...
        (size(gui_data.histology_control_points{gui_data.curr_slice},1) > 3 && ...
        size(gui_data.atlas_control_points{gui_data.curr_slice},1) > 3)
    align_ccf_to_histology(gui_fig)
end

end


function mouseclick_atlas(gui_fig,eventdata)
% Draw new point for alignment

% Get guidata
gui_data = guidata(gui_fig);

% Add clicked location to control points
gui_data.atlas_control_points{gui_data.curr_slice} = ...
    vertcat(gui_data.atlas_control_points{gui_data.curr_slice}, ...
    eventdata.IntersectionPoint(1:2));

set(gui_data.atlas_control_points_plot, ...
    'XData',gui_data.atlas_control_points{gui_data.curr_slice}(:,1), ...
    'YData',gui_data.atlas_control_points{gui_data.curr_slice}(:,2));

% Upload gui data
guidata(gui_fig, gui_data);

% If equal number of histology/atlas control points > 3, draw boundaries
if size(gui_data.histology_control_points{gui_data.curr_slice},1) == ...
        size(gui_data.atlas_control_points{gui_data.curr_slice},1) || ...
        (size(gui_data.histology_control_points{gui_data.curr_slice},1) > 3 && ...
        size(gui_data.atlas_control_points{gui_data.curr_slice},1) > 3)
    align_ccf_to_histology(gui_fig)
end

end


function align_ccf_to_histology(gui_fig)

% Get guidata
gui_data = guidata(gui_fig);

if size(gui_data.histology_control_points{gui_data.curr_slice},1) == ...
        size(gui_data.atlas_control_points{gui_data.curr_slice},1) && ...
        (size(gui_data.histology_control_points{gui_data.curr_slice},1) >= 3 && ...
        size(gui_data.atlas_control_points{gui_data.curr_slice},1) >= 3)
    % If same number of >= 3 control points, use control point alignment
    tform = fitgeotrans(gui_data.atlas_control_points{gui_data.curr_slice}, ...
        gui_data.histology_control_points{gui_data.curr_slice},'affine');
    title(gui_data.histology_ax,'New alignment');


elseif size(gui_data.histology_control_points{gui_data.curr_slice},1) >= 1 ||  ...
        size(gui_data.atlas_control_points{gui_data.curr_slice},1) >= 1
    % If less than 3 or nonmatching points, use auto but don't draw
    title(gui_data.histology_ax,'New alignment');

    % Upload gui data
    guidata(gui_fig, gui_data);
    return

elseif isfield(gui_data,'histology_ccf_auto_alignment')
    % If no points, use automated outline if available
    tform = affine2d;
    tform.T = gui_data.histology_ccf_auto_alignment{gui_data.curr_slice};
    title(gui_data.histology_ax,'Previous alignment');
else
    % If nothing available, use identity transform
    tform = affine2d;
    title(gui_data.histology_ax,'No alignment');
end

curr_av_slice = gui_data.histology_ccf(gui_data.curr_slice).av_slices;
curr_av_slice(isnan(curr_av_slice)) = 1;
curr_slice_im = gui_data.slice_im{gui_data.curr_slice};

tform_size = imref2d([size(curr_slice_im,1),size(curr_slice_im,2)]);
curr_av_slice_warp = imwarp(curr_av_slice, tform, 'OutputView',tform_size);

av_warp_boundaries = round(conv2(curr_av_slice_warp,ones(3)./9,'same')) ~= curr_av_slice_warp;

set(gui_data.histology_aligned_atlas_boundaries, ...
    'CData',av_warp_boundaries, ...
    'AlphaData',av_warp_boundaries*0.3);

% Update transform matrix
gui_data.histology_ccf_manual_alignment{gui_data.curr_slice} = tform.T;

% Upload gui data
guidata(gui_fig, gui_data);

end


function update_slice(gui_fig)
% Draw histology and CCF slice

% Get guidata
gui_data = guidata(gui_fig);

% Set next histology slice
set(gui_data.histology_im_h,'CData',gui_data.slice_im{gui_data.curr_slice})
set(gui_data.atlas_im_h,'CData',gui_data.histology_ccf(gui_data.curr_slice).tv_slices);

% Plot control points for slice
set(gui_data.histology_control_points_plot, ...
    'XData',gui_data.histology_control_points{gui_data.curr_slice}(:,1), ...
    'YData',gui_data.histology_control_points{gui_data.curr_slice}(:,2));
set(gui_data.atlas_control_points_plot, ...
    'XData',gui_data.atlas_control_points{gui_data.curr_slice}(:,1), ...
    'YData',gui_data.atlas_control_points{gui_data.curr_slice}(:,2));

% Reset histology-aligned atlas boundaries if not
histology_aligned_atlas_boundaries_init = ...
    zeros(size(gui_data.slice_im{1},1),size(gui_data.slice_im{1},2));
set(gui_data.histology_aligned_atlas_boundaries, ...
    'CData',histology_aligned_atlas_boundaries_init, ...
    'AlphaData',histology_aligned_atlas_boundaries_init);

% Upload gui data
guidata(gui_fig, gui_data);

% Update atlas boundaries
align_ccf_to_histology(gui_fig)

end

function close_gui(gui_fig,~)

% Get guidata
gui_data = guidata(gui_fig);

opts.Default = 'Yes';
opts.Interpreter = 'tex';
user_confirm = questdlg('\fontsize{14} Save?','Confirm exit',opts);
switch user_confirm
    case 'Yes'
        % Save and close
        atlas2histology_tform = ...
            gui_data.histology_ccf_manual_alignment;
        save_fn = fullfile(gui_data.save_path,'atlas2histology_tform.mat');
        save(save_fn,'atlas2histology_tform');
        disp(['Saved ' save_fn]);
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



















