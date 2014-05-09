other
=====

###Other bash scripts

#####prep_montage

This script produces mount (both img and mrc) images from spotscan images (acquired on CM120) and also perform block convolution with low-pass filtering

---
#####process_serialEM_montage

The script will split SerialEM mrc stacks (acquired on F20) into tiff files, estimate CTF for each image and produce a stack of power spectrums, thresholded and masked.

---
#####spotscan_clean_boxes

This script processes box files from CM120 spotscan (taken with 1024x1024px Gatan CCD camera) to remove particles on the border between montaged images and also the boxes outside micrograph.

---
