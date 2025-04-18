function annotate_probes(~,~,histology_scroll_gui)
% Annotate dyed probe tracts on histology slices

% Initialize gui data, add scroll image axis
gui_data = struct;
gui_data.histology_scroll_gui = histology_scroll_gui;

% Create GUI
fig_height = histology_scroll_gui.Position(4)/4;
fig_width = fig_height;
fig_x = histology_scroll_gui.Position(1);
fig_y = sum(histology_scroll_gui.Position([2,4])) - fig_height;
fig_position = [fig_x,fig_y,fig_width,fig_height];

gui_fig = figure('color','w','toolBar','none','menubar','none', ...
    'Name','Probe annotator', ...
    'units','normalized','position',fig_position);

gui_data.probe_label_text = ...
    uicontrol('style','text','BackgroundColor','w','units','normalized', ...
    'Position',[0,0.5,0.5,0.2],'String','Probe label','FontSize',16);

gui_data.probe_label = ...
    uicontrol('style','edit','units','normalized', ...
    'BackgroundColor',[0.9,0.9,0.9], ...
    'Position',[0,0.3,0.5,0.2],'FontSize',14);

uicontrol('style','pushbutton','units','normalized', ...
    'Position',[0.5,0,0.5,1],'String','Add segment', ...
    'BackgroundColor',[0.9,0.9,1], ...
    'FontSize',14','Callback',{@add_probe_segment,gui_fig});

% Update gui data
guidata(gui_fig,gui_data);

end

function add_probe_segment(currentObject, eventdata, gui_fig)

        % Get gui data
        gui_data = guidata(gui_fig);
        histology_scroll_guidata = guidata(gui_data.histology_scroll_gui);

        % Draw probe segment line (or if no label, do nothing)
        probe_label = gui_data.probe_label.String;
        if isempty(probe_label)
            return
        end
        probe_line = drawline(histology_scroll_guidata.im_h.Parent,'color','red');

        % If the line is just a click, don't include
        curr_line_length = sqrt(sum(abs(diff(probe_line.Position,[],1)).^2));
        if curr_line_length == 0
            return
        end

        % Load processing and add fields if necessary
        load(histology_scroll_guidata.histology_processing_filename);
        
        if ~isfield(AP_histology_processing,'annotation')
            AP_histology_processing.annotation = struct;
        end
        if ~isfield(AP_histology_processing.annotation,'probe')
            AP_histology_processing.annotation.probe = ...
                struct('label',cell(0),'segments',cell(0));
        end
        
        % Find probe index in annotations, add segment
        probe_idx = find(strcmp(probe_label,[AP_histology_processing.annotation.probe.label]));
        if isempty(probe_idx)
            probe_idx = length(AP_histology_processing.annotation.probe)+1;
            AP_histology_processing.annotation.probe(probe_idx).label = probe_label;
            AP_histology_processing.annotation.probe(probe_idx).segments = ...
                cell(size(histology_scroll_guidata.data));
        end

        AP_histology_processing.annotation.probe(probe_idx).segments{histology_scroll_guidata.curr_im_idx} = ...
            probe_line.Position;

        % Save processing
        save(histology_scroll_guidata.histology_processing_filename, 'AP_histology_processing');

        % Delete line object, update histology image
        probe_line.delete;
        histology_scroll_guidata.update([],[],gui_data.histology_scroll_gui);

end




