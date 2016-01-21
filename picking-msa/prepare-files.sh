#!/bin/bash
# This script adds output from gempicker run to relion star file (into particles_new.star).
# After gAutomatch picking user already has a star file with all the info.
# In both cases, the script creates IMAGIC stacks for both particles and references, preparing them for MSA run.
#
# User should have done particle extraction in Relion using coordinates obtained from gEMpicker/gAutomatch.
# Folder with picking results (see below), references and extracted particle stacks are needed (usually "Particles" folder in Relion)
#
###### USER INPUT #######################################
particles_extracted="particles.star"                    # input particle star file after extraction in relion
output="Micrographs"                                    # folder with picking results (gEMpicker: contains pik_coord folder | gAutomatch: contains *_gautopick.star files)

references="proj_for_pick_c4_new.mrcs"                  # specify only for gAutomatch: references stack (*.mrcs)

coarse="4"                                              # specify only for gEMpicker: N times mics were coarsed before gEMpicker run
coarsed_micsize="1024"                                  # specify only for gEMpicker: size of coarsed mics during gEMpicker run
particles_new="particles_new.star"                      # specify only for gEMpicker: output particle star file with gempicker info

coordinates="coordinates.star"                          # DO NOT CHANGE! only for gEMpicker: output coordinate star file name to be created
debug="1"                                               # if 0 - remove intermediate files
#########################################################

# This script needs EMAN2 and Relion to work
if [ -z `which relion` ]; then
        echo "Relion NOT found!" && exit 1
fi
if [ -z $EMAN2DIR ]; then
        echo "EMAN2 NOT found!" && exit 1
fi

# check input
[ ! -f ${particles_extracted} ] && echo "${particles_extracted} file not found! Did you extract particles in Relion?" && exit 1
micField=`grep "_rlnMicrographName" ${particles_extracted} | cut -d'#' -f2`
ptclField=`grep "_rlnImageName" ${particles_extracted} | cut -d'#' -f2`
if [ ! -f `awk -v micField=$micField 'NF>3{print $micField}' ${particles_extracted} | head -n1` ] || [ ! -f `awk -v ptclField=$ptclField 'NF>3{print $ptclField}' ${particles_extracted} | head -n1 | cut -d'@' -f2` ]
then
        echo "ERROR! Micrographs or particles, specified in input ${particles_extracted} file, not found. Check your star file!" && exit 1
fi

