function flip_reorder_slices(~,~,histology_toolbar_gui)
% Part of AP_histology toolbox
%
% Flip and re-order slice images

% Get images (from path in GUI)
histology_toolbar_guidata = guidata(histology_toolbar_gui);

slice_dir = dir(fullfile(histology_toolbar_guidata.save_path,'*.tif'));
slice_fn = natsortfiles(cellfun(@(path,fn) fullfile(path,fn), ...
    {slice_dir.folder},{slice_dir.name},'uni',false));

slice_im = cell(length(slice_fn),1);
for curr_slice = 1:length(slice_fn)
   slice_im{curr_slice} = imread(slice_fn{curr_slice});  
end

% Pull up slice viewer to scroll through slices with option to flip
screen_size_px = get(0,'screensize');
gui_aspect_ratio = 1.7; % width/length
gui_width_fraction = 0.6; % fraction of screen width to occupy
gui_width_px = screen_size_px(3).*gui_width_fraction;
gui_position = [...
    (screen_size_px(3)-gui_width_px)/2, ... % left x
    (screen_size_px(4)-gui_width_px/gui_aspect_ratio)/2, ... % bottom y
    gui_width_px,gui_width_px/gui_aspect_ratio]; % width, height

gui_fig = figure('KeyPressFcn',@keypress, ...
    'Toolbar','none','Menubar','none','color','w', ...
    'Units','pixels','Position',gui_position, ...
    'CloseRequestFcn',@close_gui);
gui_data.curr_slice = 1;
gui_data.im = slice_im;
gui_data.slice_fn = slice_fn;

% Set up axis for histology image
gui_data.histology_ax = axes('YDir','reverse');
hold on; colormap(gray); axis image off;
gui_data.histology_im_h = image(gui_data.im{1}, ...
    'Parent',gui_data.histology_ax);

% Create title to write area in
gui_data.histology_ax_title = title(gui_data.histology_ax, ...
    {'Left/right: change slice','Shift+left/right: re-order slice', ...
    'Ctrl+arrows: flip'},'FontSize',12);

% Upload gui data
guidata(gui_fig,gui_data);

end


function keypress(gui_fig,eventdata)

shift_on = any(strcmp(eventdata.Modifier,'shift'));
ctrl_on = any(strcmp(eventdata.Modifier,'control'));

% Get guidata
gui_data = guidata(gui_fig);

% Arrows: switch slice
% Shift + arrows: move slice in stack
% Control + arrows: flip slice

switch eventdata.Key
    case 'leftarrow'
        if ~shift_on && ~ctrl_on
            gui_data.curr_slice = max(gui_data.curr_slice - 1,1);
            set(gui_data.histology_im_h,'CData',gui_data.im{gui_data.curr_slice})
            guidata(gui_fig,gui_data);
        elseif shift_on
            slice_flip = [gui_data.curr_slice-1,gui_data.curr_slice];
            gui_data.im(slice_flip) = flip(gui_data.im(slice_flip));
            gui_data.curr_slice = slice_flip(1);
            guidata(gui_fig,gui_data);
        elseif ctrl_on
            gui_data.im{gui_data.curr_slice} = ...
                fliplr(gui_data.im{gui_data.curr_slice});
            set(gui_data.histology_im_h,'CData',gui_data.im{gui_data.curr_slice})
            guidata(gui_fig,gui_data);
        end

    case 'rightarrow'
        if ~shift_on && ~ctrl_on
            gui_data.curr_slice = ...
                min(gui_data.curr_slice + 1,length(gui_data.im));
            set(gui_data.histology_im_h,'CData',gui_data.im{gui_data.curr_slice})
            guidata(gui_fig,gui_data);
        elseif shift_on
            slice_flip = [gui_data.curr_slice,gui_data.curr_slice+1];
            gui_data.im(slice_flip) = flip(gui_data.im(slice_flip));
            gui_data.curr_slice = slice_flip(2);
            guidata(gui_fig,gui_data);
        elseif ctrl_on
            gui_data.im{gui_data.curr_slice} = ...
                fliplr(gui_data.im{gui_data.curr_slice});
            set(gui_data.histology_im_h,'CData',gui_data.im{gui_data.curr_slice})
            guidata(gui_fig,gui_data);
        end

    case {'uparrow','downarrow'}
        if ctrl_on
            gui_data.im{gui_data.curr_slice} = ...
                flipud(gui_data.im{gui_data.curr_slice});
            set(gui_data.histology_im_h,'CData',gui_data.im{gui_data.curr_slice})
            guidata(gui_fig,gui_data);
        end

end
end

function close_gui(gui_fig,eventdata)

% Get guidata
gui_data = guidata(gui_fig);

opts.Default = 'Yes';
opts.Interpreter = 'tex';
user_confirm = questdlg('\fontsize{14} Save?','Confirm exit',opts);
switch user_confirm
    case 'Yes'
        % Overwrite old images with new ones, close
        for curr_im = 1:length(gui_data.im)
            imwrite(gui_data.im{curr_im},gui_data.slice_fn{curr_im},'tif');
        end
        disp('Saved flipped and re-ordered slice images');
        delete(gui_fig)

    case 'No'
        % Close without saving
        delete(gui_fig)

    case 'Cancel'
        % Do nothing
end

end



