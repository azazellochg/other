other
=====

###Other bash scripts

#####align_frames.sh

Script reads FEI mrc stack files (*_frames.mrc, 7 frames) from latest EPU version, adds total exposure to the stack and runs motioncorr.

---
#####picker

The simple script to run gEMpicker software will produce EMAN1 .box files with particle coordinates. User may also ask to create .box files for particles within certain threshold range.

---
#####prep_montage

This script produces mount (both img and mrc) images from spotscan images (acquired on CM120) and also perform block convolution with low-pass filtering

---
#####prep_movie - DISCONTINUED script :( DO NOT USE!

The script looks for raw and tif files in current directory (including subdirectories) and produces a list.txt: frames/average tif

---
#####process_serialEM_montage

The script will split SerialEM mrc stacks (acquired on F20) into separate mrc files and produce a stack of power spectrums, thresholded and masked.

---
#####spotscan_clean_boxes

This script processes box files from CM120 spotscan (taken with 1024x1024px Gatan CCD camera) to remove particles on the border between montaged images and also the boxes outside micrograph.

---
