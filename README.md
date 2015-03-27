other
=====

###Other bash scripts

#####movie/movie_prep_parallel.sh and movie/movie_align.sh

The two scripts read FEI mrc stack files (*_frames.mrc, 7 frames) from EPU version 1.4.3.1159REL, add total exposure to the stack (in parallel) and run motioncorr (non-parallel).

---
#####picker

The simple script to run gEMpicker software will produce EMAN2 *.box files with particle coordinates.

---
#####prep_montage

This script produces mount (both *.img and *.mrc) images from spotscan images (acquired on CM120) and also performs block convolution with low-pass filtering

---
#####process_serialEM_montage

The script will split SerialEM mrc stacks (acquired on Tecnai F20) into separate mrc files and produce a stack of power spectrums, thresholded and masked (if required).

---
#####spotscan_clean_boxes

This script processes box files for images, acquired on Philips CM120 in spotscan mode (taken with 1024x1024px Gatan CCD camera) to remove both particles on the border between montaged images and the boxes outside micrograph.

---
