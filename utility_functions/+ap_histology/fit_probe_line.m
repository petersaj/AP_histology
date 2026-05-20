function probe_ccf_fit = fit_probe_line(AP_histology_processing_filename)
% probe_line_fits = fit_probe_line(AP_histology_processing_filename)
%
% From AP_histology probe annotations: fit line to probe points, return CCF
% coordinates for [insertion; tip approximation]
%
% INPUTS
% AP_histology_processing_filename - processing filename from AP_histology
% 
% OUTPUTS
% probe_insertion - structure with:
%       .label - annotation label
%       .ccf - [insertion;tip] coordinates CCF [AP,DV,ML]

% Load histology processing
load(AP_histology_processing_filename)

% Get labels and vertices of all probes
probe_labels = string({AP_histology_processing.annotation.label});
probe_ccf_vertices = arrayfun(@(x) horzcat( ...
    vertcat(x.vertices_ccf.ap), ...
    vertcat(x.vertices_ccf.dv), ...
    vertcat(x.vertices_ccf.ml)), ...
    AP_histology_processing.annotation,'uni',false);

% Loop through probes, find insertion point
probe_fit_coordinates = cell(size(probe_ccf_vertices));
for curr_probe = 1:length(probe_ccf_vertices)

    % Load CCF atlas
    [av,~,~] = ap_histology.load_ccf;

    % Get line of best fit through mean of marked points
    [~,~,probe_fit] = svd(probe_ccf_vertices{curr_probe} - mean(probe_ccf_vertices{curr_probe},1),0);
    probe_direction = probe_fit(:,1);

    % (ensure vector goes downward in DV)
    probe_direction(2) = abs(probe_direction(2));

    % Get probe unit vector
    probe_vector = mean(probe_ccf_vertices{curr_probe},1) + padarray(probe_direction',[1,0],0,'pre');

    % Grab AV values across probe trajectory
    max_eval = round(sqrt(max(size(av)).^2*2));
    eval_points_probe = (-max_eval:max_eval);
    eval_points_ccf = round(interp1([0,norm(diff(probe_vector))],probe_vector, ...
        eval_points_probe,'linear','extrap'));

    eval_points_ccf_valid = eval_points_ccf(all(eval_points_ccf > 0 & eval_points_ccf <= size(av),2),:);

    eval_points_ccf_idx = sub2ind(size(av),eval_points_ccf_valid(:,1), ...
        eval_points_ccf_valid(:,2),eval_points_ccf_valid(:,3));

    probe_trajectory_av = av(eval_points_ccf_idx);

    % Get insertion point: where fit intersects brain
    probe_insertion_ccf_fit = eval_points_ccf_valid(find(probe_trajectory_av>1,1),:);

    % Get deepest point (tip): where fit is closest to deepest labeled point
    [~,deepest_point_idx] = max(probe_ccf_vertices{curr_probe}(:,2));
    probe_depth_ccf_labeled = probe_ccf_vertices{curr_probe}(deepest_point_idx,:);

    probe_depth_ccf_fit = probe_vector(1,:) + ...
        ((probe_depth_ccf_labeled-probe_vector(1,:))*diff(probe_vector,[],1)').* ...
        diff(probe_vector,[],1);    

    % Store probe location as [insertion;tip]
    probe_fit_coordinates{curr_probe} = [probe_insertion_ccf_fit;probe_depth_ccf_fit];

end

% Package output
probe_ccf_fit = struct('label',num2cell(probe_labels),'ccf',probe_fit_coordinates);
