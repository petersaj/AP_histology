function align_manual_histology_atlas_v2(~,~,histology_gui)

%%%% TO DO: disable histology image scrolling?

% Get gui data
histology_guidata = guidata(histology_gui);
load(histology_guidata.histology_processing_filename);

% Turn on atlas view in histology gui


% Load atlas, get atlas images
[av,tv,st] = ap_histology.load_ccf;
slice_atlas = struct('tv',cell(size(histology_guidata.data)), 'av',cell(size(histology_guidata.data)));
for curr_slice = 1:length(histology_guidata.data)
    slice_atlas(curr_slice) = ...
        ap_histology.grab_atlas_slice(av,tv, ...
        AP_histology_processing.histology_ccf.slice_vector, ...
        AP_histology_processing.histology_ccf.slice_points(curr_slice,:), 1);
end

% Create manual align gui figure
align_gui = figure('color','w');
align_guidata = struct;
align_guidata.curr_slice = 1;
align_guidata.slice_atlas = slice_atlas;

% Draw atlas slice
atlas_ax = axes(align_gui,'YDir','reverse'); 
hold on; axis image off; colormap(gray); clim([0,400]);
align_guidata.im_h = imagesc(atlas_ax,align_guidata.slice_atlas(1).tv);

% Initialize control points
align_guidata.histology_control_points = repmat({zeros(0,2)},size(histology_guidata.data));
align_guidata.atlas_control_points = repmat({zeros(0,2)},size(histology_guidata.data));

hold(histology_guidata.im_h.Parent,'on')
align_guidata.histology_control_points_plot = plot(histology_guidata.im_h.Parent,nan,nan,'.w','MarkerSize',20);

hold(align_guidata.im_h.Parent,'on')
align_guidata.atlas_control_points_plot = plot(align_guidata.im_h.Parent,nan,nan,'.w','MarkerSize',20);

% Turn on control point clicking function
histology_guidata.im_h.ButtonDownFcn = {@mouseclick_align,histology_gui,align_gui};
align_guidata.im_h.ButtonDownFcn = {@mouseclick_align,histology_gui,align_gui};

% Set align gui data
guidata(align_gui,align_guidata);

end

function mouseclick_align(currentObject,eventdata,histology_gui,align_gui)

% Check which gui was clicked
% (do nothing if it was neither and somehow got here)
[~,fig_clicked] = ismember(currentObject.Parent.Parent,[histology_gui,align_gui]);
if fig_clicked == 0
    return
end

% Get gui data
histology_guidata = guidata(histology_gui);
align_guidata = guidata(align_gui);

%%%%% WORKING: NEED TO CHECK THIS WITH REORDERING
curr_im = histology_guidata.curr_im;

switch fig_clicked
    case 1 % Histology
        % Add clicked location to control points
        align_guidata.histology_control_points{curr_im} = ...
            vertcat(align_guidata.histology_control_points{curr_im}, ...
            eventdata.IntersectionPoint(1:2));

        set(align_guidata.histology_control_points_plot, ...
            'XData',align_guidata.histology_control_points{curr_im}(:,1), ...
            'YData',align_guidata.histology_control_points{curr_im}(:,2));

    case 2 % Atlas
        % Add clicked location to control points
        align_guidata.atlas_control_points{curr_im} = ...
            vertcat(align_guidata.atlas_control_points{curr_im}, ...
            eventdata.IntersectionPoint(1:2));

        set(align_guidata.atlas_control_points_plot, ...
            'XData',align_guidata.atlas_control_points{curr_im}(:,1), ...
            'YData',align_guidata.atlas_control_points{curr_im}(:,2));
end

% Update align gui data
guidata(align_gui,align_guidata);

end
