This pipeline aligns histology images to the Allen CCF.

Requires 
- the Allen CCF atlas ([download here](http://data.cortexlab.net/allenCCF/))
- [The npy-matlab repository](http://github.com/kwikteam/npy-matlab)

This was made with inspiration from SHARP-Track by Philip Shamash (https://github.com/cortex-lab/allenCCF, https://www.biorxiv.org/content/10.1101/447995v1). It mostly serves the same goals, but has different interfaces (most notably in the histology/CCF matching step) and saves some extra information (like the full CCF coordinates for each CCF slice), which was easier to build new compared to modifying the old.

All functions are listed in the 'demo_histology_pipeline.m' file.

## Histology preprocessing

### AP_process_histology
```matlab
AP_process_histology(im_path); % If size information in the OME-TIFF metadata, resize to CCF scale
AP_process_histology(im_path,resize_factor); % For user-specified resizing
```
1) Downsample and white-balance slides

Colors will be automatically white-balanced, user indicates color of each channel

![test image](https://github.com/petersaj/AP_scripts_cortexlab/blob/master/wiki/histology/AP_process_histology_1.png)

2) Extract slice images from slides

Select slices to extract and save: 
- slices will be automatically detected, left-clicking will select that slice
- right-clicking will draw a manual region to extract
- left-clicking on an existing selected region will unselect it
- spacebar moves to the next slide. 
![test image](https://github.com/petersaj/AP_scripts_cortexlab/blob/master/wiki/histology/AP_process_histology_2.png)

### AP_rotate_histology
```matlab
AP_rotate_histology(slice_path);
```

Draw reference line (midline) to center and rotate slices.
![test image](https://github.com/petersaj/AP_scripts_cortexlab/blob/master/wiki/histology/AP_rotate_histology.png)

## Histology CCF alignment

### AP_grab_histology_ccf
```matlab
AP_grab_histology_ccf(tv,av,st,slice_path);
```

This function is to match histology slices to their corresponding CCF slices. The left plot is the histology slices (scrollable by 1/2), the right plot is the 3D CCF atlas which is rotatable with the arrow keys and scrollable in/out of the plane with the mouse wheel. Typical use would be: 

- Match the rotation of the histology slices with the rotation of the CCF using the arrow keys. This is usually easiest using a slice with landmarks sensitive to asymmetries, e.g. the hippocampus or anterior commisure.
- Once the angle is set, the CCF slice location can be set with the scroll wheel. For each histology slice, scroll to the matching CCF slice and hit 'Enter' to set that slices' location.
- Once all histology slices are set, hit 'Escape' to save and quit

![test image](https://github.com/petersaj/AP_scripts_cortexlab/blob/master/wiki/histology/AP_grab_histology_ccf.png)

### AP_auto_align_histology_ccf
```matlab
AP_auto_align_histology_ccf(tv,av,st,slice_path);
```

This function auto-aligns each corresponding histology and CCF slice by slice outline only

![test image](https://github.com/petersaj/AP_scripts_cortexlab/blob/master/wiki/histology/AP_auto_align_histology_ccf.png)

### AP_manual_align_histology_ccf
```matlab
AP_manual_align_histology_ccf(tv,av,st,slice_path);
```

If the auto-alignment didn't work on some slices, they can be manually fixed with this function. Placing > 3 corresponding points on the histology and CCF slices creates a new alignment using those control points, and 'Escape' saves and quits.

From auto-alignment:
![test image](https://github.com/petersaj/AP_scripts_cortexlab/blob/master/wiki/histology/AP_manual_align_histology_ccf_1.png)

After manual control-point alignment: 
![test image](https://github.com/petersaj/AP_scripts_cortexlab/blob/master/wiki/histology/AP_manual_align_histology_ccf_2.png)

## Aligned histology usage

After the above steps, each histology slice is associated with a CCF slice, a transform between slices, and the location in CCF space for each slice. Some current uses for this: 

### AP_view_aligned_histology
```matlab
AP_view_aligned_histology(st,slice_path);
```
Display the histology slices with overlaid boundaries, hover over region to display name 

### AP_view_aligned_histology_volume
```matlab
AP_view_aligned_histology_volume(tv,av,st,slice_path,1);
```
Threshold and display histology channel in 3D CCF space

![test image](https://github.com/petersaj/AP_scripts_cortexlab/blob/master/wiki/histology/AP_view_aligned_histology_volume.png)

### AP_get_probe_histology
```matlab
AP_get_probe_histology(tv,av,st,slice_path);
```
Get trajectory of dyed probe in CCF coordinates and areas.

Enter the number of probes, draw lines on slices with visible tract marks corresponding to the probe (select the relevant probe by number, e.g. '1' to draw a line for probe 1), 'Escape' to save and quit

![test image](https://github.com/petersaj/AP_scripts_cortexlab/blob/master/wiki/histology/AP_get_probe_histology_1.png)

This will draw a line of best fit through the points and extract all brain areas along that trajectory. NOTE: it is unusual that the exact end of the probe can be visualized and accurately established from histology alone, so this step saves the entire trajectory and the next step aligns it to electrophysiology.
![test image](https://github.com/petersaj/AP_scripts_cortexlab/blob/master/wiki/histology/AP_get_probe_histology_2.png)

### AP_align_probe_histology
```matlab
AP_align_probe_histology(st,slice_path,spike_times,spike_templates,template_depths);
```
This is a first-pass attempt at this function.

Match the trajectory of the probe through the CCF with electrophysiological signatures. This currently relies on kilosort-convention of variables: 'spike_times' n spikes x 1 vector of all spike times, 'spike_templates' n spikes x 1 vector of the templates corresponding to each spike time, and 'template_depths' n templates x 1 vector of the depth of each template.

This will plot the template depth vs spike rate (left), the multiunit correlation (center), and the CCF areas from the trajectory (right). Press (shift) up/down to scroll the CCF areas and match to electrophysiology landmarks. 'Escape' will save and quit. 

The final useful output of this is a file/structure 'probe_ccf' which contains: 
- probe_ccf.trajectory_coords: the 3D CCF coordinates of the probe trajectory
- probe_ccf.trajectory_areas: the annotated CCF areas for each point
- probe_ccf.probe_depths: the relative depth of the probe to that point (e.g. 0 is the top of the probe and ~3840 is the end)

![test image](https://github.com/petersaj/AP_scripts_cortexlab/blob/master/wiki/histology/AP_align_probe_histology.png)
