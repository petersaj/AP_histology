function AP_auto_align_histology_ccf(slice_im_path)
% AP_auto_align_histology_ccf(slice_im_path)
%
% Auto aligns histology slices and matched CCF slices by outline registration
% Andy Peters (peters.andrew.j@gmail.com)

% Load in slice images
slice_im_path = slice_im_path;
slice_im_dir = dir([slice_im_path filesep '*.tif']);
slice_im_fn = natsortfiles(cellfun(@(path,fn) [path filesep fn], ...
    {slice_im_dir.folder},{slice_im_dir.name},'uni',false));
slice_im = cell(length(slice_im_fn),1);
for curr_slice = 1:length(slice_im_fn)
    slice_im{curr_slice} = imread(slice_im_fn{curr_slice});
end

% Load corresponding CCF slices
ccf_slice_fn = [slice_im_path filesep 'histology_ccf.mat'];
load(ccf_slice_fn);

% Align outlines of histology/atlas slices
fig_last_aligned = figure;
ax_last_aligned = axes;

atlas2histology_tform = cell(size(slice_im));
for curr_slice = 1:length(slice_im)
    
    curr_histology = slice_im{curr_slice};
    curr_av = histology_ccf(curr_slice).av_slices;
    
    curr_av(isnan(curr_av)) = 1;
    curr_av_thresh = +(curr_av > 1);
    
    % Estimate slice white threshold
    % (get median nonzero value, halve)    
    curr_im_bw = nanmean(curr_histology,3); 
    slice_threshold = prctile(curr_im_bw(curr_im_bw ~= 0),50)/2; 
    
    % (binarize and close patchy areas)
    curr_histology_thresh = imclose(+(curr_im_bw > slice_threshold),ones(20));
    
    % Resize atlas outline to approximately match histology, affine-align
    resize_factor = min(size(curr_histology_thresh)./size(curr_av_thresh));
    curr_av_thresh_resize = imresize(curr_av_thresh,resize_factor,'nearest');
    
    [optimizer, metric] = imregconfig('monomodal');
    optimizer.MaximumIterations = 200;
    optimizer.MaximumStepLength = 1e-2;
    optimizer.GradientMagnitudeTolerance = 1e-5;
    optimizer.RelaxationFactor = 1e-1;

    % Do alignment on downsampled sillhouettes (faster and more accurate)
    downsample_factor = 10;

    tformEstimate_affine_resized = ...
        imregtform( ...
        imresize(curr_av_thresh_resize,1/downsample_factor,'nearest'), ...
        imresize(curr_histology_thresh,1/downsample_factor,'nearest'), ...
        'affine',optimizer,metric,'PyramidLevels',3);

    % Set final transform (scale to histology, downscale, affine, upscale)
    scale_match = eye(3).*[repmat(resize_factor,2,1);1];
    scale_align_down = eye(3).*[repmat(1/downsample_factor,2,1);1];
    scale_align_up = eye(3).*[repmat(downsample_factor,2,1);1];

    tformEstimate_affine = tformEstimate_affine_resized;
    tformEstimate_affine.T = scale_match*scale_align_down* ...
        tformEstimate_affine_resized.T*scale_align_up;

    curr_av_aligned = imwarp(curr_av,tformEstimate_affine,'nearest','Outputview',imref2d(size(curr_histology)));   
    
    % Store the affine matrix and plot the transform
    atlas2histology_tform{curr_slice} = tformEstimate_affine.T;
    
    curr_av_aligned = imwarp(curr_av,tformEstimate_affine,'nearest','Outputview',imref2d(size(curr_histology)));   
    
    curr_histology_thresh_boundaries = imdilate(curr_histology_thresh,ones(9))-curr_histology_thresh;
    av_aligned_boundaries = round(conv2(curr_av_aligned,ones(3)./9,'same')) ~= curr_av_aligned;

    % (recreate figure if closed)
    if ~isvalid(fig_last_aligned)
        fig_last_aligned = figure;
    end
    if ~isvalid(ax_last_aligned)
        ax_last_aligned = axes(fig_last_aligned);
    end
    figure(fig_last_aligned);
    imshow(curr_histology,'Parent',ax_last_aligned); hold on
    imagesc(padarray(curr_histology_thresh_boundaries,[0,0,2],0,'post'), ...
        'Parent',ax_last_aligned,'AlphaData',curr_histology_thresh_boundaries*1);
    imagesc(av_aligned_boundaries,'Parent',ax_last_aligned,'AlphaData',av_aligned_boundaries*1);
    colormap(gray);
    title(['Aligning slices ' num2str(curr_slice) '/' num2str(length(slice_im)) '...']);
    hold off;
    drawnow;
    
end

if isvalid(fig_last_aligned)
    close(fig_last_aligned);
end

save_fn = [slice_im_path filesep 'atlas2histology_tform.mat'];
save(save_fn,'atlas2histology_tform');

disp(['Finished auto-alignment, saved in ' save_fn]);














