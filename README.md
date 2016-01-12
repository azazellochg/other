other
=====

###Other bash scripts

#####gEMpicker

The simple script to run gEMpicker software, that will produce EMAN *.box files with particle coordinates.

---

#####gnuplot

The script will plot a distribution of a single parameter using *gnuplot*.

---

#####movie/*.sh

These scripts read FEI mrc stack files (*_frames.mrc, 7 frames) from EPU version 1.4.3.1159REL, add total exposure to the stack (in parallel), run CTFFIND4 on these unaligned stacks and then run motioncorr to produce aligned sums/movies (on GPU).

---

#####process_serialEM_montage

The script will split SerialEM mrc stacks (acquired on Tecnai F20) into separate mrc files and produce a stack of power spectrums, thresholded and masked (if required).

---

#####sort_mics

Few commands to sort micrographs by max resolution (estimated by CTFFIND4) / defocus values.

---

#####spotscan_clean_boxes

This script processes box files for images, acquired on Philips CM120 in spotscan mode (taken with 1024x1024px Gatan CCD camera) to remove both particles on the border between montaged images and the boxes outside micrograph.
