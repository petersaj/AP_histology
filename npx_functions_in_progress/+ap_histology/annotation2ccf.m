function annotation2ccf
% Draw annotation from AP_histology on 3D CCF

%% Select and load histology processing filename

[histology_processing_file,histology_processing_path] = uigetfile('AP_histology_processing.mat','Select histology processing file');
load(fullfile(histology_processing_path,histology_processing_file));


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

% Transform histology annotation vertices to CCF coordinates
annotation_vertices_ccf = cell(n_slices,1);
for curr_slice = find(cellfun(@(x) ~isempty(x),AP_histology_processing.annotation.vertices))'
    annotation_vertices_histology_sub = round(transformPointsInverse( ...
        AP_histology_processing.histology_ccf.atlas2histology_tform{curr_slice}, ...
        AP_histology_processing.annotation.vertices{curr_slice}));

    annotation_vertices_histology_idx = ...
        sub2ind(size(slice_ccf(curr_slice).ap), ...
        annotation_vertices_histology_sub(:,2), ...
        annotation_vertices_histology_sub(:,1));
    
    annotation_vertices_ccf{curr_slice} = cat(2, ...
        slice_ccf(curr_slice).ap(annotation_vertices_histology_idx), ...
        slice_ccf(curr_slice).ml(annotation_vertices_histology_idx), ...
        slice_ccf(curr_slice).dv(annotation_vertices_histology_idx));
end

annotation_vertices_ccf = cat(1,annotation_vertices_ccf{:});


%% Draw volume on 3D CCF

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

% Plot annotation volume
k = convhull(annotation_vertices_ccf(:,1),annotation_vertices_ccf(:,2),annotation_vertices_ccf(:,3));
patch(ccf_ax,'Faces', k, 'Vertices', annotation_vertices_ccf, ...
      'FaceColor', 'cyan', 'EdgeColor', 'black', 'FaceAlpha', 0.8);


%% IN PROGRESS: Draw probe on 3D CCF
% 
% % Create axis
% figure('color','w');
% ccf_ax = axes;
% set(ccf_ax,'ZDir','reverse');
% axis(ccf_ax,'vis3d','equal','manual','tight');
% hold(ccf_ax,'on');
% view(ccf_ax,[-30,25]);
% h_rot = rotate3d(ccf_ax);
% h_rot.Enable = 'on';
% 
% % Plot 3D brain outlines
% slice_spacing = 5;
% brain_volume = ...
%     bwmorph3(bwmorph3(av(1:slice_spacing:end, ...
%     1:slice_spacing:end,1:slice_spacing:end)>1,'majority'),'majority');
% brain_outline_patchdata = isosurface(permute(brain_volume,[3,1,2]),0.5);
% brain_outline = patch(ccf_ax, ...
%     'Vertices',brain_outline_patchdata.vertices*slice_spacing, ...
%     'Faces',brain_outline_patchdata.faces, ...
%     'FaceColor',[0.7,0.7,0.7],'EdgeColor','none','FaceAlpha',0.1);
% 
% % Plot annotation vertices
% plot3(ccf_ax,annotation_vertices_ccf(:,1),annotation_vertices_ccf(:,2),annotation_vertices_ccf(:,3), ...
%     'color','r','linewidth',2)


% %% Get areas along probe
% 
% % IN PROGRESS - switch probe vs volume annotation? 
% 
% % Sample CCF at each micron along probe trajectory
% % (atlas is 10um, so each micron is 0.1 voxel)
% 
% probe_ccf
% 
% probe_ccf_cat = reshape(probe_ccf,[],3);
% 
% % doesn't work pdist2 because need negative numbers too
% 
% probe_ccf_sample = interp1( ...
%     pdist2(probe_ccf_cat(1,:),probe_ccf_cat)', ....
%     probe_ccf_cat, -1000:0.1:1000);







