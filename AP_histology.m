function AP_histology
% Toolbar GUI for running histology pipeline

% Set up the gui
screen_size_px = get(0,'screensize');
gui_aspect_ratio = 5; % width/length
gui_width_fraction = 0.5; % fraction of screen width to occupy
gui_border = 50; % border from gui to screen edge
gui_width_px = screen_size_px(3).*gui_width_fraction;
gui_height_px = gui_width_px/gui_aspect_ratio;
gui_position = [...
    gui_border, ... % left x
    screen_size_px(4)-(gui_height_px+gui_border+50), ... % bottom y
    gui_width_px,gui_height_px]; % width, height

histology_toolbar_gui = figure('Toolbar','none','Menubar','none','color','w', ...
    'Name','AP Histology', ...
    'Units','pixels','Position',gui_position);

% Set up the text to display coordinates
gui_data.gui_text = annotation('textbox','String','','interpreter','none', ...
    'Units','normalized','Position',[0,0,1,1],'VerticalAlignment','top', ...
    'FontSize',12,'FontName','Consolas','PickableParts','none');

% File menu
file_menu = uimenu(histology_toolbar_gui,'Text','File selection');
uimenu(file_menu,'Text','Set image path','MenuSelectedFcn',{@set_image_path,histology_toolbar_gui});
uimenu(file_menu,'Text','Set save path','MenuSelectedFcn',{@set_save_path,histology_toolbar_gui});

% Preprocessing menu
preprocess_menu = uimenu(histology_toolbar_gui,'Text','Image preprocessing');
uimenu(preprocess_menu,'Text','Create slice images','MenuSelectedFcn', ...
    {@ap_histology.create_slice_images,histology_toolbar_gui});
uimenu(preprocess_menu,'Text','Rotate & center slices','MenuSelectedFcn', ...
    {@ap_histology.rotate_center_slices,histology_toolbar_gui});
uimenu(preprocess_menu,'Text','Flip & re-order slices','MenuSelectedFcn', ...
    {@ap_histology.flip_reorder_slices,histology_toolbar_gui});

% Atlas menu
atlas_menu = uimenu(histology_toolbar_gui,'Text','Atlas alignment');
uimenu(atlas_menu,'Text','Choose histology atlas slices','MenuSelectedFcn', ...
    {@ap_histology.match_histology_atlas,histology_toolbar_gui});
uimenu(atlas_menu,'Text','Auto-align histology/atlas slices','MenuSelectedFcn', ...
    {@ap_histology.align_auto_histology_atlas,histology_toolbar_gui});
uimenu(atlas_menu,'Text','Manual align histology/atlas slices','MenuSelectedFcn', ...
    {@ap_histology.align_manual_histology_atlas,histology_toolbar_gui});

% Annotation menu
annotation_menu = uimenu(histology_toolbar_gui,'Text','Annotation');
uimenu(annotation_menu,'Text','Neuropixels probes','MenuSelectedFcn', ...
    {@ap_histology.annotate_neuropixels,histology_toolbar_gui});

% View menu
view_menu = uimenu(histology_toolbar_gui,'Text','View');
uimenu(view_menu,'Text','View aligned histology','MenuSelectedFcn', ...
    {@ap_histology.view_aligned_histology,histology_toolbar_gui});

% Create GUI variables
gui_data.image_path = char;
gui_data.save_path = char;

% Store guidata
guidata(histology_toolbar_gui,gui_data);

% Update GUI text
update_text(histology_toolbar_gui);

end

function set_image_path(h,eventdata,histology_toolbar_gui)

% Get guidata
gui_data = guidata(histology_toolbar_gui);

% Pick image path
gui_data.image_path = uigetdir([],'Select path with raw images');

% Store guidata
guidata(histology_toolbar_gui,gui_data);

% Update GUI text
update_text(histology_toolbar_gui);

end

function set_save_path(h,eventdata,histology_toolbar_gui)

% Get guidata
gui_data = guidata(histology_toolbar_gui);

% Pick image path
gui_data.save_path = uigetdir([],'Select path to save processing');

% Store guidata
guidata(histology_toolbar_gui,gui_data);

% Update GUI text
update_text(histology_toolbar_gui);

end


function update_text(histology_toolbar_gui)

% Get guidata
gui_data = guidata(histology_toolbar_gui);

% Set text
image_path_text = sprintf('Image path: %s',gui_data.image_path);
save_path_text = sprintf('Save path:  %s',gui_data.save_path);

gui_text = {image_path_text,save_path_text};
set(gui_data.gui_text,'String',gui_text);

end



















