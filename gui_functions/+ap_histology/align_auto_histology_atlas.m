function align_auto_histology_atlas(~,~,histology_gui,user_confirm_flag)
% Part of AP_histology toolbox
%
% Auto aligns histology slices and matched CCF slices by outline registration

if ~exist('user_confirm_flag','var')
    user_confirm_flag = true;
end

% User confirm
if user_confirm_flag
    user_confirm = questdlg('Auto-align atlas slices to histology?','Confirm','Yes','No','No');
    if strcmpi(user_confirm,'no')
        return
    end
end

% Get gui data
histology_guidata = guidata(histology_gui);
load(histology_guidata.histology_processing_filename);

% Update status
histology_guidata.update([],[],histology_gui,'Auto-aligning atlas/histology slices...');

% Grab slice images from histology scroller and grayscale 
% (apply rigid transform)
slice_histology = cell(size(histology_guidata.data));
for curr_slice = 1:length(histology_guidata.data)
    curr_slice_bw = ...
        max(min(histology_guidata.data{curr_slice} - permute(histology_guidata.clim(:,1),[2,3,1]), ...
        permute(diff(histology_guidata.clim,[],2),[2,3,1])),[],3);

    curr_slice_bw_rigidtform = ...
        ap_histology.rigid_transform(curr_slice_bw,curr_slice,AP_histology_processing);

    slice_histology{curr_slice} = curr_slice_bw_rigidtform;
end

% Load atlas
[av,tv,st] = ap_histology.load_ccf;

% Get atlas images
slice_atlas = struct('tv',cell(size(histology_guidata.data)), 'av',cell(size(histology_guidata.data)));
for curr_slice = 1:length(histology_guidata.data)
    slice_atlas(curr_slice) = ...
        ap_histology.grab_atlas_slice(av,tv, ...
        AP_histology_processing.histology_ccf.slice_vector, ...
        AP_histology_processing.histology_ccf.slice_points(curr_slice,:), 1);
end

% Binarize slices (only necessary if aligning outlines)
slice_thresh = graythresh(cell2mat(cellfun(@(x) reshape(x(x~=0),[],1),slice_histology,'uni',false)));
slice_histology_binary = cellfun(@(x) imbinarize(x,slice_thresh),slice_histology,'uni',false);

% Align outlines of histology/atlas slices
atlas2histology_tform = cell(size(slice_histology));
atlas2histology_size = cell(size(slice_histology));
av_aligned = cell(size(slice_histology));

for curr_slice = 1:length(slice_histology)

    % Update status text
    slice_status = sprintf('Auto-aligning atlas/histology slices: %d/%d',curr_slice,length(slice_histology));
    histology_guidata.update([],[],histology_gui,slice_status)

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
    downsample_factor = 10;

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
    atlas2histology_size{curr_slice} = size(curr_histology_slice);

    % Get aligned atlas areas
    av_aligned{curr_slice} = ...
        imwarp(slice_atlas(curr_slice).av,tformEstimate_affine,'nearest', ...
        'Outputview',imref2d(size(curr_histology_slice)));
end

% Clear status text
histology_guidata.update([],[],histology_gui,'')

% Montage overlay
align_fig = figure('color','w','units','normalized','Position',histology_gui.Position);

im_ax = axes(align_fig,'units','normalized','position',[0,0,1,1]);
im_montage = montage(slice_histology);
clim(im_ax,[0,prctile(im_montage.CData,95,'all')]);
colormap(im_ax,'gray');

atlas_ax = axes(align_fig,'units','normalized','position',[0,0,1,1]);
atlas_montage = montage(av_aligned);

ccf_cmap = cell2mat(cellfun(@(x) hex2dec(mat2cell(x,1,[2,2,2]))'./255,st.color_hex_triplet,'uni',false));
colormap(atlas_ax,ccf_cmap);
clim(atlas_ax,[1,size(ccf_cmap,1)]);

atlas_montage.AlphaData = 0.2;

linkaxes([im_ax,atlas_ax]);
title(atlas_ax,'Histology/atlas alignment overlay');

% Prompt for save
if user_confirm_flag
    opts.Default = 'Yes';
    opts.Interpreter = 'tex';
    user_confirm = questdlg('\fontsize{14} Save alignments?','Confirm exit','Yes','No',opts);
    switch user_confirm
        
        case 'Yes'
            % Package
            AP_histology_processing.histology_ccf.atlas2histology_tform = atlas2histology_tform;
            AP_histology_processing.histology_ccf.atlas2histology_size = atlas2histology_size;

            % Save
            save(histology_guidata.histology_processing_filename,'AP_histology_processing');
            disp('Saved alignments');

            % Load atlas slices into histology GUI
            histology_guidata.load_atlas_slices([],[],histology_gui)

            % Turn on atlas view
            view_aligned_atlas_menu_idx = contains({histology_guidata.menu.view.Children.Text},'atlas','IgnoreCase',true);
            histology_guidata.menu.view.Children(view_aligned_atlas_menu_idx).Checked = true;
            histology_guidata.update([],[],histology_gui);

        case 'No'
            % Close without saving
            close(align_fig);

    end
end















