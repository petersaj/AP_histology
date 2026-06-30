function annotator(~,~,histology_gui)
% Annotate volume of interest by polygon on each slice

% Initialize gui data, add scroll image axis
gui_data = struct;
gui_data.histology_gui = histology_gui;

% Create annotator figure
fig_height = histology_gui.Position(4)/2;
fig_width = fig_height/2;
fig_x = histology_gui.Position(1);
fig_y = sum(histology_gui.Position([2,4])) - fig_height;
fig_position = [fig_x,fig_y,fig_width,fig_height];

gui_fig = uifigure('color','w','Name','Annotator', ...
    'units','normalized','position',fig_position);
gui_grid = uigridlayout(gui_fig,[2,1]);

% Add dropdown for labels
gui_data.annotation_label = uidropdown(gui_grid,'Items',"No annotations",'ValueChangedFcn',{@select_annotation,gui_fig});
gui_data.annotation_label.BackgroundColor = 'w';
gui_data.annotation_label.FontSize = 14;

% Add buttons
button_h = gobjects(0);
button_h(1+end) = uibutton(gui_grid,'text','Line','ButtonPushedFcn',{@draw_annotation,gui_fig,@drawline});
button_h(1+end) = uibutton(gui_grid,'text','Point','ButtonPushedFcn',{@draw_annotation,gui_fig,@drawpoint});
button_h(1+end) = uibutton(gui_grid,'text','Polygon','ButtonPushedFcn',{@draw_annotation,gui_fig,@drawpolygon});
button_h(1+end) = uibutton(gui_grid,'text','Polygon (assist)','ButtonPushedFcn',{@draw_annotation,gui_fig,@drawassisted});
button_h(1+end) = uibutton(gui_grid,'text','Delete annotation on slice','ButtonPushedFcn',{@delete_annotation_slice,gui_fig});
button_h(1+end) = uibutton(gui_grid,'text','Delete annotation entirely','ButtonPushedFcn',{@delete_annotation,gui_fig});

[button_h.FontSize] = deal(14);
[button_h.BackgroundColor] = deal([0.9,0.9,1]);

% Update gui data
guidata(gui_fig,gui_data);

% Ensure annotation view turned on, update image
histology_guidata = guidata(gui_data.histology_gui);
annotations_menu_idx = contains({histology_guidata.menu.view.Children.Text},'annotations','IgnoreCase',true);
histology_guidata.menu.view.Children(annotations_menu_idx).Checked = 'on';
histology_guidata.update([],[],gui_data.histology_gui);

% Populate annotation menu with any extant annotations
load(histology_guidata.histology_processing_filename);
if isfield(AP_histology_processing,'annotation')
    annotation_labels = {AP_histology_processing.annotation.label};
else
    annotation_labels = {};
end
gui_data.annotation_label.Items = horzcat(string(annotation_labels),"New annotation");

end

function draw_annotation(currentObject, eventdata, gui_fig, annotate_fcn)
% Draw annotation with selected method

% Get gui data
gui_data = guidata(gui_fig);
histology_guidata = guidata(gui_data.histology_gui);

% Draw annotation segment line (or if no label, do nothing)
annotation_label = gui_data.annotation_label.Value;
if isempty(annotation_label)
    histology_guidata.update([],[],gui_data.histology_gui,'Cannot annotate without label')
    return
else
    histology_guidata.update([],[],gui_data.histology_gui,sprintf('Draw annotation: %s',annotation_label))
end
curr_annotation = annotate_fcn(histology_guidata.im_h.Parent,'color','y');

% Load processing and add annotation fields if necessary
load(histology_guidata.histology_processing_filename);
if ~isfield(AP_histology_processing,'annotation')
    AP_histology_processing.annotation = struct('label',cell(0),...
        'vertices_histology',cell(0),'vertices_ccf',cell(0));
end

% Find annotation index in annotations, add current annotation
annotation_idx = find(strcmp(annotation_label,{AP_histology_processing.annotation.label}));
if isempty(annotation_idx)
    % (if no annotation with that name, create one)
    annotation_idx = length(AP_histology_processing.annotation)+1;
    AP_histology_processing.annotation(annotation_idx).label = annotation_label;
    AP_histology_processing.annotation(annotation_idx).vertices_histology = ...
        cell(size(histology_guidata.data));
    AP_histology_processing.annotation(annotation_idx).vertices_ccf = ...
        struct('ap',cell(size(histology_guidata.data)), ...
        'ml',cell(size(histology_guidata.data)), ...
        'dv',cell(size(histology_guidata.data)));
end

curr_vertices = curr_annotation.Position;

% Store vertices in histology coordinates
AP_histology_processing.annotation(annotation_idx).vertices_histology{histology_guidata.curr_im_idx} = ...
    curr_vertices;

% Get transform from slice to atlas
% (manual if >3 paired control points, automatic otherwise)
if isfield(AP_histology_processing.histology_ccf,'control_points') && ...
        (size(AP_histology_processing.histology_ccf.control_points.histology{histology_guidata.curr_im_idx},1) == ...
        size(AP_histology_processing.histology_ccf.control_points.atlas{histology_guidata.curr_im_idx},1)) && ...
        size(AP_histology_processing.histology_ccf.control_points.histology{histology_guidata.curr_im_idx},1) >= 3
    % Manual alignment
    atlas_tform = fitgeotform2d( ...
        AP_histology_processing.histology_ccf.control_points.atlas{histology_guidata.curr_im_idx}, ...
        AP_histology_processing.histology_ccf.control_points.histology{histology_guidata.curr_im_idx},'pwl');
