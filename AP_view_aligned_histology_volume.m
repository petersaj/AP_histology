function AP_view_aligned_histology_volume(tv,av,st,slice_im_path,channel)
% AP_view_aligned_histology_volume(tv,av,st,slice_im_path,channel)
%
% Plot histology warped onto CCF volume
% Andy Peters (peters.andrew.j@gmail.com)
%
% channel - channel (color) to threshold and plot

% Initialize guidata
gui_data = struct;
gui_data.tv = tv;
gui_data.av = av;
gui_data.st = st;

% Load in slice images
gui_data.slice_im_path = slice_im_path;
slice_im_dir = dir([slice_im_path filesep '*.tif']);
slice_im_fn = natsortfiles(cellfun(@(path,fn) [path filesep fn], ...
    {slice_im_dir.folder},{slice_im_dir.name},'uni',false));
gui_data.slice_im = cell(length(slice_im_fn),1);
for curr_slice = 1:length(slice_im_fn)
    gui_data.slice_im{curr_slice} = imread(slice_im_fn{curr_slice});
end

% Load corresponding CCF slices
ccf_slice_fn = [slice_im_path filesep 'histology_ccf.mat'];
load(ccf_slice_fn);
gui_data.histology_ccf = histology_ccf;

% Load histology/CCF alignment
ccf_alignment_fn = [slice_im_path filesep 'atlas2histology_tform.mat'];
load(ccf_alignment_fn);
gui_data.histology_ccf_alignment = atlas2histology_tform;

% Warp histology to CCF
gui_data.atlas_aligned_histology = cell(length(gui_data.slice_im),1);
for curr_slice = 1:length(gui_data.slice_im)
    curr_av_slice = gui_data.histology_ccf(curr_slice).av_slices;
    curr_av_slice(isnan(curr_av_slice)) = 1;
    curr_slice_im = gui_data.slice_im{curr_slice};
    
    tform = affine2d;
    tform.T = gui_data.histology_ccf_alignment{curr_slice};
    % (transform is CCF -> histology, invert for other direction)
    tform = invert(tform);

    tform_size = imref2d([size(gui_data.histology_ccf(curr_slice).av_slices,1), ...
        size(gui_data.histology_ccf(curr_slice).av_slices,2)]);
    
    gui_data.atlas_aligned_histology{curr_slice} = ...
        imwarp(curr_slice_im,tform,'nearest','OutputView',tform_size);
    
end

% Create figure
gui_fig = figure;

% Set up 3D plot for volume viewing
axes_atlas = axes;
[~, brain_outline] = plotBrainGrid([],axes_atlas);
set(axes_atlas,'YDir','reverse','ZDir','reverse');
hold(axes_atlas,'on');
axis vis3d equal off manual
view([-30,25]);
caxis([0 300]);
[ap_max,dv_max,ml_max] = size(tv);
xlim([-10,ap_max+10])
ylim([-10,ml_max+10])
zlim([-10,dv_max+10])

switch channel
    case 1
        colormap(brewermap([],'Reds'));
    case 2
        colormap(brewermap([],'Greens'));
    case 3
        colormap(brewermap([],'Blues'));
end

% Turn on rotation by default
h = rotate3d(axes_atlas);
h.Enable = 'on';

% Draw all aligned slices
histology_surf = gobjects(length(gui_data.slice_im),1);
for curr_slice = 1:length(gui_data.slice_im)
    
    % Get thresholded image
    curr_slice_im = gui_data.atlas_aligned_histology{curr_slice}(:,:,channel);
    slice_alpha = curr_slice_im;
    value_thresh = 100;
    
    % Draw if thresholded pixels (ignore if not)
    if any(curr_slice_im(:) > value_thresh)
        % Draw a surface at CCF coordinates
        histology_surf(curr_slice) = surface( ...
            gui_data.histology_ccf(curr_slice).plane_ap, ...
            gui_data.histology_ccf(curr_slice).plane_ml, ...
            gui_data.histology_ccf(curr_slice).plane_dv);
        
        % Draw the slice on the surface
        histology_surf(curr_slice).FaceColor = 'texturemap';
        histology_surf(curr_slice).EdgeColor = 'none';
        histology_surf(curr_slice).CData = gui_data.atlas_aligned_histology{curr_slice}(:,:,channel);
        
        % Set the alpha data
        max_alpha = 0.5;
        slice_alpha = mat2gray(curr_slice_im,[value_thresh,double(max(curr_slice_im(:)))])*max_alpha;
        histology_surf(curr_slice).FaceAlpha = 'texturemap';
        histology_surf(curr_slice).AlphaDataMapping = 'none';
        histology_surf(curr_slice).AlphaData = slice_alpha;
        
        drawnow;
    end
end


% % Attempt plotting as 3D surface
% 
% keyboard
% 
% thresh_volume = false(size(tv));
% 
% for curr_slice = 1:length(gui_data.slice_im)
%     
%     % Get thresholded image
%     curr_slice_im = gui_data.atlas_aligned_histology{curr_slice}(:,:,channel);
%     slice_alpha = curr_slice_im;
%     slice_alpha(slice_alpha < 100) = 0;
%     
%     slice_thresh = curr_slice_im > 200;
%     
%     slice_thresh_ap = round(gui_data.histology_ccf(curr_slice).plane_ap(slice_thresh));
%     slice_thresh_dv = round(gui_data.histology_ccf(curr_slice).plane_dv(slice_thresh));
%     slice_thresh_ml = round(gui_data.histology_ccf(curr_slice).plane_ml(slice_thresh));
%     
%     thresh_idx = sub2ind(size(tv),slice_thresh_ap,slice_thresh_dv,slice_thresh_ml);
%     thresh_volume(thresh_idx) = true;
%     
% end
% 
% thresh_volume_dilate = imdilate(thresh_volume,strel('sphere',5));
% 
% sphere_size = (4/3)*pi*5^3;
% a = bwareaopen(thresh_volume_dilate,round(sphere_size*20));
% b = imdilate(a,strel('sphere',5));
% c = imresize3(+b,1/10,'nearest');
% 
% ap = linspace(1,size(tv,1),size(c,1));
% dv = linspace(1,size(tv,2),size(c,2));
% ml = linspace(1,size(tv,3),size(c,3));
% 
% figure;
% plotBrainGrid([],gca); hold on;
% isosurface(ap,ml,dv,permute(c,[3,1,2]));
% camlight;










