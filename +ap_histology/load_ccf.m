function [av,tv,st] = load_ccf
% [av,tv,st] = load_ccf
%
% Load Allen CCF atlas

allen_atlas_path = fileparts(which('template_volume_10um.npy'));
if isempty(allen_atlas_path)
    error('No CCF atlas found (add CCF atlas to path)')
end
tv = readNPY(fullfile(allen_atlas_path,'template_volume_10um.npy'));
av = readNPY(fullfile(allen_atlas_path,'annotation_volume_10um_by_index.npy'));
st = ap_histology.loadStructureTree(fullfile(allen_atlas_path,'structure_tree_safe_2017.csv'));

end