elseif isfield(AP_histology_processing.histology_ccf,'atlas2histology_tform')
    % Automatic alignment
    atlas_tform = AP_histology_processing.histology_ccf.atlas2histology_tform{histology_guidata.curr_im_idx};
end

% Convert vertices to CCF coordinates
annotation_vertices_histology_subscript = round(transformPointsInverse( ...
    atlas_tform,curr_vertices));

annotation_vertices_histology_idx = ...
    sub2ind(size(histology_guidata.atlas_slices{histology_guidata.curr_im_idx}), ...
    annotation_vertices_histology_subscript(:,2), ...
    annotation_vertices_histology_subscript(:,1));

[AP_histology_processing.annotation(annotation_idx).vertices_ccf(histology_guidata.curr_im_idx).ap, ...
    AP_histology_processing.annotation(annotation_idx).vertices_ccf(histology_guidata.curr_im_idx).ml, ...
    AP_histology_processing.annotation(annotation_idx).vertices_ccf(histology_guidata.curr_im_idx).dv] = ...
    deal(histology_guidata.atlas_slice_coords(histology_guidata.curr_im_idx).ap(annotation_vertices_histology_idx), ...
    histology_guidata.atlas_slice_coords(histology_guidata.curr_im_idx).ml(annotation_vertices_histology_idx), ...
    histology_guidata.atlas_slice_coords(histology_guidata.curr_im_idx).dv(annotation_vertices_histology_idx));

% Save processing
save(histology_guidata.histology_processing_filename, 'AP_histology_processing');

% Delete line object, update histology image
curr_annotation.delete;
histology_guidata.update([],[],gui_data.histology_gui);

end


function select_annotation(currentObject, eventdata, gui_fig)

% Get gui data
gui_data = guidata(gui_fig);
histology_guidata = guidata(gui_data.histology_gui);

% Get currently selected annotation
annotation_label = gui_data.annotation_label.Value;

% New annotation
if strcmp(annotation_label,'New annotation')
    % Query new label
    new_annotation_label = inputdlg('New annotation label');
    if ~isempty(new_annotation_label)
        % Load processing
        load(histology_guidata.histology_processing_filename);
        % Add new label to list
        if isfield(AP_histology_processing,'annotation')
            annotation_labels = {AP_histology_processing.annotation.label};
        else
            annotation_labels = {};
        end
        gui_data.annotation_label.Items = horzcat(annotation_labels,new_annotation_label,{'New annotation'});
        % Select new label
        gui_data.annotation_label.Value = new_annotation_label;
        % Update gui data
        guidata(gui_fig,gui_data);
    end
end

end

function delete_annotation_slice(currentObject, eventdata, gui_fig)
% Delete verticies of selected annotation on slice

% Get gui data
gui_data = guidata(gui_fig);
histology_guidata = guidata(gui_data.histology_gui);

% Load processing
load(histology_guidata.histology_processing_filename);

% Delete any selected annotations on slice
annotation_label = gui_data.annotation_label.Value;
annotation_idx = find(strcmp(annotation_label,{AP_histology_processing.annotation.label}));

AP_histology_processing.annotation(annotation_idx).vertices_histology{histology_guidata.curr_im_idx} = [];
AP_histology_processing.annotation(annotation_idx).vertices_ccf(histology_guidata.curr_im_idx).ap = [];
AP_histology_processing.annotation(annotation_idx).vertices_ccf(histology_guidata.curr_im_idx).ml = [];
AP_histology_processing.annotation(annotation_idx).vertices_ccf(histology_guidata.curr_im_idx).dv = [];

% Save processing
save(histology_guidata.histology_processing_filename, 'AP_histology_processing');

% Update histology image
histology_guidata.update([],[],gui_data.histology_gui);
end

function delete_annotation(currentObject, eventdata, gui_fig)
% Delete entire annotation

% Get gui data
gui_data = guidata(gui_fig);
histology_guidata = guidata(gui_data.histology_gui);

% Get currently selected annotation
annotation_label = gui_data.annotation_label.Value;

% Confirm with user
user_confirm = ...
    uiconfirm(gui_fig,sprintf('Delete annotation: ''%s''?',annotation_label), ...
    "Confirm delete annotation",'Icon','warning');

if strcmp(user_confirm,'OK')
    % Remove annotation from list
    gui_data.annotation_label.Items = setdiff(gui_data.annotation_label.Items,annotation_label);

    % Remove annotation from saved histology file
    load(histology_guidata.histology_processing_filename);
    annotation_idx = find(strcmp(annotation_label,{AP_histology_processing.annotation.label}));
    AP_histology_processing.annotation(annotation_idx) = [];
    save(histology_guidata.histology_processing_filename, 'AP_histology_processing');

    % Update histology image
    histology_guidata.update([],[],gui_data.histology_gui);
end

end



