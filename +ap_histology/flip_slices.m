function flip_slices(~,~,histology_gui)
% Part of AP_histology toolbox
%
% Flip slices

% Get histology toolbar data
histology_guidata = guidata(histology_gui);

fig_height = histology_gui.Position(4)/4;
fig_width = fig_height;
fig_x = histology_gui.Position(1);
fig_y = sum(histology_gui.Position([2,4])) - fig_height;
fig_position = [fig_x,fig_y,fig_width,fig_height];

figure('color','w','toolBar','none','menubar','none','Name','Slice flipper', ...
    'units','normalized','position',fig_position);

flipud_button = uicontrol('style','pushbutton','units','normalized', ...
    'Position',[0,0,0.5,1],'String','Flip U/D', ...
    'Callback',{@slice_flip,histology_gui,1});

fliplr_button = uicontrol('style','pushbutton','units','normalized', ...
    'Position',[0.5,0,0.5,1],'String','Flip L/R', ...
    'Callback',{@slice_flip,histology_gui,2});

% Initialize flip flag
load(histology_guidata.histology_processing_filename);
if ~isfield(AP_histology_processing,'flip')
    AP_histology_processing.flip = false(length(histology_guidata.data),2);
    save(histology_guidata.histology_processing_filename,'AP_histology_processing');
end

end

function slice_flip(~,~,histology_gui,flip_dim)

% Get histology scroll data
histology_guidata = guidata(histology_gui);

% Set flip flag, save
load(histology_guidata.histology_processing_filename);
AP_histology_processing.flip(histology_guidata.curr_im_idx,flip_dim) = ...
    ~AP_histology_processing.flip(histology_guidata.curr_im_idx,flip_dim);
save(histology_guidata.histology_processing_filename,'AP_histology_processing');

% Update histology image
histology_guidata.update([],[],histology_gui);

end



