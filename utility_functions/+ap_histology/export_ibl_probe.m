function export_ibl_probe(~,~,histology_gui)
% Convert probe CCF coordinates into IBL-standard file to load into IBL
% ephys processing pipeline (thanks Guido Meijer for help with IBL)
%
% IBL expects: [AP,ML,DV] in meters from bregma
% saved in a folder by probe (probe00,probe01...)
% into a file xyz_picks.json
%
% Multiple shanks currently not supported: IBL expects separate files as
% xyz_picks_shank1.json, xyz_picks_shank2.json etc.

% Get gui data and update status
histology_guidata = guidata(histology_gui);
histology_guidata.update([],[],histology_gui,'Saving annotations as IBL-formatted probe coordinates...');

% Set save path (same as folder with histology_processing)
save_path = fullfile(fileparts(histology_guidata.histology_processing_filename),'IBL_probe_coordinates');

% Fit line through probe points, return [insertion;tip]
probe_line_fits = ap_histology.fit_probe_line(histology_guidata.histology_processing_filename);

% Convert CCF to IBL coordinates standard: [AP,ML,DV] in meters
ibl_bregma_ccf = [540, 44, 570];
probe_line_fits_ibl = cellfun(@(x) ...
    (x(:,[1,3,2])-ibl_bregma_ccf([1,3,2]))*10/1000, ...
    {probe_line_fits.ccf},'uni',false);

for curr_probe = 1:length(probe_line_fits_ibl)
    xyz_picks_struct = struct('xyz_picks', probe_line_fits_ibl{curr_probe});

    save_filename = fullfile(save_path,sprintf('probe%02d',curr_probe-1),'xyz_picks.json');
    mkdir(fileparts(save_filename));

    writelines(jsonencode(xyz_picks_struct),save_filename);
end

histology_guidata.update([],[],histology_gui, ...
    {'Saved IBL probe coordinates into: ',save_path});
