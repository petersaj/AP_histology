function update_gui(histology_toolbar_gui)

% Get guidata
gui_data = guidata(histology_toolbar_gui);

% Check for files
raw_images_present = ~isempty(gui_data.image_path) && ...
    ~isempty(dir(fullfile(gui_data.image_path,'*.tif')));
processed_images_present = ~isempty(gui_data.save_path) && ...
    ~isempty(dir(fullfile(gui_data.save_path,'*.tif')));
atlas_slices_present = ~isempty(gui_data.save_path) && ...
    exist(fullfile(gui_data.save_path,'histology_ccf.mat'),'file');
atlas_alignment_present = ~isempty(gui_data.save_path) && ...
    exist(fullfile(gui_data.save_path,'atlas2histology_tform.mat'),'file');
neuropixels_annotations_present = ~isempty(gui_data.save_path) && ...
    exist(fullfile(gui_data.save_path,'probe_ccf.mat'),'file');

% % Enable/disable appropriate menu options
% gui_data.menu.preprocess.Enable = raw_images_present | processed_images_present;
% gui_data.menu.preprocess.Children(end).Enable = raw_images_present;
% [gui_data.menu.preprocess.Children(1:end-1).Enable] = deal(processed_images_present);
% 
% gui_data.menu.atlas.Enable = processed_images_present;
% [gui_data.menu.atlas.Children(1:end-1).Enable] = deal(processed_images_present & atlas_slices_present);
% 
% gui_data.menu.annotation.Enable = atlas_alignment_present;
% gui_data.menu.view.Enable = atlas_alignment_present;


% Set text
image_path_text = sprintf('Raw image path:       %s',strrep(gui_data.image_path,filesep,repmat(filesep,1,2)));
save_path_text = sprintf('Processing save path: %s',strrep(gui_data.save_path,filesep,repmat(filesep,1,2)));

% Check for present files
% (images)
if raw_images_present
    n_raw_images = length(dir(fullfile(gui_data.image_path,'*.tif')));
else
    n_raw_images = 0;
end
n_raw_images_text = sprintf('Raw images: %d',n_raw_images);

if processed_images_present
    n_processed_images = length(dir(fullfile(gui_data.save_path,'*.tif')));
else
    n_processed_images = 0;
end
n_processed_images_text = sprintf('Processed images: %d',n_processed_images);

% (alignment)
if atlas_slices_present
    histology_atlas_text = 'Histology atlas slices: YES';
else
    histology_atlas_text = 'Histology atlas slices: NO';
end

if atlas_alignment_present
    alignment_text = 'Histology-atlas alignment: YES';
else
    alignment_text = 'Histology-atlas alignment: NO';
end

% (annotations)
if neuropixels_annotations_present
    annotations_text = 'Neuropixels probe annotations: YES';
else
    annotations_text = '';
end
gui_text = { ...
    '\bf --File paths \rm', ...
    image_path_text,save_path_text,'\newline', ...
    '\bf --Images \rm', ...
    n_raw_images_text,n_processed_images_text, '\newline', ...
    '\bf --Atlas alignment \rm', ...
    histology_atlas_text,alignment_text, '\newline', ...
    '\bf --Annotations \rm', ...
    annotations_text};

set(gui_data.gui_text,'String',gui_text(cellfun(@(x) ~isempty(x),gui_text)))

end