function ccf_points = AP_histology2ccf(histology_points,slice_im_path)
% Transform coordinates on histology slices to CCF location
%
% Inputs: 
% histology_points - n images x 1 cell array of points to convert, each
% cell contains n points x 2 ([x,y]). E.g., for two slices: 
% {[100,200]},{[]} will convert the point x = 100, y = 200 on the first
% slide into CCF coordinates
%
% Outputs
% ccf_points = cell array with CCF coordinates corresponding to
% histology_points (note: in native CCF order [AP/DV/ML])

% Load corresponding CCF slices
ccf_slice_fn = [slice_im_path filesep 'histology_ccf.mat'];
load(ccf_slice_fn);

% Load histology/CCF alignment
ccf_alignment_fn = [slice_im_path filesep 'atlas2histology_tform.mat'];
load(ccf_alignment_fn);

ccf_points = cell(length(atlas2histology_tform),1);
for curr_slice = find(~cellfun(@isempty,histology_points))
    
    % Transform histology to atlas slice
    tform = affine2d;
    tform.T = atlas2histology_tform{curr_slice};
    % (transform is CCF -> histology, invert for other direction)
    tform = invert(tform);
    
    % Transform and round to nearest index
    [histology_points_atlas_x,histology_points_atlas_y] = ...
        transformPointsForward(tform, ...
        histology_points{curr_slice}(:,1), ...
        histology_points{curr_slice}(:,2));
    
    histology_points_atlas_x = round(histology_points_atlas_x);
    histology_points_atlas_y = round(histology_points_atlas_y);
    
    probe_points_atlas_idx = sub2ind(size(histology_ccf(curr_slice).av_slices), ...
        histology_points_atlas_y,histology_points_atlas_x);
    
    % Get CCF coordinates for histology coordinates (CCF in AP,DV,ML)
    ccf_points{curr_slice} = ...
        [histology_ccf(curr_slice).plane_ap(probe_points_atlas_idx), ...
        histology_ccf(curr_slice).plane_dv(probe_points_atlas_idx), ...
        histology_ccf(curr_slice).plane_ml(probe_points_atlas_idx)];
    
end
