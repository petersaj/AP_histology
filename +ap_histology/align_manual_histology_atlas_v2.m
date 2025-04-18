function align_manual_histology_atlas_v2(~,~,histology_gui)

% Get gui data
histology_guidata = guidata(histology_gui);
load(histology_guidata.histology_processing_filename);

% Disable image scrolling in histology gui
histology_guidata.scrollbar_image.Enable = 'off';
histology_guidata.update([],[],histology_gui,'Loading atlas slices...');

% Turn on atlas view in histology gui
atlas_menu_idx = contains({histology_guidata.menu.view.Children.Text},'atlas');
histology_guidata.menu.view.Children(atlas_menu_idx).Enable = 'on';
histology_guidata.menu.view.Children(atlas_menu_idx).Checked = 'on';
histology_guidata.update([],[],histology_gui);

% Load atlas, get atlas images
[av,tv,st] = ap_histology.load_ccf;
slice_atlas = struct('tv',cell(size(histology_guidata.data)), 'av',cell(size(histology_guidata.data)));
for curr_slice = 1:length(histology_guidata.data)
    slice_atlas(curr_slice) = ...
        ap_histology.grab_atlas_slice(av,tv, ...
        AP_histology_processing.histology_ccf.slice_vector, ...
        AP_histology_processing.histology_ccf.slice_points(curr_slice,:), 1);
end

% Create manual align gui figure
align_gui = figure('Name','Manual slice aligner','color','w', ...
    'Units','normalized','Position',histology_gui.Position, ... 
    'Toolbar','none','Menubar','none', ...
    'CloseRequestFcn',{@close_gui,histology_gui});
align_guidata = struct;
align_guidata.slice_atlas = slice_atlas;

% Buttons
button_strings = {'Previous histology slice','Next histology slice','Clear alignment points'};
button_functions = {@previous_slice,@next_slice,@clear_control_points};

button_height = 0.1;
button_width = 1/length(button_strings);
button_x = 0:button_width:1-button_width;

for curr_button = 1:length(button_strings)
    uicontrol(align_gui,'style','pushbutton','units','normalized', ...
        'Position',[button_x(curr_button),0,button_width,button_height], ...
        'String',button_strings{curr_button}, ...
        'Callback',{button_functions{curr_button},align_gui,histology_gui});
end

% Draw atlas slice
atlas_ax = axes(align_gui,'YDir','reverse'); 
hold on; axis image off; colormap(gray); clim([0,400]);
align_guidata.im_h = imagesc(atlas_ax,NaN);

% Initialize control points
if ~isfield(AP_histology_processing.histology_ccf,'control_points')
    AP_histology_processing.histology_ccf.control_points.histology = repmat({zeros(0,2)},size(histology_guidata.data));
    AP_histology_processing.histology_ccf.control_points.atlas = repmat({zeros(0,2)},size(histology_guidata.data));
    save(histology_guidata.histology_processing_filename,'AP_histology_processing');
end

% Initialize plots and set click function
hold(histology_guidata.im_h.Parent,'on')
align_guidata.histology_control_points_plot = plot(histology_guidata.im_h.Parent,nan,nan,'.m','MarkerSize',20);

hold(align_guidata.im_h.Parent,'on')
align_guidata.atlas_control_points_plot = plot(align_guidata.im_h.Parent,nan,nan,'.m','MarkerSize',20);

histology_guidata.im_h.ButtonDownFcn = {@mouseclick_align,align_gui,histology_gui};
align_guidata.im_h.ButtonDownFcn = {@mouseclick_align,align_gui,histology_gui};

% Set align gui data
guidata(align_gui,align_guidata);

% Set the first slice in both GUIs
histology_guidata.curr_slice = 1;
guidata(histology_gui,histology_guidata);
histology_guidata.update([],[],histology_gui,'Click align points');

update_atlas_slice(align_gui,histology_gui);


end


function update_atlas_slice(align_gui,histology_gui)

% Get gui data and processing
align_guidata = guidata(align_gui);
histology_guidata = guidata(histology_gui);
load(histology_guidata.histology_processing_filename);

% Update atlas slice
align_guidata.im_h.CData = align_guidata.slice_atlas(histology_guidata.curr_im_idx).tv;

