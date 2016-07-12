#!/bin/bash

#---input-parameters---
# input movies should be in 'raw_stacks' folder
program='/usr/local/bin/MotionCor2-03-16-2016'
pix="1.1"
dose="7.05"
patch="5 5" # this does not work! change the line 27 yourself
kv="300"
group="1"
frames="7"
#----------------------

[ -d aligned_sums_motioncor2 ] && echo "Please remove aligned_sums_motioncor2 folder and restart the script!" && exit 1
mkdir -p logs/motioncor2 aligned_sums_motioncor2
[ -f logs/avg_shift_motioncor2.log ] && rm -f logs/avg_shift_motioncor2.log
[ -f logs/motioncor2_failed.log ] && rm -f logs/motioncor2_failed.log
k=1
fr=$((frames*2))
total=`ls raw_stacks/ | wc -l`
suffix=`ls raw_stacks/ | head -n1 | awk -F "_" '{print $NF}'`
echo ""

for i in `ls raw_stacks/ | sed 's/raw_stacks\///g;s/_'$suffix'//g'`;
do
        echo -ne "Aligning stack $k/$total..\r"
        $program -InMrc "raw_stacks/${i}_${suffix}" -OutMrc "aligned_sums_motioncor2/${i}_aligned_sum.mrc" -Patch 5 5 -FmDose "${dose}" -LogFile "logs/motioncor2/${i}_" -PixSize "${pix}" -kV $kv -Group $group >> logs/motioncor2.log 2>&1
        [ $? -ne 0 ] && echo -e "Alignment failed for the stack ${k}!\n" && echo "raw_stacks/${i}_frames.mrc" >> logs/motioncor2_failed.log
        avgshift=`sed 's/-//g' logs/motioncor2/${i}_0-Patch-Full.log | awk -v fr=$fr 'NR>3{sum+=$2;sum+=$3}END{print sum/fr}'`
        echo "raw_stacks/${i}_frames.mrc - avg frame shift: $avgshift px" >> logs/avg_shift_motioncor2.log
        ((k++))
done
sort -n -k2 logs/avg_shift_motioncor2.log > .tmp_sort
mv .tmp_sort logs/avg_shift_motioncor2.log
echo -e "\nDone!\nLog files are in logs/motioncor2/ folder."
