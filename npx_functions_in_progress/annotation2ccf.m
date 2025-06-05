%% Convert probe histology coordinates to CCF coordinates

n_slices = length(AP_histology_processing.histology_ccf.atlas2histology_tform);

% Load atlas and get slice CCF coordinates
[av,tv,gui_data.st] = ap_histology.load_ccf;
slice_atlas = struct('ap',cell(n_slices,1),'ml',cell(n_slices,1),'dv',cell(n_slices,1));
for curr_slice = 1:n_slices
    [~,slice_ccf(curr_slice)] = ...
        ap_histology.grab_atlas_slice(av,tv, ...
        AP_histology_processing.histology_ccf.slice_vector, ...
        AP_histology_processing.histology_ccf.slice_points(curr_slice,:), 1);
end

% Transform probe histology coordinates to CCF
probe_segment_ccf = cell(n_slices,1);
for curr_slice = find(cellfun(@(x) ~isempty(x),AP_histology_processing.annotation.probe.segments))'
    probe_segment_histology_sub = round(transformPointsInverse( ...
        AP_histology_processing.histology_ccf.atlas2histology_tform{curr_slice}, ...
        AP_histology_processing.annotation.probe.segments{curr_slice}));

    probe_segment_histology_idx = ...
        sub2ind(size(slice_ccf(curr_slice).ap), ...
        probe_segment_histology_sub(:,2), ...
        probe_segment_histology_sub(:,1));
    
    probe_segment_ccf{curr_slice} = cat(2, ...
        slice_ccf(curr_slice).ap(probe_segment_histology_idx), ...
        slice_ccf(curr_slice).ml(probe_segment_histology_idx), ...
        slice_ccf(curr_slice).dv(probe_segment_histology_idx));
end

probe_ccf = permute(cat(3,probe_ccf{:}),[1,3,2]);



%% Draw probe on 3D CCF

% Create axis
figure('color','w');
ccf_ax = axes;
set(ccf_ax,'ZDir','reverse');
axis(ccf_ax,'vis3d','equal','manual','tight');
hold(ccf_ax,'on');
view(ccf_ax,[-30,25]);
h_rot = rotate3d(ccf_ax);
h_rot.Enable = 'on';

% Plot 3D brain outlines
slice_spacing = 5;
brain_volume = ...
    bwmorph3(bwmorph3(av(1:slice_spacing:end, ...
    1:slice_spacing:end,1:slice_spacing:end)>1,'majority'),'majority');
brain_outline_patchdata = isosurface(permute(brain_volume,[3,1,2]),0.5);
brain_outline = patch(ccf_ax, ...
    'Vertices',brain_outline_patchdata.vertices*slice_spacing, ...
    'Faces',brain_outline_patchdata.faces, ...
    'FaceColor',[0.7,0.7,0.7],'EdgeColor','none','FaceAlpha',0.1);

% Plot probe
line(ccf_ax,probe_ccf(:,:,1),probe_ccf(:,:,2),probe_ccf(:,:,3), ...
    'color','r','linewidth',2)


%% Get areas along probe

% Sample CCF at each micron along probe trajectory
% (atlas is 10um, so each micron is 0.1 voxel)

probe_ccf



probe_ccf_cat = reshape(probe_ccf,[],3);

% doesn't work pdist2 because need negative numbers too

probe_ccf_sample = interp1( ...
    pdist2(probe_ccf_cat(1,:),probe_ccf_cat)', ....
    probe_ccf_cat, -1000:0.1:1000);







