function rotate_center_slices(~,~,histology_gui)
% Part of AP_histology toolbox
%
% Rotate and center slices

% User confirm
user_confirm = questdlg('Set new rotate/center parameters?','Confirm','Yes','No','No');
if strcmpi(user_confirm,'no')
    return
end

% Get gui data
histology_guidata = guidata(histology_gui);

% Load processing data, remove rotation/translation fields if extant
load(histology_guidata.histology_processing_filename);
if isfield(AP_histology_processing,'rotation_angle')
    AP_histology_processing = rmfield(AP_histology_processing, ...
        {'rotation_angle','translation_center'});
end
save(histology_guidata.histology_processing_filename,'AP_histology_processing');

% Loop through images and draw reference line
align_axis = nan(2,2,length(histology_guidata.data));
for curr_im = 1:length(histology_guidata.data)

    histology_guidata.curr_im = curr_im;
    guidata(histology_gui,histology_guidata);
    histology_guidata.update([],[],histology_gui,'Draw reference line')

    curr_line = drawline('color','w','linewidth',4);
    align_axis(:,:,curr_im) = curr_line.Position;
    curr_line.delete;

end

% Get angle for all axes
align_angle = squeeze(atan2d(diff(align_axis(:,1,:),[],1),diff(align_axis(:,2,:),[],1)));
align_center = permute(nanmean(align_axis,1),[3,2,1]);

% Load processing and save rotations
load(histology_guidata.histology_processing_filename);

AP_histology_processing.rotation_angle = align_angle;
AP_histology_processing.translation_center = align_center;
save(histology_guidata.histology_processing_filename,'AP_histology_processing');

histology_guidata.update([],[],histology_gui,'Saved rotation/centering')




