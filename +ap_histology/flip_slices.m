function flip_slices(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Flip and re-order slice images

% Get histology toolbar data
histology_toolbar_guidata = guidata(histology_toolbar_gui);

fig_height = histology_scroll_gui.Position(4)/4;
fig_width = fig_height;
fig_x = histology_scroll_gui.Position(1);
fig_y = sum(histology_scroll_gui.Position([2,4])) - fig_height;
fig_position = [fig_x,fig_y,fig_width,fig_height];

figure('color','w','toolBar','none','menubar','none','Name','Slice flipper', ...
    'units','normalized','position',fig_position);

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



