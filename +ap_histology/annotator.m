function annotator(~,~,histology_scroll_gui)
% Annotate volume of interest by polygon on each slice

% Initialize gui data, add scroll image axis
gui_data = struct;
gui_data.histology_scroll_gui = histology_scroll_gui;

% Create GUI
fig_height = histology_scroll_gui.Position(4)/4;
fig_width = fig_height;
fig_x = histology_scroll_gui.Position(1);
fig_y = sum(histology_scroll_gui.Position([2,4])) - fig_height;
fig_position = [fig_x,fig_y,fig_width,fig_height];

gui_fig = figure('color','w','ToolBar','none','MenuBar','none', ...
    'Name','Annotator','units','normalized','position',fig_position);

gui_data.probe_label_text = ...
    uicontrol('style','text','BackgroundColor','w','units','normalized', ...
    'Position',[0,0.5,0.5,0.2],'String','Annotation label','FontSize',14);

gui_data.probe_label = ...
    uicontrol('style','edit','units','normalized', ...
    'BackgroundColor',[0.9,0.9,0.9], ...
    'Position',[0,0.3,0.5,0.2],'FontSize',14);

ui_buttons = [];
button_height = 0.25;
button_fontsize = 12;

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

end

function draw_annotation(currentObject, eventdata, gui_fig, annotate_fcn)

        % Get gui data
        gui_data = guidata(gui_fig);
        histology_scroll_guidata = guidata(gui_data.histology_scroll_gui);

        % Draw probe segment line (or if no label, do nothing)
        volume_label = gui_data.probe_label.String;
        if isempty(volume_label)
            return
        end
        curr_annotation = annotate_fcn(histology_scroll_guidata.im_h.Parent,'color','y');

        % Load processing and add fields if necessary
        load(histology_scroll_guidata.histology_processing_filename);
        
        if ~isfield(AP_histology_processing,'annotation')
            AP_histology_processing.annotation = struct;
        end        
        
        % Find probe index in annotations, add current annotation
        annotation_idx = find(strcmp(volume_label,[AP_histology_processing.annotation.label]));
        if isempty(annotation_idx)
            annotation_idx = length(AP_histology_processing.annotation)+1;
            AP_histology_processing.annotation(annotation_idx).label = volume_label;
            AP_histology_processing.annotation(annotation_idx).vertices = ...
                cell(size(histology_scroll_guidata.data));
        end

        AP_histology_processing.annotation(annotation_idx).vertices{histology_scroll_guidata.curr_im_idx} = ...
            curr_annotation.Position;

        % Save processing
        save(histology_scroll_guidata.histology_processing_filename, 'AP_histology_processing');

        % Delete line object, update histology image
        curr_annotation.delete;
        histology_scroll_guidata.update([],[],gui_data.histology_scroll_gui);

end




