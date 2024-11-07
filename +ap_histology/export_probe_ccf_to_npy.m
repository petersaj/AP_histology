function export_probe_ccf_to_npy(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Export probe CCF to npy

% Get images (from path in GUI)
histology_toolbar_guidata = guidata(histology_toolbar_gui);

save_path = histology_toolbar_guidata.save_path;
probe_filename = fullfile(save_path,'probe_ccf.mat');
load(probe_filename, 'probe_ccf');

if length(probe_ccf) == 1
    
    fname = fullfile(save_path, 'probe_ccf.traj_coords.npy');
    writeNPY(probe_ccf.trajectory_coords, fname);
    
    fname = fullfile(save_path, 'probe_ccf.points.npy');
    writeNPY(probe_ccf.points, fname);
    
else
    
    % Write probe_ccf coordinates as NPY file (separately for each shank)
    for iShank = 1:length(probe_ccf)
        fname = fullfile(save_path, sprintf('probe_ccf.traj_coords.shank%d.npy', iShank));
        writeNPY(probe_ccf(iShank).trajectory_coords, fname);
        
        fname = fullfile(save_path, sprintf('probe_ccf.points.shank%d.npy', iShank));
        writeNPY(probe_ccf(iShank).points, fname);
    end
end
fprintf("\nExported to npy files at %s \n", save_path)
end