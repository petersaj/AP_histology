function annotation2ccf(histology_processing_filename,slice_atlas_ccf,annotations,slices)
% annotation2ccf(histology_processing_filename,slice_atlas_ccf,annotation,slice)
% 
% Calculate and save CCF coordinates for annotations 
% (compensates for new atlas->slice transform, assumes no change in slice)
%
% INPUTS
% histology_processing_filename - location of histology processing file
% slice_atlas_ccf (optional) - CCF coordinates corresponding to slices (loads if not specified)
% annotations (optiona) - annotation to convert (all if not specifed)
% slices (optional) - slice to convert (all if not specified)

arguments
    histology_processing_filename {mustBeText}
    slice_atlas_ccf = []
    annotations = []
    slices = []
end

% Load processing
load(histology_processing_filename)

% Use all annotations if not set
if isempty(annotations)
    if isfield(AP_histology_processing,'annotation') && ...
            ~isempty(AP_histology_processing.annotation)
        annotations = 1:length(AP_histology_processing.annotation);
    else
        return
    end
end

% Use all slices if not set
if isempty(slices)
    slices = 1:size(AP_histology_processing.histology_ccf.slice_points,1);
end

% Grab atlas images (if not provided)
if isempty(slice_atlas_ccf)
    [av,tv,gui_data.st] = ap_histology.load_ccf;
    n_slices = length(AP_histology_processing.histology_ccf.atlas2histology_size);
    slice_atlas = struct('tv',cell(n_slices,1), 'av',cell(n_slices,1));
    slice_atlas_ccf = struct('ap',cell(n_slices,1),'ml',cell(n_slices,1),'dv',cell(n_slices,1));
    for curr_slice = 1:n_slices
        [slice_atlas(curr_slice),slice_atlas_ccf(curr_slice)] = ...
            ap_histology.grab_atlas_slice(av,tv, ...
            AP_histology_processing.histology_ccf.slice_vector, ...
            AP_histology_processing.histology_ccf.slice_points(curr_slice,:), 1);
    end
end

% Loop through annotations>images, transform histology coords to CCF
for curr_annotation = reshape(annotations,1,[])
    for curr_slice = reshape(slices,1,[])

        curr_vertices = AP_histology_processing.annotation(curr_annotation).vertices_histology{curr_slice};
        if isempty(curr_vertices)
            continue
        end

        % Get transform from slice to atlas
        % (manual if >3 paired control points, automatic otherwise)
        if isfield(AP_histology_processing.histology_ccf,'control_points') && ...
                (size(AP_histology_processing.histology_ccf.control_points.histology{curr_slice},1) == ...
                size(AP_histology_processing.histology_ccf.control_points.atlas{curr_slice},1)) && ...
                size(AP_histology_processing.histology_ccf.control_points.histology{curr_slice},1) >= 3
            % Manual alignment
            atlas_tform = fitgeotform2d( ...
                AP_histology_processing.histology_ccf.control_points.atlas{curr_slice}, ...
                AP_histology_processing.histology_ccf.control_points.histology{curr_slice},'pwl');
        elseif isfield(AP_histology_processing.histology_ccf,'atlas2histology_tform')
            % Automatic alignment
            atlas_tform = AP_histology_processing.histology_ccf.atlas2histology_tform{curr_slice};
        end

        % Convert vertices to CCF coordinates
        annotation_vertices_histology_subscript = round(transformPointsInverse( ...
            atlas_tform,curr_vertices));

        annotation_vertices_histology_idx = ...
            sub2ind(size(slice_atlas_ccf(curr_slice).ap), ...
            annotation_vertices_histology_subscript(:,2), ...
            annotation_vertices_histology_subscript(:,1));

        [AP_histology_processing.annotation(curr_annotation).vertices_ccf(curr_slice).ap, ...
            AP_histology_processing.annotation(curr_annotation).vertices_ccf(curr_slice).ml, ...
            AP_histology_processing.annotation(curr_annotation).vertices_ccf(curr_slice).dv] = ...
            deal(slice_atlas_ccf(curr_slice).ap(annotation_vertices_histology_idx), ...
            slice_atlas_ccf(curr_slice).ml(annotation_vertices_histology_idx), ...
            slice_atlas_ccf(curr_slice).dv(annotation_vertices_histology_idx));

    end
end

% Save processing
save(histology_processing_filename, 'AP_histology_processing');


