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
    curr_im_bw = nanmean(curr_histology,3);
    % (get histogram of values > 0 in case unimaged area)
    [im_hist,im_hist_edges] = histcounts(curr_im_bw, ...
        linspace(max(1,min(curr_im_bw(:))),max(curr_im_bw(:)),100));
    im_hist_deriv = [0;diff(smooth(im_hist,10))];
    [~,bg_down] = min(im_hist_deriv);
    bg_signal_min = find(im_hist_deriv(bg_down:end) > 0,1) + bg_down;
    slice_threshold = im_hist_edges(bg_signal_min);
    
    curr_histology_thresh = +(curr_im_bw > slice_threshold);
    
    [optimizer, metric] = imregconfig('monomodal');
    optimizer.MaximumIterations = 200;
    optimizer.MaximumStepLength = 1e-2;
    optimizer.GradientMagnitudeTolerance = 1e-5;
    optimizer.RelaxationFactor = 1e-1;
    
    tformEstimate_affine = imregtform(curr_av_thresh,curr_histology_thresh,'affine',optimizer,metric);
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














