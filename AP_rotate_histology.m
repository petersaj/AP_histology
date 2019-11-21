function AP_rotate_histology(im_path)
% AP_rotate_histology(im_path)
%
% Pad, center, and rotate images of histological slices
% Andy Peters (peters.andrew.j@gmail.com)

slice_dir = dir([im_path filesep '*.tif']);
slice_fn = natsortfiles(cellfun(@(path,fn) [path filesep fn], ...
    {slice_dir.folder},{slice_dir.name},'uni',false));

slice_im = cell(length(slice_fn),1);
for curr_slice = 1:length(slice_fn)
   slice_im{curr_slice} = imread(slice_fn{curr_slice});  
end

% Pad all slices centrally to the largest slice and make matrix
slice_size_max = max(cell2mat(cellfun(@size,slice_im,'uni',false)),[],1);
slice_im_pad = ...
    cell2mat(cellfun(@(x) x(1:slice_size_max(1),1:slice_size_max(2),:), ...
    reshape(cellfun(@(im) padarray(im, ...
    [ceil((slice_size_max(1) - size(im,1))./2), ...
    ceil((slice_size_max(2) - size(im,2))./2)],0,'both'), ...
    slice_im,'uni',false),1,1,1,[]),'uni',false));

% Draw line to indicate midline for rotation
rotation_fig = figure;

align_axis = nan(2,2,length(slice_im));
for curr_im = 1:length(slice_im)
    imshow(slice_im_pad(:,:,:,curr_im));
    title('Click and drag reference line (e.g. midline)')
    curr_line = imline;
    align_axis(:,:,curr_im) = curr_line.getPosition;  
end
close(rotation_fig);

% NOTE FOR FUTURE: make target angle either vert or horiz for whatever's
% closest to the average reference? then switch dx vs dy below
target_angle = 90;
target_position = round(slice_size_max(2)./2);

% Get angle for all axes
align_angle = squeeze(acosd(diff(align_axis(:,1,:),[],1)./diff(align_axis(:,2,:),[],1)));
align_center = squeeze(nanmean(align_axis,1));

im_aligned = zeros(size(slice_im_pad),class(slice_im_pad));

for curr_im = 1:length(slice_im)
    
    angle_diff = align_angle(curr_im) - target_angle;
    x_diff = target_position - align_center(1,curr_im);
    y_diff = 0;
    
    im_aligned(:,:,:,curr_im) = ...
        imrotate(imtranslate(slice_im_pad(:,:,:,curr_im), ...
        [x_diff,y_diff]),angle_diff,'bilinear','crop');
    
end

% Pull up slice viewer to scroll through slices with option to flip

% Create figure, set button functions
gui_fig = figure('KeyPressFcn',@keypress);
gui_data.curr_slice = 1;
gui_data.im_aligned = im_aligned;
gui_data.slice_fn = slice_fn;

% Set up axis for histology image
gui_data.histology_ax = axes('YDir','reverse'); 
hold on; colormap(gray); axis image off;
gui_data.histology_im_h = image(gui_data.im_aligned(:,:,:,1), ...
    'Parent',gui_data.histology_ax);

% Create title to write area in
gui_data.histology_ax_title = title(gui_data.histology_ax, ...
    '1/2: change slice, Arrows: flip, Esc: save & quit','FontSize',14);

% Upload gui data
guidata(gui_fig,gui_data);



end


function keypress(gui_fig,eventdata)

% Get guidata
gui_data = guidata(gui_fig);

switch eventdata.Key
    
    % 1/2: move slice
    case '1'
        gui_data.curr_slice = max(gui_data.curr_slice - 1,1);
        set(gui_data.histology_im_h,'CData',gui_data.im_aligned(:,:,:,gui_data.curr_slice))
        guidata(gui_fig,gui_data);
        
    case '2'
        gui_data.curr_slice = ...
            min(gui_data.curr_slice + 1,size(gui_data.im_aligned,4));
        set(gui_data.histology_im_h,'CData',gui_data.im_aligned(:,:,:,gui_data.curr_slice))
        guidata(gui_fig,gui_data);
        
    % Arrow keys: flip slice
    case {'leftarrow','rightarrow'}
        gui_data.im_aligned(:,:,:,gui_data.curr_slice) = ...
            fliplr(gui_data.im_aligned(:,:,:,gui_data.curr_slice));
        set(gui_data.histology_im_h,'CData',gui_data.im_aligned(:,:,:,gui_data.curr_slice))
        guidata(gui_fig,gui_data);
        
    case {'uparrow','downarrow'}
        gui_data.im_aligned(:,:,:,gui_data.curr_slice) = ...
            flipud(gui_data.im_aligned(:,:,:,gui_data.curr_slice));
        set(gui_data.histology_im_h,'CData',gui_data.im_aligned(:,:,:,gui_data.curr_slice))
        guidata(gui_fig,gui_data);
        
    % Escape: save and close
    case 'escape'
        opts.Default = 'Yes';
        opts.Interpreter = 'tex';
        user_confirm = questdlg('\fontsize{15} Save and quit?','Confirm exit',opts);
        if strcmp(user_confirm,'Yes')
            % Overwrite old images with new ones
            for curr_im = 1:size(gui_data.im_aligned,4)
                imwrite(gui_data.im_aligned(:,:,:,curr_im),gui_data.slice_fn{curr_im},'tif');
            end
            disp(['Saved padded/centered/rotated slices']);
            close(gui_fig)
        end
        
end

end




