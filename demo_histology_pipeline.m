% Example pipeline for processing histology

%% 1) Load CCF and set paths for slide and slice images

% Load CCF atlas
allen_atlas_path = 'C:\Users\Andrew\OneDrive for Business\Documents\Atlases\AllenCCF';
tv = readNPY([allen_atlas_path filesep 'template_volume_10um.npy']);
av = readNPY([allen_atlas_path filesep 'annotation_volume_10um_by_index.npy']);
st = loadStructureTree([allen_atlas_path filesep 'structure_tree_safe_2017.csv']);

% Set paths for histology images and directory to save slice/alignment
im_path = 'C:\Users\Andrew\Desktop\test_histology\AP046';
slice_path = [im_path filesep 'slices'];

%% 2) Preprocess slide images to produce slice images

% Set white balance and resize slide images, extract slice images
% (Note: this resizes the images purely for file size reasons - the CCF can
% be aligned to histology no matter what the scaling. If pixel size is
% available in metadata then automatically scales to CCF resolution,
% otherwise user can specify the resize factor as a second argument)
AP_process_histology(im_path);
% AP_process_histology(im_path,resize_factor); % user-specified resize factor

% (optional) Rotate, center, pad, flip slice images
AP_rotate_histology(slice_path);

%% 3) Align CCF to slices

% Find CCF slices corresponding to each histology slice
AP_grab_histology_ccf(tv,av,st,slice_path);

% Align CCF slices and histology slices
% (first: automatically, by outline)
AP_auto_align_histology_ccf(slice_path)
% (second: curate manually)
AP_manual_align_histology_ccf(tv,av,st,slice_path);


%% 4) Utilize aligned CCF

% Display aligned CCF over histology slices
AP_view_aligned_histology(st,slice_path);

% Display histology within 3D CCF
AP_view_aligned_histology_volume(tv,av,st,slice_path,1);

% Get probe trajectory from histology, convert to CCF coordinates
AP_get_probe_histology(tv,av,st,slice_path);

% Align histology to electrophysiology
AP_align_probe_histology(st,slice_path,spike_times,spike_templates,template_depths);

% Extract slices from full-resolution images
% (not worth it at the moment, each slice is 200 MB)
% AP_grab_fullsize_histology_slices(im_path)













