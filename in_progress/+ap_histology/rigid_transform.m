function im_rigid_transformed = rigid_transform(im,im_idx,AP_histology_processing)
% im_rigid_transformed = rigid_transform(im,im_idx,AP_histology_processing)
%
% Apply pre-saved rigid transforms (translate, rotate, scale) to histology
% image. 
%
% INPUTS
% im - raw image
% im_idx - numbered index for image (e.g. slice 5)
% AP_histology_processing - processing structure

% Initialize transform parameters
rotation = 0;
translation = 0;
reflect_h = 1;
reflect_v = 1;

% Translation/rotation
if isfield(AP_histology_processing,'rotation_angle')
    target_angle = round(nanmean(AP_histology_processing.rotation_angle)/90)*90;
    target_position = nanmean(AP_histology_processing.translation_center,1);

    rotation = AP_histology_processing.rotation_angle(im_idx) - target_angle;
    translation = target_position - AP_histology_processing.translation_center(im_idx,:);
end

% Reflection
if isfield(AP_histology_processing,'flip')
    if AP_histology_processing.flip(im_idx,1)
        reflect_v = -1;
    end
    if AP_histology_processing.flip(im_idx,2)
        reflect_h = -1;
    end
end

% Create transform matrix
tform_translation = transltform2d(translation);
tform_rotation = rigidtform2d(rotation,[0,0]);
tform_reflect = diag([reflect_h,reflect_v,1]);

tform_matrix = tform_translation.A*tform_rotation.A*tform_reflect;

% Warp image
tform = affinetform2d;
tform.A = tform_matrix;
Rout = affineOutputView(size(im),tform,'BoundsStyle','CenterOutput');

im_rigid_transformed = imwarp(im,tform,'interp','nearest','OutputView',Rout);










