#!/bin/bash

### source your EMAN2.1 here (not beta!! beta didn't support yet mrcs)
#source /home/sharov/soft/EMAN2.1/eman2.bashrc

### Script works only with unaligned FEI MRC 16-bit stacks (FoilHole*_Data_*_frames.mrc) from latest EPU version
### By default it alignes all frames to the total exposure (-atm parameter) which is added to the stack before alignment starts
### One can adjust -fod and/or -kit parameter in case motioncorr fails to align the frames

### input parameters ###
prog="/usr/local/bin/motioncorr_v2.1"   #Path to the motioncorr executable
fod="2"                                 #Number of frame offset for frame comparison
logs="logs"                             #Folder for per-stack log files

### create log files temp directory: 1 log per input file
[ -f ${PWD}/*.log ] && rm -f ${PWD}/*.log
[ -d ${logs} ] && rm -rf ${logs}
mkdir ${logs}

### select input folder with unaligned stacks and total sums
echo "Choose input directory with UNaligned STACKS and total SUMS: "
input_folder=`zenity --file-selection --directory --title="Choose input directory with UNaligned STACKS and total SUMS" --file-filter=*.mrc`
[ "$?" -ne 0 ] && echo "Script stopped!" && exit 1
echo -n "${input_folder}"

### create list of files and check for errors
ls ${input_folder}/ | sed -rn 's/FoilHole_[0-9]*_Data_[0-9]*_([^\.]+)\.mrc/\1\t\0/p' | sort | cut -f2 > list_sorted
[ `grep "_frames.mrc" list_sorted | wc -l` -ne `grep -v "_frames.mrc" list_sorted | wc -l` ] && echo -e "\nNumber of stacks and total sums are different!" && exit 1

###any other checks?

### count frames in initial stacks
example=`sed -n '/_frames/{p;q;}' list_sorted`
num_frames=`e2iminfo.py -H ${example} | grep "MRC.nz:" | sed 's/[^0-9]*//g'`
[ "$?" -ne 0 ] && echo -e "\nCannot find e2iminfo.py command! Is EMAN2 sourced?" && exit 1
((num_frames++))

### select output folder for aligned stacks
echo -e "\nChoose output directory for aligned STACKS and sums: "
output_folder=`zenity --file-selection --directory --title="Choose output directory for aligned STACKS and sums"`
[ "$?" -ne 0 ] && echo "Script stopped!" && exit 1
[ "${input_folder}" == "${output_folder}" ] && echo "Output folder cannot be the same as input!" && exit 1
echo -n "${output_folder}"

### convert stacks and add total exposure (90 clockwise rotated)
for name in `cat list_sorted | grep "_frames.mrc" | sed "s/_frames.mrc//g"`
do

# normalize and threshold
echo -e "\nNormalising stack: ${name}_frames.mrc..."
e2proc2d.py ${name}_frames.mrc ${output_folder}/${name}_stackunali.mrcs --process=normalize.edgemean --process=threshold.clampminmax.nsigma:nsigma=4
[ "$?" -ne 0 ] && echo "Stack normalisation or thresholding failed!" && exit 1

# add total exposure
echo "Adding total sum: ${name}.mrc..."
e2proc2d.py ${name}.mrc ${output_folder}/${name}_stackunali.mrcs --rotate=90 --process=normalize.edgemean --process=threshold.clampminmax.nsigma:nsigma=4
[ "$?" -ne 0 ] && echo "Addition of total exposure to the stack failed!" && exit 1

# rename stack for motioncorr
mv ${output_folder}/${name}_stackunali.mrcs ${output_folder}/${name}_stackunali.mrc

### run motion correction for mrc stack, output corrected stack and sum
### "-atm" parameter will align all frames to the last one - total exposure
timeout -s 9 1m ${prog} ${output_folder}/${name}_stackunali.mrc -fod ${fod} -ssc 1 -fct ${output_folder}/${name}_movie.mrc -fcs ${output_folder}/${name}_sumcorr.mrc -flg ${logs}/${name}_frames.log -dsp 0 -atm -${num_frames}

### check for errors
if [ "$?" -ne 0 ]
then
timeout -s 9 1m ${prog} ${output_folder}/${name}_stackunali.mrc -fod ${fod} -ssc 1 -fct ${output_folder}/${name}_movie.mrc -fcs ${output_folder}/${name}_sumcorr.mrc -flg ${logs}/${name}_frames.log -dsp 0 -kit 2.0 -atm -${num_frames}
echo "${name}_frames.mrc" >> ${PWD}/movies_higherror.log
fi
[ $? -ne 0 ] && echo "${name}_frames.mrc" >> ${PWD}/movies_unaligned.log

#rename back aligned stack to relion convention "*_movie.mrcs"
[ -f ${output_folder}/${name}_movie.mrc ] && mv ${output_folder}/${name}_movie.mrc ${output_folder}/${name}_movie.mrcs

#add successfully aligned stack to log file
echo "${name}_frames.mrc" >> ${PWD}/movies_aligned.log
done

### the end
echo "Finished: your aligned stacks are in: ${output_folder}/*_movie.mrcs
          your aligned sums are in: ${output_folder}/*_sumcorr.mrc
          ========================================================
          Aligned images are in -> movies_aligned.log
          Aligned images with 2.0 pixel error are in -> movies_higherror.log
          UNaligned images are in -> movies_unaligned.log
          Log files for each image are in -> ${logs}/ folder"
