function [image_aligned_binmax,ccf_bin_edges] = bin_aligned_images(histology_path,atlas_orientation,atlas_bin_size)
% bin_aligned_images(histology_path,atlas_orientation,atlas_bin_size)
%
% Align histology images to CCF, get maximum within CCF bins
% 
% INPUTS
% histology_path - path to AP histology processing file
% atlas_orientation - 1: AP, 2: DV, 3: ML (default = 1)
% atlas_bin_size - scalar = size of CCF bin, vector = CCF bin edges to use
%
% OUTPUTS
% image_aligned_binmax - pixels x pixels x bin x channel array of maximum
% channel fluorescence within CCF bins
% ccf_bin_edges - edges of CCF bins to generate max image

arguments
    histology_path = []
    atlas_orientation = 1
    atlas_bin_size = 100
end

% Load atlas and processing file
[av,tv] = ap_histology.load_ccf;
load(fullfile(histology_path,'AP_histology_processing.mat'));

% Load images
image_path = histology_path;
image_dir = dir(fullfile(image_path,'*.tif'));
image_filenames = cellfun(@(path,name) fullfile(path,name), ...
    {image_dir.folder},{image_dir.name},'uni',false);
[~,sort_idx] = ap_histology.natsortfiles(image_filenames);

images = cell(size(image_dir));
for curr_im = 1:length(sort_idx)
    images{curr_im} = tiffreadVolume( ...
        image_filenames{sort_idx(curr_im)});
end

% Grab atlas images and histology-aligned coordinates
n_slices = length(images);
slice_atlas = struct('tv',cell(n_slices,1), 'av',cell(n_slices,1));
slice_atlas_ccf = struct('ap',cell(n_slices,1),'ml',cell(n_slices,1),'dv',cell(n_slices,1));
for curr_slice = 1:length(images)
    [slice_atlas(curr_slice),slice_atlas_ccf(curr_slice)] = ...
        ap_histology.grab_atlas_slice(av,tv, ...
        AP_histology_processing.histology_ccf.slice_vector, ...
        AP_histology_processing.histology_ccf.slice_points(curr_slice,:), 1);
end

% Build volume of histology images
n_channels = max(cellfun(@(x) size(x,3),images));
histology_volume = zeros([size(tv),n_channels],'single');
for curr_channel = 1:n_channels
    for curr_im_idx = 1:length(images)

        % Rigid transform
        im_rigid_transformed = ap_histology.rigid_transform( ...
            images{curr_im_idx}(:,:,curr_channel),curr_im_idx,AP_histology_processing);

        % Affine/nonlin transform
        if isfield(AP_histology_processing.histology_ccf,'control_points') && ...
                (size(AP_histology_processing.histology_ccf.control_points.histology{curr_im_idx},1) == ...
                size(AP_histology_processing.histology_ccf.control_points.atlas{curr_im_idx},1)) && ...
                size(AP_histology_processing.histology_ccf.control_points.histology{curr_im_idx},1) >= 3
            % Manual alignment (if >3 matched points)
            histology2atlas_tform = fitgeotform2d( ...
                AP_histology_processing.histology_ccf.control_points.histology{curr_im_idx}, ...
                AP_histology_processing.histology_ccf.control_points.atlas{curr_im_idx},'pwl');
        elseif isfield(AP_histology_processing.histology_ccf,'atlas2histology_tform')
            % Automatic alignment
            histology2atlas_tform = invert(AP_histology_processing.histology_ccf.atlas2histology_tform{curr_im_idx});
        end

        atlas_slice_aligned = imwarp(im_rigid_transformed, ...
            histology2atlas_tform,'nearest','OutputView', ...
            imref2d(size(slice_atlas(curr_im_idx).av)));

        % % Check match (for debugging)
        % figure; imshowpair(slice_atlas(curr_im_idx).av,atlas_slice_aligned);

        % Add points to volume in CCF space
        curr_ccf_idx = sub2ind([size(tv),n_channels], ...
            round(slice_atlas_ccf(curr_im_idx).ap(:)), ...
            round(slice_atlas_ccf(curr_im_idx).dv(:)), ...
            round(slice_atlas_ccf(curr_im_idx).ml(:)), ...
            curr_channel);

        histology_volume(curr_ccf_idx) = histology_volume(curr_ccf_idx) + ...
            single(atlas_slice_aligned(:));
    end
end

% Get max of histology volume in atlas bins
if isscalar(atlas_bin_size)
    ccf_bin_edges = 1:atlas_bin_size:size(av,atlas_orientation);
else
    ccf_bin_edges = atlas_bin_size;
end

image_aligned_binmax = zeros([size(squeeze(max(av,[],atlas_orientation))),length(ccf_bin_edges)-1,n_channels]);
for curr_channel = 1:n_channels
    for curr_atlas_bin = 1:length(ccf_bin_edges)-1
        curr_ap = 1:size(tv,1);
        curr_dv = 1:size(tv,2);
        curr_ml = 1:size(tv,3);
        switch atlas_orientation
            case 1
                curr_ap = ccf_bin_edges(curr_atlas_bin):ccf_bin_edges(curr_atlas_bin+1);
            case 2
                curr_dv = ccf_bin_edges(curr_atlas_bin):ccf_bin_edges(curr_atlas_bin+1);
            case 3
                curr_ml = ccf_bin_edges(curr_atlas_bin):ccf_bin_edges(curr_atlas_bin+1);
        end
        image_aligned_binmax(:,:,curr_atlas_bin,curr_channel) = ...
            squeeze(max(histology_volume(curr_ap,curr_dv,curr_ml,curr_channel), ....
            [],atlas_orientation));
    end
end


