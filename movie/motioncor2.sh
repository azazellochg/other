#!/bin/bash

# 15/09/2016 works best with .mrc frame stacks from FEI EPU (MRC mode 6, uint16)
# does not work with mrcs stacks (MRC mode 1, int16)
#exporting CUDA 7.5 libs
if ! (echo "${LD_LIBRARY_PATH}" | grep "cuda-7.5" > /dev/null 2>&1)
        then export LD_LIBRARY_PATH="/usr/local/cuda-7.5/lib64/:${LD_LIBRARY_PATH}"
fi
# check if EMAN2 is sourced
if [ -z $EMAN2DIR ]; then
        echo "EMAN2 NOT found!" && exit 1
fi

#---input-parameters---
# input movies should be in 'raw_stacks' folder
program='/usr/local/bin/MotionCor2-10-19-2016'
pix="1.1"
dose="7.05" # dose per frame
patch="5 5" # this var does not work!!! change cmd line yourself
kv="300"
group="1"   # group frames
frames="7"  # total N of frames
#----------------------

echo -n "Do you want to save aligned movie stacks? (0 - no, 1 - yes, default: 0): "
read stacks
stacks=${stacks:-0}
re='^[0-1]+$'
if ! [[ $stacks =~ $re ]]; then
        echo "error: Wrong answer!" >&2; exit 1
fi
if [ $stacks -eq 1 ]; then
        [ -d aligned_movies_motioncor2 ] && echo "aligned_movies_motioncor2 folder already exists! Please remove it!" && exit 1
        mkdir aligned_movies_motioncor2
fi
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
        $program -InMrc "raw_stacks/${i}_${suffix}" -OutMrc "aligned_sums_motioncor2/${i}_aligned_sum.mrc" -Patch 5 5 -FmDose "${dose}" -LogFile "logs/motioncor2/${i}_" -PixSize "${pix}" -kV $kv -Group $group -OutStack $stacks >> logs/motioncor2.log 2>&1
        if [ $? -ne 0 ]; then
                echo -e "Alignment failed for the stack ${k}!\n" && echo "raw_stacks/${i}_frames.mrc" >> logs/motioncor2_failed.log
        else
                # convert output to 16 bit, since motioncor2 produces 32 bit files
                e2proc2d.py "aligned_sums_motioncor2/${i}_aligned_sum.mrc" "aligned_sums_motioncor2/${i}_aligned_sum_16bit.mrc" --outmode=uint16 > /dev/null 2>&1
                mv "aligned_sums_motioncor2/${i}_aligned_sum_16bit.mrc" "aligned_sums_motioncor2/${i}_aligned_sum.mrc"
                avgshift=`sed 's/-//g' logs/motioncor2/${i}_0-Patch-Full.log | awk -v fr=$fr 'NR>3{sum+=$2;sum+=$3}END{print sum/fr}'`
                echo "raw_stacks/${i}_${suffix} $avgshift px" >> logs/motioncor2_avg_shift.log
                [ $stacks -eq 1 ] && e2proc2d.py "aligned_sums_motioncor2/${i}_aligned_sum_Stk.mrc" "aligned_movies_motioncor2/${i}_aligned_movie.mrcs" --outmode=uint16 > /dev/null 2>&1
        fi
        ((k++))
done        
sort -n -k2 logs/motioncor2_avg_shift.log > .tmp_sort
mv .tmp_sort logs/motioncor2_avg_shift.log
echo -e "\nDone!\nLog files are in logs/motioncor2/ folder."
