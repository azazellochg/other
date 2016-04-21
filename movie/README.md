#### Preprocessing of the movies, acquired on Falcon II camera with EPU*
##### Preparation, stack creation, CTF estimation, motioncorr (+optical flow) run

Gabor Papai, Gregory Sharov (c) 2015-2016

1. Run *[clean.sh](clean.sh)* script. It will create a list of unnecessary metadata files for subsequent removal.
2. Run *[check.sh](check.sh)* script. It will check if there is a corresponding frame stack for each total exposure and rename files if requested.
3. Run *[movie_prep_parallel.sh](movie_prep_parallel.sh)* script. It will join frame stacks (7 frames) and total exposure into raw unaligned stacks, in parallel (8 cores).
4. Run *[movie_align.sh](movie_align.sh)* script. Afterwards, check log files and sort aligned sums and/or movies by average frame shift. If you ran *movie_ctf.sh* in advance, you can provide *ctfrings.txt* file and select input files according to max resolution, estimated by CTFFIND4.
 
---
  * *[movie_align2.sh](movie_align2.sh)* script: this script replaces steps 3-4 in case you want to use frame stacks only (total exposure can be removed).
  * *[movie_ctf.sh](movie_ctf.sh)* script: it will launch CTFFIND4 in parallel (8 cores) on either movie stacks or single images. You should only provide input folder with *.mrc* or *.mrcs* files. In output *ctfrings.txt* file you will find image names with defocus values and maximum detected resolution.
  * *[movie_xmipp.sh](movie_xmipp.sh)* script: it will run xmipp optical flow alignment on movie frames that were pre-aligned with motioncorr. Input folder with movies should be *aligned_movies_motioncorr*.

At the very end, user has many possibilities to sort micrographs by defocus values, max resolution, average frame shift and discard bad micrographs. Of course, manual inspection of micrographs remains necessary.

*Currently these scripts only support movies acquired as a single-stack in EPU.