% Update control points on histology and atlas
set(align_guidata.histology_control_points_plot, ...
    'XData',AP_histology_processing.histology_ccf.control_points.histology{histology_guidata.curr_im_idx}(:,1), ...
    'YData',AP_histology_processing.histology_ccf.control_points.histology{histology_guidata.curr_im_idx}(:,2));

set(align_guidata.atlas_control_points_plot, ...
    'XData',AP_histology_processing.histology_ccf.control_points.atlas{histology_guidata.curr_im_idx}(:,1), ...
    'YData',AP_histology_processing.histology_ccf.control_points.atlas{histology_guidata.curr_im_idx}(:,2));

end


function mouseclick_align(currentObject,eventdata,align_gui,histology_gui)

% Check which gui was clicked
% (do nothing if it was neither and somehow got here)
[~,fig_clicked] = ismember(currentObject.Parent.Parent,[histology_gui,align_gui]);
if fig_clicked == 0
    return
end

% Get guidata and processing
histology_guidata = guidata(histology_gui);
align_guidata = guidata(align_gui);
load(histology_guidata.histology_processing_filename);

curr_im_idx = histology_guidata.curr_im_idx;

switch fig_clicked
    case 1 % Histology
        % Add clicked location to control points
        AP_histology_processing.histology_ccf.control_points.histology{curr_im_idx}(end+1,:) = ...
            eventdata.IntersectionPoint(1:2);
    case 2 % Atlas
        % Add clicked location to control points
        AP_histology_processing.histology_ccf.control_points.atlas{curr_im_idx}(end+1,:) = ...
            eventdata.IntersectionPoint(1:2);
end

save(histology_guidata.histology_processing_filename,'AP_histology_processing');

% Update align gui data and plots
guidata(align_gui,align_guidata);
update_atlas_slice(align_gui,histology_gui);

% Update histology image if >=3 pairs of points
if size(AP_histology_processing.histology_ccf.control_points.histology{curr_im_idx},1) == ...
        size(AP_histology_processing.histology_ccf.control_points.atlas{curr_im_idx},1) & ...
        size(AP_histology_processing.histology_ccf.control_points.histology{curr_im_idx},1) >= 3
    histology_guidata.update([],[],histology_gui,'Click align points');
end


end

function previous_slice(currentObject,eventdata,align_gui,histology_gui)

% Get guidata
align_guidata = guidata(align_gui);
histology_guidata = guidata(histology_gui);

% Increment slice
new_slice = max(histology_guidata.curr_slice-1,1);
histology_guidata.curr_slice = new_slice;
guidata(histology_gui,histology_guidata);

% Update images
histology_guidata.update([],[],histology_gui,'Click align points');
update_atlas_slice(align_gui,histology_gui);

end

function next_slice(currentObject,eventdata,align_gui,histology_gui)

% Get guidata
align_guidata = guidata(align_gui);
histology_guidata = guidata(histology_gui);

% Increment slice
new_slice = min(histology_guidata.curr_slice+1,length(histology_guidata.data));
histology_guidata.curr_slice = new_slice;
guidata(histology_gui,histology_guidata);

% Update images
histology_guidata.update([],[],histology_gui,'Click align points');
update_atlas_slice(align_gui,histology_gui);

end


function clear_control_points(currentObject,eventdata,align_gui,histology_gui)

% Get guidata and processing
align_guidata = guidata(align_gui);
histology_guidata = guidata(histology_gui);
load(histology_guidata.histology_processing_filename);

% Clear control points for slice
AP_histology_processing.histology_ccf.control_points.histology{histology_guidata.curr_im_idx} = zeros(0,2);
AP_histology_processing.histology_ccf.control_points.atlas{histology_guidata.curr_im_idx} = zeros(0,2);
save(histology_guidata.histology_processing_filename,'AP_histology_processing');

% Update images
histology_guidata.update([],[],histology_gui,'Click align points');
update_atlas_slice(align_gui,histology_gui);

end


function close_gui(align_gui,eventdata,histology_gui)

% Get guidata
align_guidata = guidata(align_gui);
histology_guidata = guidata(histology_gui);

% Close figure and histology plots
delete(align_gui);
delete(align_guidata.histology_control_points_plot);

% Re-enable image scrolling in histology gui
histology_guidata.scrollbar_image.Enable = 'on';

end
