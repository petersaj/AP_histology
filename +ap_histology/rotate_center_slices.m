function rotate_center_slices(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Pad, center, and rotate slice images

% Get gui data
histology_toolbar_guidata = guidata(histology_toolbar_gui);
histology_scroll_data = guidata(histology_toolbar_guidata.histology_scroll);

% Draw line to indicate midline for rotation
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

bw_clim = [min(histology_scroll_data.clim(:,1)), ...
    max(histology_scroll_data.clim(:,2))];

align_axis = nan(2,2,length(histology_scroll_data.data));
for curr_im = 1:length(histology_scroll_data.data)
    imagesc(max(histology_scroll_data.data{curr_im},[],3));
    clim(bw_clim);
    colormap(gray);
    axis equal off;

    title('Click and drag reference line (e.g. midline)')
    curr_line = imline;
    align_axis(:,:,curr_im) = curr_line.getPosition;  
end
close(gui_fig);

% Get angle for all axes
align_angle = squeeze(atan2d(diff(align_axis(:,1,:),[],1),diff(align_axis(:,2,:),[],1)));
align_center = permute(nanmean(align_axis,1),[3,2,1]);

% Load processing and save rotations
load(histology_toolbar_guidata.histology_processing_filename);

AP_histology_processing.rotation_angle = align_angle;
AP_histology_processing.translation_center = align_center;
save(histology_toolbar_guidata.histology_processing_filename,'AP_histology_processing');




