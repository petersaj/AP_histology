function gui_fig = AP_align_probe_histology(st,slice_path, ...
    spike_times,spike_templates,template_depths,use_probe)
% AP_align_probe_histology(st,slice_path,spike_times,spike_templates,template_depths,lfp,lfp_channel_positions,use_probe)

% If no probe specified, use probe 1
if ~exist('use_probe','var') || isempty(use_probe)
    use_probe = 1;
end

% Load probe CCF
probe_ccf_fn = [slice_path filesep 'probe_ccf.mat'];
load(probe_ccf_fn);

% Get normalized log spike n
spike_templates_unique = unique(spike_templates);
norm_template_spike_n = mat2gray(log10(accumarray(spike_templates,1)+1));

% Get multiunit correlation
depth_corr_window = 200; % MUA window in microns
depth_corr_window_spacing = 50; % MUA window spacing in microns

max_depths = 3840; % (hardcode, sometimes kilosort2 drops channels)

depth_corr_bins = [0:depth_corr_window_spacing:(max_depths-depth_corr_window); ...
    (0:depth_corr_window_spacing:(max_depths-depth_corr_window))+depth_corr_window];
depth_corr_bin_centers = depth_corr_bins(1,:) + diff(depth_corr_bins,[],1)/2;

spike_binning_t = 0.01; % seconds
spike_binning_t_edges = nanmin(spike_times):spike_binning_t:nanmax(spike_times);

binned_spikes_depth = zeros(size(depth_corr_bins,2),length(spike_binning_t_edges)-1);
for curr_depth = 1:size(depth_corr_bins,2)
    curr_depth_templates_idx = ...
        find(template_depths >= depth_corr_bins(1,curr_depth) & ...
        template_depths < depth_corr_bins(2,curr_depth));
    
    binned_spikes_depth(curr_depth,:) = histcounts(spike_times( ...
        ismember(spike_templates,curr_depth_templates_idx)),spike_binning_t_edges);
end

