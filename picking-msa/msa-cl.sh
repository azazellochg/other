#!/bin/bash
# This script should be launched after prepare-files.sh.
# It will split picked particle stack into separate groups,
# according to the picking reference and launch MSA+classification for each group.
# In the end, user can select good or bad classums.

###### USER INPUT ########################################
input_particles="particles"                             # input IMAGIC particle stack (.img file + .plt file) produced by prepare-files.sh
input_references="picking_references"                   # input picking references (.img file) produced by prepare-files.sh
ref_size=80                                             # box size of references, px
msa_mask=38                                             # mask radius, px. Use same value as in gEMpicker/gAutomatch
ptcls_per_cl=200                                        # approx number of particles per class for MSA
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
awk '{print $3}' ${input_particles}.plt | sort -n | uniq -c >> ${input_particles}.tmp
[ -f msa-cl.log ] && rm -f msa-cl.log

# populate header file with particleID=52, CCC=20, refID=107
echo "Populating header file with particleID=52, CCC=20, refID=107..."
echo "! IMAGIC program: headers ----------------------------------------------" >> msa-cl.log
${imagic_dir}/stand/headers.e <<EOF >> msa-cl.log
WRITE
INDEX
NUMBER
52;20;107
PLT
${input_particles}.plt
${input_particles}
EOF

# extract particles into groups according to each picking reference
echo -ne "Extracting particles into groups according to each picking reference...\r"
[ -d processing ] && rm -rf processing
mkdir processing
for i in `seq 1 ${numRef}`
do
        echo "! IMAGIC program: aliselct ---------------------------------------------" >> msa-cl.log
        ${imagic_dir}/align/aliselct.e <<EOF >> msa-cl.log
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
        echo "! IMAGIC program: inc2dmenu --------------------------------------------" >> msa-cl.log
        ${imagic_dir}/incore/inc2dmenu.e MODE NORM_VARIANCE <<EOF >> msa-cl.log
WHOLE_IMAGE
processing/particles-ref$i
processing/particles-ref$i-norm
1.0
NO
EOF
done
echo "Extracting particles into groups according to each picking reference...FINISHED"

# perform ali-rot if required: 3 iterations, MEDIUM precision, -180/180 degrees
alirot_suffix="" # set default suffix to nothing
if [ ${do_ali_rot} -eq 1 ];then
        echo -ne "Performing rotational alignment: 3 iterations, MEDIUM precision, -180/180 degrees...\r"
        for i in `seq 1 ${numRef}`
        do
        echo "! IMAGIC program: excopy -----------------------------------------------" >> msa-cl.log
        ${imagic_dir}/incore/excopy.e <<EOF >> msa-cl.log
2D_IMAGES/SECTIONS
EXTRACT
${input_references}
processing/ref$i
INTERACTIVE
$i
EOF
        echo "! IMAGIC program: alidir -----------------------------------------------" >> msa-cl.log
        ${imagic_dir}/align/alidir.e MODE_ALIGN ROTATIONAL <<EOF >> msa-cl.log
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
echo "Performing rotational alignment: 3 iterations, MEDIUM precision, -180/180 degrees...FINISHED"

# when calculated number of classes = 0 or 1, simply calculate total sum
totsum() {
echo "! IMAGIC program: summer -----------------------------------------------" >> msa-cl.log
${imagic_dir}/incore/summer.e <<EOF >> msa-cl.log
TOTAL_SUM
processing/particles-ref$i-norm${alirot_suffix}
processing/particles-ref$i-cl1
none
EOF
}

# create MSA mask
echo "Creating MSA mask..."
echo "! IMAGIC program: test-image ----------------------------------------------" >> msa-cl.log
${imagic_dir}/stand/testim.e <<EOF >> msa-cl.log
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
echo "! IMAGIC program: msa --------------------------------------------------" >> msa-cl.log
${imagic_dir}/msa/msa.e <<EOF >> msa-cl.log
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
echo "! IMAGIC program: classify ---------------------------------------------" >> msa-cl.log
${imagic_dir}/msa/classify.e <<EOF >> msa-cl.log
IMAGES/VOLUMES
processing/particles-ref$i-norm${alirot_suffix}
0
10
YES
${clsNum}
processing/particles-ref$i-cl${clsNum}
EOF
echo "! IMAGIC program: classum ----------------------------------------------" >> msa-cl.log
${imagic_dir}/msa/classum.e <<EOF >> msa-cl.log
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
        echo -ne "Calculating total sum for group ${i}/${numRef}...\r"
        totsum
        echo "Calculating total sum for group ${i}/${numRef}...OK"
elif [ $clsNum -eq 2 ]
then
        clsNum=3
        echo -ne "Running MSA with 20 eigs for 20 iterations: group ${i}/${numRef}...\r"
        msa
        echo "Running MSA with 20 eigs for 20 iterations: group ${i}/${numRef}...OK"
else
        echo -ne "Running MSA with 20 eigs for 20 iterations: group ${i}/${numRef}...\r"
        msa
        echo "Running MSA with 20 eigs for 20 iterations: group ${i}/${numRef}...OK"
fi
done
echo "Running MSA: FINISHED!"

# move resulting sums/classums to output folder for inspection
echo "Move resulting sums/classums to output folder for inspection..."
[ -d classums ] && rm -rf classums
mkdir classums
filelist=`ls processing/ | egrep 'particles\-ref[0-9]{1,3}\-(cl[0-9]{1,3}.img)' | sed 's/.img//g' | sort -V | tail -n+2`
firstfile=`ls processing/ | egrep 'particles\-ref[0-9]{1,3}\-(cl[0-9]{1,3}.img)' | sed 's/.img//g' | sort -V | head -n1`
cp processing/${firstfile}.hed classums/all_sums.hed
cp processing/${firstfile}.img classums/all_sums.img
for i in `echo ${filelist}`
do
        cp processing/${i}.* classums/
        echo "! IMAGIC program: append -----------------------------------------------" >> msa-cl.log
        ${imagic_dir}/stand/append.e <<EOF >> msa-cl.log
classums/${i}
classums/all_sums
EOF
done

# create log file with statistics
echo "Creating log file with statistics..."
[ -f classums/all_sums.log ] && rm -f classums/all_sums.log
for i in `seq 1 ${numRef}`
do
        file_lis=`ls processing/particles-ref$i-cl*.lis 2> /dev/null`
        if [ $? -eq 0 ]; then
                echo "Ref#     Class#     Members#     Intra-class variance" >> classums/all_sums.log
                sed -n '/Classes sorted by INTRA/,/Classes sorted by/p' ${file_lis} | tail -n+6 | head -n -3 | sed 's/E/e/g' | awk -v i=$i '{printf "%5d%10d%10d          %.04f\n",i,$3,$5,$2}' >> classums/all_sums.log
        fi
done
echo -e "DONE!\n------------------------------------------------------------------------------------------"
echo -e "Output classums are in classums/all_sums.img. Intra-class variance stats is in classums/all_sums.log.
General log file: msa-cl.log\n------------------------------------------------------------------------------------------
Now compare the class averages in classums/all-sums file with ${input_references}.
Then you can either select good classums and redo the picking (maybe iterate this procedure 2-3 times)
or select bad classums into plt file and run make_star.sh script that will generate an updated star file with good particles."

# clean up
[ $debug -eq 0 ] && rm -rf _imagic.dff particles.tmp processing/*.plt processing/msa-ref*
