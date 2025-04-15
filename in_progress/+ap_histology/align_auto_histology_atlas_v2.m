function align_auto_histology_atlas_v2(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Auto aligns histology slices and matched CCF slices by outline registration

% Get gui data
histology_toolbar_guidata = guidata(histology_toolbar_gui);
histology_scroll_data = guidata(histology_toolbar_guidata.histology_scroll);

% Grab slice images from histology scroller
bw_clim = [min(histology_scroll_data.clim(:,1)), ...
    max(histology_scroll_data.clim(:,2))];

slice_histology = cell(size(histology_scroll_data.data));
for curr_slice = 1:length(histology_scroll_data.data)
    curr_slice_chanmax = max(histology_scroll_data.data{curr_slice},[],3);
    
    slice_histology{curr_slice} = ...
        min(max(curr_slice_chanmax-bw_clim(1),0),diff(bw_clim));
end

% Load atlas
allen_atlas_path = fileparts(which('template_volume_10um.npy'));
if isempty(allen_atlas_path)
    error('No CCF atlas found (add CCF atlas to path)')
end
disp('Loading Allen CCF atlas...')
tv = readNPY(fullfile(allen_atlas_path,'template_volume_10um.npy'));
av = readNPY(fullfile(allen_atlas_path,'annotation_volume_10um_by_index.npy'));
st = ap_histology.loadStructureTree(fullfile(allen_atlas_path,'structure_tree_safe_2017.csv'));
disp('Done.')

% Get atlas images
load(histology_toolbar_guidata.histology_processing_filename);

slice_atlas = struct('tv',cell(size(histology_scroll_data.data)), 'av',cell(size(histology_scroll_data.data)));
for curr_slice = 1:length(histology_scroll_data.data)
    slice_atlas(curr_slice) = ...
        ap_histology.grab_atlas_slice(av,tv, ...
        AP_histology_processing.histology_ccf.slice_vector, ...
        AP_histology_processing.histology_ccf.slice_points(curr_slice,:), 1);
end

% Binarize slices (only necessary if aligning outlines)
slice_thresh = graythresh(cell2mat(cellfun(@(x) reshape(x(x~=0),[],1),slice_histology,'uni',false)));
slice_histology_binary = cellfun(@(x) imbinarize(x,slice_thresh),slice_histology,'uni',false);

% Align outlines of histology/atlas slices
atlas_align_borders = cell(size(slice_histology));
atlas2histology_tform = cell(size(slice_histology));

waitbar_h = waitbar(0,'Aligning atlas/histology slices...');
for curr_slice = 1:length(slice_histology)

    % To align anatomy:
    curr_histology_slice = slice_histology{curr_slice};
    curr_atlas_slice = slice_atlas(curr_slice).tv;
    curr_atlas_slice(isnan(curr_atlas_slice)) = 0;
    [optimizer, metric] = imregconfig('multimodal');
    optimizer.MaximumIterations = 200;
    optimizer.GrowthFactor = 1+1e-3;
    optimizer.InitialRadius = 1e-3;

%     % To align outlines:
%     curr_histology_slice = +slice_histology_binary{curr_slice};
%     curr_atlas_slice = +(histology_ccf(curr_slice).av_slices > 1);
%     [optimizer, metric] = imregconfig('monomodal');
%     optimizer.MaximumIterations = 200;
%     optimizer.MaximumStepLength = 1e-2;
%     optimizer.GradientMagnitudeTolerance = 1e-5;
%     optimizer.RelaxationFactor = 1e-1;

    % Resize atlas outline to approximately match histology, affine-align
    resize_factor = min(size(curr_histology_slice)./size(curr_atlas_slice));
    curr_atlas_slice_resize = imresize(curr_atlas_slice,resize_factor,'nearest');

    % Do alignment on downsampled images (faster and more accurate)
    downsample_factor = 5;

    tformEstimate_affine_resized = ...
        imregtform( ...
        imresize(curr_atlas_slice_resize,1/downsample_factor,'nearest'), ...
        imresize(curr_histology_slice,1/downsample_factor,'nearest'), ...
        'affine',optimizer,metric,'PyramidLevels',3);

    % Set final transform (scale to histology, downscale, affine, upscale)
    scale_match = eye(3).*[repmat(resize_factor,2,1);1];
    scale_align_down = eye(3).*[repmat(1/downsample_factor,2,1);1];
    scale_align_up = eye(3).*[repmat(downsample_factor,2,1);1];

    tformEstimate_affine = tformEstimate_affine_resized;
    tformEstimate_affine.T = scale_match*scale_align_down* ...
        tformEstimate_affine_resized.T*scale_align_up;

    % Store the affine matrix and plot the transform
    atlas2histology_tform{curr_slice} = tformEstimate_affine;

    % Get aligned atlas areas
    curr_av_aligned = imwarp(slice_atlas(curr_slice).av,tformEstimate_affine,'nearest', ...
        'Outputview',imref2d(size(curr_histology_slice)));
    atlas_align_borders{curr_slice} = boundarymask(max(0,curr_av_aligned));

    waitbar(curr_slice/length(slice_histology),waitbar_h, ...
        sprintf('Aligning atlas/histology slices: %d/%d', ...
        curr_slice,length(slice_histology)));

end

close(waitbar_h);

% Montage overlay
screen_size_px = get(0,'screensize');
gui_aspect_ratio = 1.7; % width/length
gui_width_fraction = 0.6; % fraction of screen width to occupy
gui_width_px = screen_size_px(3).*gui_width_fraction;
gui_position = [...
    (screen_size_px(3)-gui_width_px)/2, ... % left x
    (screen_size_px(4)-gui_width_px/gui_aspect_ratio)/2, ... % bottom y
    gui_width_px,gui_width_px/gui_aspect_ratio]; % width, height
align_fig = figure('color','w','Position',gui_position);

% (images)
montage(slice_histology); hold on;
% % (binary threshold outline)
% slice_histology_binary_boundaries = cellfun(@(x) ...
%     imdilate(x,ones(9))-x,slice_histology_binary,'uni',false);
% binary_boundaries_montage = montage(slice_histology_binary_boundaries);
% binary_boundaries_montage.AlphaData = binary_boundaries_montage.CData;
% binary_boundaries_montage.CData = binary_boundaries_montage.CData.*permute([0;1;1],[2,3,1]);
% (aligned atlas areas)
aligned_atlas_montage = montage(atlas_align_borders);
aligned_atlas_montage.AlphaData = aligned_atlas_montage.CData > 0;
aligned_atlas_montage.CData = double(aligned_atlas_montage.CData).*permute([1;0;0],[2,3,1]);

% Prompt for save
opts.Default = 'Yes';
opts.Interpreter = 'tex';
user_confirm = questdlg('\fontsize{14} Save?','Confirm exit','Yes','No',opts);
switch user_confirm
    case 'Yes'
        % Save
        save_fn = fullfile(save_path,'atlas2histology_tform.mat');
        save(save_fn,'atlas2histology_tform');
        disp(['Saved alignments: ' save_fn]);
        close(align_fig);

    case 'No'
        % Close without saving
        close(align_fig);

end

% Update toolbar GUI
ap_histology.update_toolbar_gui(histology_toolbar_gui);















