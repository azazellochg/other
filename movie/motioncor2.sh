#!/bin/bash

#exporting CUDA 7.5 libs
if ! (echo "${LD_LIBRARY_PATH}" | grep "cuda-7.5" > /dev/null 2>&1)
        then export LD_LIBRARY_PATH="/usr/local/cuda-7.5/lib64/:${LD_LIBRARY_PATH}"
fi

#---input-parameters---
# input movies should be in 'raw_stacks' folder
program='/usr/local/bin/MotionCor2-03-16-2016'
pix="1.1"
dose="7.05" # dose per frame
patch="5 5" # this var does not work!!! change cmd line yourself
kv="300"
group="1"   # group frames
frames="7"  # total N of frames
#----------------------

[ -d aligned_sums_motioncor2 ] && echo "Please remove aligned_sums_motioncor2 folder and restart the script!" && exit 1
mkdir -p logs/motioncor2 aligned_sums_motioncor2
[ -f logs/motioncor2_avg_shift.log ] && rm -f logs/motioncor2_avg_shift.log
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
        echo "raw_stacks/${i}_${suffix} $avgshift px" >> logs/motioncor2_avg_shift.log
        ((k++))
done        
sort -n -k2 logs/motioncor2_avg_shift.log > .tmp_sort
mv .tmp_sort logs/motioncor2_avg_shift.log
echo -e "\nDone!\nLog files are in logs/motioncor2/ folder."
