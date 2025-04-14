function AP_histology_v2
% Toolbar GUI for running histology pipeline

% Set up the gui
screen_size_px = get(0,'screensize');
gui_aspect_ratio = 1.5; % width/length
gui_width_fraction = 0.4; % fraction of screen width to occupy
gui_border = 50; % border from gui to screen edge
gui_width_px = screen_size_px(3).*gui_width_fraction;
gui_height_px = gui_width_px/gui_aspect_ratio;
gui_position = [...
    gui_border, ... % left x
    screen_size_px(4)-(gui_height_px+gui_border+50), ... % bottom y
    gui_width_px,gui_height_px]; % width, height

histology_toolbar_gui = figure('Toolbar','none','Menubar','none','color','w', ...
    'Name','AP Histology v2', ...
    'Units','pixels','Position',gui_position);

% Set up the text to display coordinates
gui_data.gui_text = annotation('textbox','String','','interpreter','tex', ...
    'Units','normalized','Position',[0,0,1,1],'VerticalAlignment','top', ...
    'FontSize',12,'FontName','Consolas','PickableParts','none');

% File menu
gui_data.menu.file = uimenu(histology_toolbar_gui,'Text','Images');
uimenu(gui_data.menu.file,'Text','Open images','MenuSelectedFcn',{@open_images,histology_toolbar_gui});

% Preprocessing menu
gui_data.menu.preprocess = uimenu(histology_toolbar_gui,'Text','Image preprocessing');
uimenu(gui_data.menu.preprocess,'Text','Create slice images','MenuSelectedFcn', ...
    {@ap_histology.create_slice_images,histology_toolbar_gui},'enable','off');
uimenu(gui_data.menu.preprocess,'Text','Rotate & center slices','MenuSelectedFcn', ...
    {@ap_histology.rotate_center_slices,histology_toolbar_gui});
uimenu(gui_data.menu.preprocess,'Text','Re-order slices','MenuSelectedFcn', ...
    {@ap_histology.reorder_slices,histology_toolbar_gui});
uimenu(gui_data.menu.preprocess,'Text','Flip slices','MenuSelectedFcn', ...
    {@ap_histology.flip_slices,histology_toolbar_gui});

% Atlas menu
gui_data.menu.atlas = uimenu(histology_toolbar_gui,'Text','Atlas alignment');
uimenu(gui_data.menu.atlas,'Text','Choose histology atlas slices','MenuSelectedFcn', ...
    {@ap_histology.match_histology_atlas,histology_toolbar_gui});
uimenu(gui_data.menu.atlas,'Text','Auto-align histology/atlas slices','MenuSelectedFcn', ...
    {@ap_histology.align_auto_histology_atlas,histology_toolbar_gui});
uimenu(gui_data.menu.atlas,'Text','Manual align histology/atlas slices','MenuSelectedFcn', ...
    {@ap_histology.align_manual_histology_atlas,histology_toolbar_gui});

% Annotation menu
gui_data.menu.annotation = uimenu(histology_toolbar_gui,'Text','Annotation');
uimenu(gui_data.menu.annotation,'Text','Neuropixels probes','MenuSelectedFcn', ...
    {@ap_histology.annotate_neuropixels,histology_toolbar_gui});

% View menu
gui_data.menu.view = uimenu(histology_toolbar_gui,'Text','View');
uimenu(gui_data.menu.view,'Text','View aligned histology','MenuSelectedFcn', ...
    {@ap_histology.view_aligned_histology,histology_toolbar_gui});

% Create GUI variables
gui_data.image_path = char;
gui_data.save_path = char;

% Store guidata
guidata(histology_toolbar_gui,gui_data);

% Update GUI text
ap_histology.update_toolbar_gui(histology_toolbar_gui);

end

function open_images(h,eventdata,histology_toolbar_gui)

% Get guidata
gui_data = guidata(histology_toolbar_gui);

% Pick image path
gui_data.image_path = uigetdir([],'Select path with raw images');

if gui_data.image_path == 0
    return
end

% Set save filename, create file if it doesn't exist
gui_data.histology_processing_filename = fullfile(gui_data.image_path,'AP_histology_processing.mat');

if ~exist(gui_data.histology_processing_filename,'file')
    AP_histology_processing = struct;
    save(gui_data.histology_processing_filename,'AP_histology_processing');
end

% Open histology image scroller
gui_data.histology_scroll = ap_histology.histology_scroll(gui_data.image_path);

% Store guidata
guidata(histology_toolbar_gui,gui_data);

% Update GUI text
ap_histology.update_toolbar_gui(histology_toolbar_gui);



end






















