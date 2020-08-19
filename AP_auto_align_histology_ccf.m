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
    % (do this by estimating background from border pixels)    
    curr_im_bw = nanmean(curr_histology,3);
    
    border_px = 10;
    border_idx = true(size(curr_im_bw));
    border_idx(border_px+1:end-border_px,border_px+1:end-border_px) = false;
    slice_threshold = 3*(nanmean(curr_im_bw(border_idx),1)+1);
    
    curr_histology_thresh = +(curr_im_bw > slice_threshold);
    
    % Resize atlas outline to approximately match histology, affine-align
    resize_factor = min(size(curr_histology_thresh)./size(curr_av_thresh));
    curr_av_thresh_resize = imresize(curr_av_thresh,resize_factor,'nearest');
    
    [optimizer, metric] = imregconfig('monomodal');
    optimizer.MaximumIterations = 200;
    optimizer.MaximumStepLength = 1e-2;
    optimizer.GradientMagnitudeTolerance = 1e-5;
    optimizer.RelaxationFactor = 1e-1;
    
    tformEstimate_affine_resized = imregtform(curr_av_thresh_resize,curr_histology_thresh,'affine',optimizer,metric);
    
    % Put the resizing factor into the affine matrix
    tformEstimate_affine = tformEstimate_affine_resized;
    tformEstimate_affine.T(1,1) = tformEstimate_affine_resized.T(1,1)*resize_factor;
    tformEstimate_affine.T(2,2) = tformEstimate_affine_resized.T(2,2)*resize_factor;
    
    % Store the affine matrix and plot the transform
    atlas2histology_tform{curr_slice} = tformEstimate_affine.T;
    
    curr_av_aligned = imwarp(curr_av,tformEstimate_affine,'nearest','Outputview',imref2d(size(curr_histology)));   
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
    imagesc(av_aligned_boundaries,'Parent',ax_last_aligned,'AlphaData',av_aligned_boundaries*0.3);
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














