#!/bin/bash
# This script split aligned picked particle stack into separate groups,
# according to the picking reference and launch MSA for each group,

###### USER INPUT ########################################
input_particles="particles"                             # input IMAGIC particle stack (.img file + .plt file)
input_references="picking_references"                   # input picking references (.img file)
ref_size=80                                             # box size of references, px
msa_mask=38                                             # mask radius, px. Use same value as in gEMpicker/gAutomatch
ptcls_per_cl=100                                        # approx number of particles per class for MSA
imagic_dir="/usr/local/imagic/2014_08_22"               # IMAGIC root folder
do_ali_rot="1"                                          # perform rotational alignment with reference before MSA (1 - yes, 0 - no)
debug="1"                                               # if 0 - remove intermediate files
#########################################################

# load IMAGIC and check input
module load imagic/imagic
export IMAGIC_BATCH=1
([ ! -f ${input_particles}.hed ] || [ ! -f ${input_particles}.plt ] || [ ! -f ${input_references}.hed ]) && echo "No IMAGIC input files found!" && exit 1
numRef=`awk '{print $3}' ${input_particles}.plt |sort -n | uniq | tail -n1`
echo "Particles_per_reference Reference_number" > ${input_particles}.tmp
awk '{print $3}' ${input_particles}.plt |sort -n | uniq -c >> ${input_particles}.tmp

# populate header file with particleID=52, CCC=20, refID=107
echo "! IMAGIC program: headers ----------------------------------------------"
${imagic_dir}/stand/headers.e <<EOF
WRITE
INDEX
NUMBER
52;20;107
PLT
${input_particles}.plt
${input_particles}
EOF

# extract particles into groups according to each picking reference
[ -d processing ] && rm -rf processing
mkdir processing
for i in `seq 1 ${numRef}`
do
        echo "! IMAGIC program: aliselct ---------------------------------------------"
        ${imagic_dir}/align/aliselct.e <<EOF
EXTRACT
${input_particles}
INPUT_FILE
NO
INTERACTIVE
$i
processing/particles-ref$i
NO
EOF

        # normalize all images
        echo "! IMAGIC program: inc2dmenu --------------------------------------------"
        ${imagic_dir}/incore/inc2dmenu.e MODE NORM_VARIANCE <<EOF
WHOLE_IMAGE
processing/particles-ref$i
processing/particles-ref$i-norm
1.0
NO
EOF
done

# perform ali-rot if required: 3 iterations, MEDIUM precision, -180/180 degrees
alirot_suffix="" # set default suffix to nothing
if [ ${do_ali_rot} -eq 1 ];then
        for i in `seq 1 ${numRef}`
        do
        echo "! IMAGIC program: excopy -----------------------------------------------"
        ${imagic_dir}/incore/excopy.e <<EOF
2D_IMAGES/SECTIONS
EXTRACT
${input_references}
processing/ref$i
INTERACTIVE
$i
EOF
        echo "! IMAGIC program: alidir -----------------------------------------------"
        ${imagic_dir}/align/alidir.e MODE_ALIGN ROTATIONAL <<EOF
NO
IMAGES
ROTATIONAL
INPUT_REFERENCE_FROM_FILE
YES
TOTAL_AVERAGE
3
CCF
processing/particles-ref$i-norm
processing/particles-ref$i-norm-alirot
processing/ref$i
NO
$i
NO
-180,180
MEDIUM
5,${msa_mask}
NO
EOF
        done
        ## correct input msa file
        alirot_suffix="-alirot"
fi

# when calculated number of classes = 0 or 1, simply calculate total sum
totsum() {
echo "! IMAGIC program: summer -----------------------------------------------"
${imagic_dir}/incore/summer.e <<EOF
TOTAL_SUM
processing/particles-ref$i-norm${alirot_suffix}
processing/particles-ref$i-sum
none
EOF
}

# create MSA mask
echo "! IMAGIC program: test-image ----------------------------------------------"
${imagic_dir}/stand/testim.e <<EOF
processing/msa_mask
${ref_size},${ref_size}
REAL
DISC
${msa_mask}
EOF

for i in `seq 1 ${numRef}`
do

msa() {
# run MSA with 20 eigs for 20 iter
echo "! IMAGIC program: msa --------------------------------------------------"
${imagic_dir}/msa/msa.e <<EOF
NO
FRESH_MSA
MODULATION
processing/particles-ref$i-norm${alirot_suffix}
processing/msa_mask
processing/eig-ref$i
YES
20
20
processing/msa-ref$i
EOF

# use 10 out of 20 eigs
echo "! IMAGIC program: classify ---------------------------------------------"
${imagic_dir}/msa/classify.e <<EOF
IMAGES/VOLUMES
processing/particles-ref$i-norm${alirot_suffix}
0
10
YES
${clsNum}
processing/particles-ref$i-cl${clsNum}
EOF
echo "! IMAGIC program: classum ----------------------------------------------"
${imagic_dir}/msa/classum.e <<EOF
processing/particles-ref$i-norm${alirot_suffix}
processing/particles-ref$i-cl${clsNum}
processing/particles-ref$i-cl${clsNum}
NO
0
NONE
EOF
}

# calculate number of classes
numPtclsPerRef=`awk -v i=$i '$2==i{print $1}' ${input_particles}.tmp`
clsNum=`echo "scale=0;${numPtclsPerRef}/${ptcls_per_cl}" | bc`
if [ $clsNum -eq 0 ] || [ $clsNum -eq 1 ]
then
        totsum
elif [ $clsNum -eq 2 ]
then
        clsNum=3
        msa
else
        msa
fi
done

# move resulting sums/classums to output folder for inspection
[ -d classums ] && rm -rf classums
mkdir classums
filelist=`ls processing/ | egrep 'particles\-ref[0-9]{1,3}\-(cl[0-9]{1,3}.img|sum)' | sed 's/.img//g;s/.hed//g' | uniq | sort -V | tail -n+2`
firstfile=`ls processing/ | egrep 'particles\-ref[0-9]{1,3}\-(cl[0-9]{1,3}.img|sum)' | sed 's/.img//g;s/.hed//g' | uniq | sort -V | head -n1`
cp processing/${firstfile}.hed classums/all_sums.hed
cp processing/${firstfile}.img classums/all_sums.img
for i in `echo ${filelist}`
do
        cp processing/${i}.* classums/
        echo "! IMAGIC program: append -----------------------------------------------"
        ${imagic_dir}/stand/append.e <<EOF
classums/${i}
classums/all_sums
EOF
done
echo "Output classums are in classums/ folder. Now compare them with ${input_references}!"
