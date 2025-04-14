function flip_slices(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Flip and re-order slice images

% Get histology toolbar data
histology_toolbar_guidata = guidata(histology_toolbar_gui);

figure('color','w','toolBar','none','menubar','none','Name','Slice flipper', ...
    'units','normalized','position', ...
    histology_toolbar_guidata.histology_scroll.Position./[1,1,2,3])

flipud_button = uicontrol('style','pushbutton','units','normalized', ...
    'Position',[0,0,0.5,1],'String','Flip U/D', ...
    'Callback',{@slice_flipud,histology_toolbar_gui});

fliplr_button = uicontrol('style','pushbutton','units','normalized', ...
    'Position',[0.5,0,0.5,1],'String','Flip L/R', ...
    'Callback',{@slice_fliplr,histology_toolbar_gui});


histology_scroll_guidata = guidata(histology_toolbar_guidata.histology_scroll);

% Initialize flip flag
load(histology_toolbar_guidata.histology_processing_filename);
AP_histology_processing.flip = false(length(histology_scroll_guidata.data),2);
save(histology_toolbar_guidata.histology_processing_filename,'AP_histology_processing');

end

function slice_flipud(~,~,histology_toolbar_gui)

% Get histology toolbar data
histology_toolbar_guidata = guidata(histology_toolbar_gui);

% Get histology scroll data
histology_scroll_guidata = guidata(histology_toolbar_guidata.histology_scroll);

% Set flip flag, save
load(histology_toolbar_guidata.histology_processing_filename);
AP_histology_processing.flip(histology_scroll_guidata.curr_im,1) = ...
    ~AP_histology_processing.flip(histology_scroll_guidata.curr_im,1);
save(histology_toolbar_guidata.histology_processing_filename,'AP_histology_processing');

% Update histology image
histology_scroll_guidata.update([],[],histology_toolbar_guidata.histology_scroll);

end

function slice_fliplr(~,~,histology_toolbar_gui)

% Get histology toolbar data
histology_toolbar_guidata = guidata(histology_toolbar_gui);

% Get histology scroll data
histology_scroll_guidata = guidata(histology_toolbar_guidata.histology_scroll);

% Set flip flag, save
load(histology_toolbar_guidata.histology_processing_filename);
AP_histology_processing.flip(histology_scroll_guidata.curr_im,2) = ...
    ~AP_histology_processing.flip(histology_scroll_guidata.curr_im,2);
save(histology_toolbar_guidata.histology_processing_filename,'AP_histology_processing');

% Update histology image
histology_scroll_guidata.update([],[],histology_toolbar_guidata.histology_scroll);

end