### BEGIN gEMpicker_parse function
gEMpicker_parse() {
# gEMpicker txt file: $2=CC, $3=X, $4=Y, $5=box, $6=ref#, $7=angle
# txt to box: (X;Y)-->(micsize-Y-box/2,X-box/2+1)
# box to box: (X,Y)-->(coarse*X,coarse*Y)
# box to relion: (X,Y)-->(X+box/2,Y+box/2)

# create new header for coordinates star file
[ -f ${coordinates} ] && rm -f ${coordinates}
echo "data_

loop_ 
_rlnMicrographName #1 
_rlnCoordinateX #2 
_rlnCoordinateY #3
_rlnAnglePsi #4 
_rlnAutopickFigureOfMerit #5 
_rlnClassNumber #6" > ${coordinates}

# grep results from gEMpicker
cd ${PWD}/${output}/pik_coord
echo "Acquiring results from gempicker..."
awk -v coarse=$coarse -v micsize=$coarsed_micsize '(FNR>1){ printf "Micrographs/%s\t%.6f\t%.6f\t%.6f\t%.6f\t%d\n", FILENAME, ($5*coarse/2)+coarse*(micsize-$4-$5/2), ($5*coarse/2)+coarse*($3-$5/2+1), -$7, $2, $6 }' *.txt >> ../../${coordinates}
sed -i 's/.txt/.mrc/' ../../${coordinates}
cd ../../

# copy all refs to a stack for further analysis
[ -f picking_references.mrcs ] && rm -f picking_references.mrcs
for i in `awk 'NR>1{print $2}' ${PWD}/${output}/ListSch.txt`
do
        e2proc2d.py ${i} picking_references.mrcs > /dev/null 2>&1
done
e2proc2d.py picking_references.mrcs picking_references.img > /dev/null 2>&1
echo "New coordinate star file created: ${coordinates}"

# create new header for particles_new star file
colNum=`grep -c "_rln" ${particles_extracted}`
((colNum++))
awk 'NF<3{print}' ${particles_extracted} | sed '$ d' > ${particles_new}
echo "_rlnAnglePsi #$colNum " >> ${particles_new}
((colNum++))
echo "_rlnAutopickFigureOfMerit #$colNum " >> ${particles_new}
((colNum++))
echo "_rlnClassNumber #$colNum " >> ${particles_new}

# remove headers from input star files
[ -d tmp ] && rm -rf tmp
mkdir tmp
awk 'NF>3{print}' ${coordinates} > tmp/${coordinates}
awk 'NF>3{print}' ${particles_extracted} > tmp/${particles_extracted}

# internal check
check_star() {
        awk 'NR==FNR{a[$1];b[$2];c[$3];next}($1 in a&&$2 in b&&$3 in c){print}' tmp/${coordinates} tmp/${particles_extracted} >> tmp/${particles_new}
        [ `wc -l tmp/${coordinates} | awk '{print $1}'` -ne `wc -l tmp/${particles_extracted} | awk '{print $1}'` ] && echo "Error!" && exit 1
}
[ $debug -eq 1 ] && check_star

# add new fields to particles_extracted star file
awk '{print $4,$5,$6}' tmp/${coordinates} > tmp/${coordinates}.tmp
pr -mJt -s' ' tmp/${particles_extracted} tmp/${coordinates}.tmp >> ${particles_new}
echo "New particle star file with gEMpicker info created: ${particles_new}"
particles_new=`echo ${particles_new} | sed 's/.star//'`
}
### END gEMpicker_parse function

### BEGIN gAutomatch_parse function
gAutomatch_parse() {
# renumber references
echo "Acquiring results from gAutomatch..."
refNo=`grep "_rlnClassNumber" ${particles_extracted} | cut -d'#' -f2`
if [ `awk -v refNo=$refNo '$refNo==0{print $refNo}' ${particles_extracted} | wc -l` -ne 0 ];then
        awk -v refNo=$refNo 'NF<3||$refNo=$refNo+1' ${particles_extracted} > ${particles_extracted}.tmp
        mv ${particles_extracted}.tmp ${particles_extracted}
fi

# convert them to IMAGIC
if [ -f ${references} ];then
        e2proc2d.py ${references} picking_references.img > /dev/null 2>&1
else
        echo "References not found: ${references}"
        exit 1
fi
}
### END gAutomatch_parse function

if [ ! -d ${output}/pik_coord ]; then
        gAutomatch_parse
        particles_new=`echo ${particles_extracted} | sed 's/.star//'`
else
        gEMpicker_parse
fi

# extract all particles and apply rotation to bring them into alignment with references
echo "Creating a single stack for all particles..."
`which relion_stack_create`  --i ${particles_new}.star --o ${particles_new} --apply_transformation 

# convert stack into imagic file and create a plt file with particleID, CCC, refID
echo "Converting the stack to IMAGIC..."
e2proc2d.py ${particles_new}.mrcs ${particles_new}.img
echo "Creating plt file with particleID, CCC and refID..."
field2=`grep "_rln" ${particles_new}.star | wc -l`
field1=$((field2-1))
awk -v a=$field1 -v b=$field2 'NF>3{print $a,$b}' ${particles_new}.star | nl > ${particles_new}.plt

# clean up
[ $debug -eq 0 ] && rm -rf tmp ${particles_new}.mrcs picking_references.mrcs 
echo "DONE! Output files:
--> Stack of aligned particles: ${particles_new}.img
--> File with particleID, CCC and refID: ${particles_new}.plt
--> Stack of picking references: picking_references.img"