mua_corr = corrcoef(binned_spikes_depth');

% Create GUI
gui_fig = figure('color','w','KeyPressFcn',@keypress);
tiledlayout(1,7,'TileSpacing','compact');

% Plot spike depth vs rate
unit_ax = nexttile([1,3]);
scatter(norm_template_spike_n(spike_templates_unique), ...
    template_depths(spike_templates_unique),15,'k','filled');
set(unit_ax,'YDir','reverse');
ylim([0,max_depths]);
xlabel('N spikes')
title('Template depth & rate')
set(unit_ax,'FontSize',12)
ylabel('Depth (\mum)');

% Plot multiunit correlation
multiunit_ax = nexttile([1,3]); axis off;
imagesc(depth_corr_bin_centers,depth_corr_bin_centers,mua_corr);
caxis([0,0.3]); colormap(hot);
ylim([0,max_depths]);
set(multiunit_ax,'YTick',[]);
title('MUA correlation');
set(multiunit_ax,'FontSize',12)
xlabel(multiunit_ax,'Multiunit depth');

% Link all y-axes
linkaxes([unit_ax,multiunit_ax],'y');

% Plot probe areas (interactive)
% (load the colormap - located in the repository, find by associated fcn)
allenCCF_path = fileparts(which('allenCCFbregma'));
cmap_filename = [allenCCF_path filesep 'allen_ccf_colormap_2017.mat'];
load(cmap_filename);

probe_areas_ax = nexttile;

% Convert probe CCF coordinates to linear depth (*10 to convert to um)
% (use the dorsal-most coordinate as the reference point)
[~,dv_sort_idx] = sort(probe_ccf(use_probe).trajectory_coords(:,2));

probe_trajectory_depths = ...
    pdist2(probe_ccf(use_probe).trajectory_coords, ...
    probe_ccf(use_probe).trajectory_coords((dv_sort_idx == 1),:))*10;

trajectory_area_boundary_idx = ...
    [1;find(diff(double(probe_ccf(use_probe).trajectory_areas)) ~= 0)+1];
trajectory_area_boundaries = probe_trajectory_depths(trajectory_area_boundary_idx);
trajectory_area_centers = (trajectory_area_boundaries(1:end-1) + diff(trajectory_area_boundaries)/2);
trajectory_area_labels = st.acronym(probe_ccf(use_probe).trajectory_areas(trajectory_area_boundary_idx));

[~,area_dv_sort_idx] = sort(trajectory_area_centers);

image([],probe_trajectory_depths,probe_ccf(use_probe).trajectory_areas);
colormap(probe_areas_ax,cmap);
caxis([1,size(cmap,1)])
set(probe_areas_ax,'YTick',trajectory_area_centers(area_dv_sort_idx), ...
    'YTickLabels',trajectory_area_labels(area_dv_sort_idx));
set(probe_areas_ax,'XTick',[]);
set(probe_areas_ax,'YAxisLocation','right')

ylim([0,max_depths]);
ylabel({'Probe areas','(Arrow/shift keys to move)','(Escape: save & quit)'});
set(probe_areas_ax,'FontSize',10)

% Draw boundary lines at borders (and undo clipping to extend across all)
boundary_lines = gobjects;
for curr_boundary = 1:length(trajectory_area_boundaries)
    boundary_lines(curr_boundary,1) = line(probe_areas_ax,[-13.5,1.5], ...
        repmat(trajectory_area_boundaries(curr_boundary),1,2),'color','b','linewidth',1);
end
set(probe_areas_ax,'Clipping','off');

% Package into gui
gui_data = struct;
gui_data.probe_ccf_fn = probe_ccf_fn; 

gui_data.probe_ccf = probe_ccf;
gui_data.use_probe = use_probe;

gui_data.unit_ax = unit_ax;
gui_data.multiunit_ax = multiunit_ax;

gui_data.probe_areas_ax = probe_areas_ax;
gui_data.probe_areas_ax_ylim = ylim(probe_areas_ax);
gui_data.probe_trajectory_depths = probe_trajectory_depths;

% Upload gui data
guidata(gui_fig,gui_data);

end


function keypress(gui_fig,eventdata)

% Get guidata
gui_data = guidata(gui_fig);

% Set amounts to move by with/without shift
if any(strcmp(eventdata.Modifier,'shift'))
    y_change = 100;
else
    y_change = 1;
end

switch eventdata.Key
    
    % up/down: move probe areas
    case 'uparrow'
        new_ylim = gui_data.probe_areas_ax_ylim - y_change;
        ylim(gui_data.probe_areas_ax,new_ylim);
        gui_data.probe_areas_ax_ylim = new_ylim;
        % Upload gui data
        guidata(gui_fig,gui_data);
    case 'downarrow'
        new_ylim = gui_data.probe_areas_ax_ylim + y_change;
        ylim(gui_data.probe_areas_ax,new_ylim);
        gui_data.probe_areas_ax_ylim = new_ylim;
        % Upload gui data
        guidata(gui_fig,gui_data);
        
    % escape: save and quit
    case 'escape'
        opts.Default = 'Yes';
        opts.Interpreter = 'tex';
        user_confirm = questdlg('\fontsize{15} Save and quit?','Confirm exit',opts);
        if strcmp(user_confirm,'Yes')
            
            probe_ccf = gui_data.probe_ccf;
            
            % Get the probe depths corresponding to the trajectory areas
            probe_depths = gui_data.probe_trajectory_depths - ...
                gui_data.probe_areas_ax_ylim(1);         
            
            probe_ccf(gui_data.use_probe).probe_depths = probe_depths;
            
            % Save the appended probe_ccf structure
            save(gui_data.probe_ccf_fn,'probe_ccf');
            
            % Close the figure
            close(gui_fig);
            
        end
        
end

end







