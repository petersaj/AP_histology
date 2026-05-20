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
im_rotation = 0;
im_translation = [0,0];
im_reflect = [false,false];

% Translation/rotation
if isfield(AP_histology_processing,'rotation_angle')
    target_angle = round(nanmean(AP_histology_processing.rotation_angle)/90)*90;
    target_position = nanmean(AP_histology_processing.translation_center,1);

    im_rotation = target_angle - AP_histology_processing.rotation_angle(im_idx);
    im_translation = target_position - AP_histology_processing.translation_center(im_idx,:);
end

% Reflection
if isfield(AP_histology_processing,'flip')
    im_reflect = AP_histology_processing.flip(im_idx,:);
end

% Transform image
im_rigid_transformed = imrotate(imtranslate(im,im_translation),im_rotation,'nearest','crop');
if im_reflect(1)
    im_rigid_transformed = flipud(im_rigid_transformed);
end
if im_reflect(2)
    im_rigid_transformed = fliplr(im_rigid_transformed);
end

% This was to do affine2d method: faster, but hassle to deal with the
% output view
%
% % Create transform matrix
% tform_translation = transltform2d(im_translation);
% tform_rotation = rigidtform2d(im_rotation,[0,0]);
% tform_reflect = diag([reflect_h,reflect_v,1]);
% 
% tform_matrix = tform_translation.A*tform_rotation.A*tform_reflect;
% 
% % Warp image
% % (tform method)
% tform = affinetform2d;
% tform.A = tform_matrix;
% Rout = affineOutputView(size(im),tform,'BoundsStyle','CenterOutput');
% im_rigid_transformed = imwarp(im,tform,'interp','nearest','OutputView',Rout);









