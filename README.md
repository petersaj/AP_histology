Toolbox for aliging histology images to the Allen CCF mouse atlas.

A video demonstration of this toolbox is available here (note - old interface): https://www.youtube.com/watch?v=HKm_G17Wc6g

Inspiration from SHARP-Track by Philip Shamash (https://www.biorxiv.org/content/10.1101/447995v1).

# Installation 
* download the Allen CCF mouse atlas [download here](https://osf.io/fv7ed/) *
* clone this repository
* add both the CCF mouse atlas and repository to the matlab path
* [The npy-matlab repository](http://github.com/kwikteam/npy-matlab)

*(note on where these files came from: they are a re-formatted version of [the original atlas](http://download.alleninstitute.org/informatics-archive/current-release/mouse_ccf/annotation/ccf_2017/), which has been [processed with this script](https://github.com/cortex-lab/allenCCF/blob/master/setup_utils.m))

# Histology preprocessing

## Toolbox menu
Open the toolbox menu with:
```matlab
AP_histology
```
This is the menu for to run all toolbox functions.

![image](https://github.com/petersaj/AP_histology/blob/master/wiki/menu_gui.png)

The menu functions are described below.


## File selection
Set the location of the raw images and save path

* Set the raw image path with `File selection > Set raw image path`
* Set the processing save path with `File selection > Set processing save path`

## Image preprocessing 
### Create slice images
1) Downsample image sizes (if desired)
2) Set white balance and color for each channel
3) Extract slices into individual images (if not already)

In the initial dialog box, select the image downsampling factor (e.g. 2 reduces image size to 1/2) and whether images are individual slices (1 = slices, 0 = not slices, e.g. slides)

A montage of images will be shown for each channel, user selects white balance and color:
![image](https://github.com/petersaj/AP_histology/blob/master/wiki/AP_process_histology_1.png)

To create individual slice images from slide imges: 
- slices will be automatically detected, left-clicking will select that slice
- right-clicking will draw a manual region to extract
- left-clicking on an existing selected region will unselect it
- spacebar moves to the next slide. 
![image](https://github.com/petersaj/AP_histology/blob/master/wiki/AP_process_histology_2.png)

### Rotate & center slices
Draw reference line (e.g. the midline):
![image](https://github.com/petersaj/AP_histology/blob/master/wiki/AP_rotate_histology.png)

These reference lines will used to centered and rotate the slice images, which are then saved.

### Re-order slices
Images can be re-ordered (click to select order)

### Flip slices
Images can be flipped (left/right or up/down)

## Atlas alignment

### Choose histology atlas slices
This function is to match histology slices to their corresponding CCF slices. The left plot is the histology slices (scrollable by 1/2), the right plot is the 3D CCF atlas which is rotatable with the arrow keys and scrollable in/out of the plane with the mouse wheel. Typical use would be: 

- Rotate the CCF atlas until the rotation matches that of the histology slices. This is usually easiest using a slice with landmarks sensitive to asymmetries, e.g. the hippocampus or anterior commisure.
- Once the angle is set, the CCF slice location can be set with the scroll wheel. For each histology slice, scroll to the matching CCF slice and hit 'Enter' to set that slices' location.
- Once all histology slices are set, close the GUI to save and quit.
![image](https://github.com/petersaj/AP_histology/blob/master/wiki/AP_grab_histology_ccf.png)

### Auto-align histology/atlas slices
This function auto-aligns each corresponding histology and CCF slice by slice outline.
Alignments which need manual correction can be fixed in the next step.
![image](https://github.com/petersaj/AP_histology/blob/master/wiki/AP_auto_align_histology_ccf.png)

### Manual-align histology/atlas slices
If the auto-alignment didn't work on some slices, they can be manually fixed with this function. Placing > 3 corresponding points on the histology and CCF slices creates a new alignment using those control points, and 'Escape' saves and quits.

From auto-alignment:
![image](https://github.com/petersaj/AP_histology/blob/master/wiki/AP_manual_align_histology_ccf_1.png)

After manual control-point alignment: 
![image](https://github.com/petersaj/AP_histology/blob/master/wiki/AP_manual_align_histology_ccf_2.png)

## Annotation

### Neuropixels probes
Get trajectory of dyed probe in CCF coordinates and areas.

Draw lines on slices with visible tract marks corresponding to the probe (select the relevant probe by number, e.g. '1' to draw a line for probe 1). Lines for a given probe can be (and usually are) drawn across multiple slices.
![test image](https://github.com/petersaj/AP_histology/blob/master/wiki/AP_get_probe_histology_1.png)

The final probe trajectory will be a line of best fit through all marked points, and brain areas will be saved along that trajectory. NOTE: it is unusual that the exact end of the probe can be visualized and accurately established from histology alone, so this step saves the entire trajectory and the next step aligns it to electrophysiology.
![test image](https://github.com/petersaj/AP_histology/blob/master/wiki/AP_get_probe_histology_2.png)

## View

### View aligned histology

Display the histology slices with overlaid boundaries, hover over region to display name 

# Major change log
2024-02-16 - Split re-order/flip GUIs: re-ordering is now a simpler click interface
2023-11-02 - Created menu GUI for easier interfacing re-structured/improve much of the code, improved auto-align

