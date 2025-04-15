function [atlas_slice,atlas_coords] = grab_atlas_slice(av,tv,atlas_vector,atlas_point,point_spacing)
% [atlas_slice,atlas_coords] = grab_atlas_slice(av,tv,atlas_vector,atlas_point,point_spacing)
%
% Find slice through CCF atlas given angle and point
%
% INPUTS: 
% av - annotated volume atlas
% tv - average volume atlas
% atlas_vector - unit vector giving view direction on atlas
% atlas_point - a 3D point for the slice plane to intersect
% point_spacing - the spacing of coordinates to return (high-res vs fast)
%
% OUTPUTS: 
% atlas_slice.av/.tv: slice through each atlas
% atlas_coords.ap/ml/dv: coordinates in CCF space for slice

% Get plane offset through point at given vector
plane_offset = -(atlas_vector*reshape(atlas_point,3,1));

% Define a plane of points to index
% (the plane grid is defined based on the which cardinal plan is most
% orthogonal to the plotted plane. this is janky but it works)

[~,cam_plane] = max(abs(atlas_vector./norm(atlas_vector)));

switch cam_plane
    
    % Note: ML and DV directions are flipped to match 2D histology and 3D
    % atlas axes, so make ML and DV coordinates go backwards for true CCF
    % coordinates
    
    case 1
        [plane_ml,plane_dv] = ...
            meshgrid(1:point_spacing:size(tv,3), ...
            1:point_spacing:size(tv,2));
        plane_ap = ...
            (atlas_vector(2)*plane_ml+atlas_vector(3)*plane_dv + plane_offset)/ ...
            -atlas_vector(1);
        
    case 2
        [plane_ap,plane_dv] = ...
            meshgrid(1:point_spacing:size(tv,1), ...
            1:point_spacing:size(tv,2));
        plane_ml = ...
            (atlas_vector(1)*plane_ap+atlas_vector(3)*plane_dv + plane_offset)/ ...
            -atlas_vector(2);
        
    case 3
        [plane_ap,plane_ml] = ...
            meshgrid(size(tv,1):-point_spacing:1, ...
            1:point_spacing:size(tv,3));
        plane_dv = ...
            (atlas_vector(1)*plane_ap+atlas_vector(2)*plane_ml + plane_offset)/ ...
            -atlas_vector(3);
        
end

% Get the coordiates on the plane
ap_idx = round(plane_ap);
ml_idx = round(plane_ml);
dv_idx = round(plane_dv);

% Find plane coordinates in bounds with the volume
% (CCF coordinates: [AP,DV,ML])
use_ap = ap_idx > 0 & ap_idx < size(tv,1);
use_dv = dv_idx > 0 & dv_idx < size(tv,2);
use_ml = ml_idx > 0 & ml_idx < size(tv,3);
use_idx = use_ap & use_ml & use_dv;

curr_slice_idx = sub2ind(size(tv),ap_idx(use_idx),dv_idx(use_idx),ml_idx(use_idx));

% Find plane coordinates that contain brain
curr_slice_isbrain = false(size(use_idx));
curr_slice_isbrain(use_idx) = av(curr_slice_idx) > 0;

% Index coordinates in bounds + with brain
grab_pix_idx = sub2ind(size(tv),ap_idx(curr_slice_isbrain),dv_idx(curr_slice_isbrain),ml_idx(curr_slice_isbrain));

% Grab pixels from (selected) volume
tv_slice = nan(size(use_idx));
tv_slice(curr_slice_isbrain) = tv(grab_pix_idx);

av_slice = nan(size(use_idx));
av_slice(curr_slice_isbrain) = av(grab_pix_idx);

% Package for output
atlas_slice = struct('tv',tv_slice,'av',av_slice);
atlas_coords = struct('ap',plane_ap,'ml',plane_ml,'dv',plane_dv);



















