function annotator(~,~,histology_gui)
% Annotate volume of interest by polygon on each slice

% Initialize gui data, add scroll image axis
gui_data = struct;
gui_data.histology_gui = histology_gui;

% Create GUI
fig_height = histology_gui.Position(4)/4;
fig_width = fig_height;
fig_x = histology_gui.Position(1);
fig_y = sum(histology_gui.Position([2,4])) - fig_height;
fig_position = [fig_x,fig_y,fig_width,fig_height];

gui_fig = figure('color','w','ToolBar','none','MenuBar','none', ...
    'Name','Annotator','units','normalized','position',fig_position);

gui_data.annotation_label_text = ...
    uicontrol('style','text','BackgroundColor','w','units','normalized', ...
    'Position',[0,0.5,0.5,0.2],'String','Annotation label','FontSize',14);

gui_data.annotation_label = ...
    uicontrol('style','popupmenu','string','No annotations','units','normalized', ...
    'BackgroundColor',[0.9,0.9,0.9], ...
    'Position',[0,0.3,0.5,0.2],'FontSize',14, ...
    'Callback',{@select_annotation,gui_fig});

ui_buttons = [];
button_height = 1/5; % (just manual at the moment, not autospaced)
button_fontsize = 12;

ui_buttons(end+1) = uicontrol('style','pushbutton','units','normalized', ...
    'Position',[0.5,button_height*length(ui_buttons),0.5,button_height], ...
    'String','Delete on slice','BackgroundColor',[0.9,0.9,1], ...
    'FontSize',button_fontsize,'Callback',{@delete_annotation_slice,gui_fig});

ui_buttons(end+1) = uicontrol('style','pushbutton','units','normalized', ...
    'Position',[0.5,button_height*length(ui_buttons),0.5,button_height], ...
    'String','Polygon (assist)','BackgroundColor',[0.9,0.9,1], ...
    'FontSize',button_fontsize,'Callback',{@draw_annotation,gui_fig,@drawassisted});

ui_buttons(end+1) = uicontrol('style','pushbutton','units','normalized', ...
    'Position',[0.5,button_height*length(ui_buttons),0.5,button_height], ...
    'String','Polygon','BackgroundColor',[0.9,0.9,1], ...
    'FontSize',button_fontsize,'Callback',{@draw_annotation,gui_fig,@drawpolygon});

ui_buttons(end+1) = uicontrol('style','pushbutton','units','normalized', ...
    'Position',[0.5,button_height*length(ui_buttons),0.5,button_height], ...
    'String','Point','BackgroundColor',[0.9,0.9,1], ...
    'FontSize',button_fontsize,'Callback',{@draw_annotation,gui_fig,@drawpoint});

ui_buttons(end+1) = uicontrol('style','pushbutton','units','normalized', ...
    'Position',[0.5,button_height*length(ui_buttons),0.5,button_height], ...
    'String','Line','BackgroundColor',[0.9,0.9,1], ...
    'FontSize',button_fontsize,'Callback',{@draw_annotation,gui_fig,@drawline});

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
gui_data.annotation_label.String = horzcat(annotation_labels,{'New annotation'});

end

function draw_annotation(currentObject, eventdata, gui_fig, annotate_fcn)
% Draw annotation with selected method

        % Get gui data
        gui_data = guidata(gui_fig);
        histology_guidata = guidata(gui_data.histology_gui);

        % Draw annotation segment line (or if no label, do nothing)
        annotation_label = gui_data.annotation_label.String{gui_data.annotation_label.Value};
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

        % Convert vertices to CCF coordinates and store
        annotation_vertices_histology_subscript = round(transformPointsInverse( ...
            AP_histology_processing.histology_ccf.atlas2histology_tform{histology_guidata.curr_im_idx}, ...
            curr_vertices));

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


function delete_annotation_slice(currentObject, eventdata, gui_fig, annotate_fcn)
% Delete verticies of selected annotation on slice

        % Get gui data
        gui_data = guidata(gui_fig);
        histology_guidata = guidata(gui_data.histology_gui);

        % Load processing 
        load(histology_guidata.histology_processing_filename);

        % Delete any selected annotations on slice
        annotation_label = gui_data.annotation_label.String{gui_data.annotation_label.Value};
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



function select_annotation(currentObject, eventdata, gui_fig)

% Get gui data
gui_data = guidata(gui_fig);
histology_guidata = guidata(gui_data.histology_gui);

% Get currently selected annotation
annotation_label = gui_data.annotation_label.String{gui_data.annotation_label.Value};

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
        gui_data.annotation_label.String = horzcat(annotation_labels,new_annotation_label,{'New annotation'});
        % Select new label
        gui_data.annotation_label.Value = length(gui_data.annotation_label.String)-1;
        % Update gui data
        guidata(gui_fig,gui_data);
    end
end

end


