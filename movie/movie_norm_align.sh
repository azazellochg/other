#!/bin/bash
#Source your EMAN2 in the next line!
source /home/sharov/soft/EMAN2.1/eman2.bashrc

#exporting CUDA 5.5  and scipion libs
export LD_LIBRARY_PATH="/home/sharov/soft/scipion/software/lib:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"
export LC_ALL="en_US.UTF-8"

# check if EMAN2 is sourced
if [ -z $EMAN2DIR ]; then
        echo "EMAN2 NOT found!" && exit 1
fi
trap 'kill -HUP -$$' exit; nvidia-smi -l 300 >/dev/null & # by Jonathan

# set path to software
movie_soft_path="/home/sharov/soft/motioncorr_v2.1_modif/bin/"
xmipp_soft_path="/home/sharov/soft/scipion/software/em/xmipp/bin"

# user input
echo -n "How many random frame stacks you want to average for avg/std estimation (for camera normalization, default 100): "
read stkavg
stkavg=${stkavg:-100}
re='^[0-9]+$'
if ! [[ $stkavg =~ $re ]]; then
        echo "error: Wrong answer!" >&2; exit 1
fi
echo -n "Do you want to run xmipp optical flow alignment after motioncorr? (0 - no, 1 - yes, default: 0): "
read opflow
opflow=${opflow:-0}
re='^[0-1]+$'
if ! [[ $opflow =~ $re ]]; then
        echo "error: Wrong answer!" >&2; exit 1
fi
echo -n "Do you want to save aligned movie stacks? (0 - no, 1 - yes, default: 1): "
read ssc
ssc=${ssc:-1}
re='^[0-1]+$'
if ! [[ $ssc =~ $re ]]; then
        echo "error: Wrong answer!" >&2; exit 1
fi
echo -n "Do you want to select input files based on max resolution estimated by CTFFIND? (0 - no, 1 - yes, default: 0): "
read select
select=${select:-0}
re='^[0-1]+$'
if ! [[ $select =~ $re ]]; then
        echo "error: Wrong answer!" >&2; exit 1
fi
if [ $select -eq 1 ]; then
        echo -n "Select ctfrings.txt file: " && ctfrings=`zenity --title="Select ctfrings.txt file" --file-selection --file-filter="ctfrings.txt"`
        [ ! -f ${ctfrings} ] && echo "ERROR! File ctfrings.txt not found!" && exit 1
        echo -n "Specify the worst resolution in Angstrom (default: 15): "
        read reso
        reso=${reso:-15}
        re='^[0-9]*$'
        if ! [[ $reso =~ $re ]]; then
                echo "error: Wrong answer!" >&2; exit 1
        fi
fi

# create necessary folders and check input
if [ $opflow -eq 1 ]; then
        [ -d aligned_sums_xmipp ] && echo "aligned_sums_xmipp folder already exists! Please remove it!" && exit 1
        mkdir aligned_sums_xmipp
fi
[ -d aligned_sums_motioncorr ] && echo "aligned_sums_motioncorr folder already exists! Please remove it!" && exit 1
[ -d aligned_movies_motioncorr ] && echo "aligned_movies_motioncorr folder already exists! Please remove it!" && exit 1
[ -d logs/alignment ] && echo "logs/alignment folder already exists! Please remove it!" && exit 1

#re-run find command since after check.sh script we might have renamed files
find . -name "FoilHole_*_Data_*.mrc" > logs/files.list
grep "frames" logs/files.list > logs/frame.list
mkdir aligned_movies_motioncorr && mkdir aligned_sums_motioncorr
mkdir -p logs/alignment

# set output aligned stacks if required
if [ $opflow -eq 1 ] && [ $ssc -eq 1 ]; then
        ssc1=1 && ssc2=1
        [ -d aligned_movies_xmipp ] && echo "aligned_movies_xmipp folder already exists! Please remove it!" && exit 1
        mkdir aligned_movies_xmipp
elif [ $opflow -eq 1 ] && [ $ssc -eq 0 ]; then
        ssc1=1 && ssc2=0
elif [ $opflow -eq 0 ] ; then
        ssc1=$ssc && ssc2=0
fi
if [ $select -eq 0 ]; then
        total=`wc -l < logs/frame.list`
        inputFile="logs/frame.list"
else
        if [ `wc -l < logs/frame.list` -eq `wc -l < ${ctfrings}` ]; then
                awk -v reso=$reso '$3<reso{print $1}' ${ctfrings} | sed 's/Micrographs\///g;s/.mrc//g' > logs/frame_to_process.list
                total=`wc -l logs/frame_to_process.list`
                inputFile="logs/frame_to_process.list"
        else
                echo "ERROR! This should not happen! Number of files in ${ctfrings} and logs/frame.list is different!" && exit 1
        fi
fi

#create a stack from $stkavg frames, calculate avg+sigma
sort -R $inputFile | head -n $stkavg > logs/random_frames.list
rm -f random_stack*
echo -ne "Averaging frames and calculating std: ...\r"
for i in `cat logs/random_frames.list`; do e2proc2d.py "${i}" random_stack.hdf &>/dev/null ; done
/usr/bin/env python - <<END
# simple script to calculate avg and std for an image stack (c) Steve Ludtke

from EMAN2 import *

stack = "random_stack.hdf"
count = EMUtil.get_image_count(stack)

# initialize averager
std_img=EMData(stack,0) # need to initialize with empty image same size as inputs
std_img.to_zero()
avg=Averagers.get("mean",{"sigma":std_img})

# note we only need to keep one image in memory at a time
for i in xrange(count):
    image = EMData(stack,i)
    avg.add_image(image)

avg_img=avg.finish() # also produces std_img
avg_img.write_image("random_stack_avg.mrc")
std_img.write_image("random_stack_std.mrc")
END
echo "OK!"
key=1
echo ""
for file in `cat ${inputFile}`
do
        stack=`echo ${file} | sed 's/.*FoilHole/FoilHole/g;s/_frames.mrc//g'`
        if [ -f ${file} ] && [ ! -f aligned_sums_motioncorr/${stack}.mrc ]
        then
                echo ""
                echo -ne "Aligning frames $key/$total: ...\r"
                # run motioncorr within time interval
                timeout 1.5m ${movie_soft_path}/dosefgpu_driftcorr ${file} -hgr 0 -fdr random_stack_avg.mrc -fgr random_stack_std.mrc -fod 2 -ssc $ssc1 -fct aligned_movies_motioncorr/${stack}_movie.mrcs -fcs aligned_sums_motioncorr/${stack}.mrc -dsp 0 -atm 1 -flg logs/alignment/${stack}_align_motioncorr.log &>/dev/null
                if [ ! -f aligned_sums_motioncorr/${stack}.mrc ]
                then
                        echo "${file}" >> logs/not_aligned_motioncorr.plt
                        echo -ne "Aligning frames $key/$total: ... FAIL!\n"
                else
                        shift=`grep "Final shift (Average" logs/alignment/${stack}_align_motioncorr.log | sed -e 's/Final\ shift\ (Average//g;s/)\://g'`
                        echo -ne "Aligning frames $key/$total: ... average shift ${shift}\n"
                        # convert output to 16 bit, since motioncorr produces 32 bit files
                        e2proc2d.py aligned_sums_motioncorr/${stack}.mrc aligned_sums_motioncorr/${stack}_16bit.mrc --outmode=int16 > /dev/null 2>&1
                        mv aligned_sums_motioncorr/${stack}_16bit.mrc aligned_sums_motioncorr/${stack}.mrc
                        
                        if [ $ssc1 -eq 1 ]; then
                                e2proc2d.py aligned_movies_motioncorr/${stack}_movie.mrcs aligned_movies_motioncorr/${stack}_movie_16bit.mrcs --outmode=int16 > /dev/null 2>&1
                                mv aligned_movies_motioncorr/${stack}_movie_16bit.mrcs aligned_movies_motioncorr/${stack}_movie.mrcs
                        fi

                        # run xmipp if required
                        if [ $opflow -eq 1 ] && [ -f aligned_movies_motioncorr/${stack}_movie.mrcs ]; then
                                # check if we want to save aligned stacks
                                echo -ne "Aligning frames $key/$total by optical flow: ...\r"
                                if [ $ssc2 -eq 1 ]; then
                                        ${xmipp_soft_path}/xmipp_movie_optical_alignment_gpu -i aligned_movies_motioncorr/${stack}_movie.mrcs -o aligned_sums_xmipp/${stack}.mrc --ssc --winSize 150 > logs/alignment/${stack}_align_xmipp.log
                                else
                                        ${xmipp_soft_path}/xmipp_movie_optical_alignment_gpu -i aligned_movies_motioncorr/${stack}_movie.mrcs -o aligned_sums_xmipp/${stack}.mrc --winSize 150 > logs/alignment/${stack}_align_xmipp.log
                                fi
                                echo -ne "Aligning frames $key/$total by optical flow: ... OK!\n"
                                # convert output to 16 bit, since xmipp produces 32 bit files
                                e2proc2d.py aligned_sums_xmipp/${stack}.mrc aligned_sums_xmipp/${stack}_16bit.mrc --outmode=int16 > /dev/null 2>&1
                                mv aligned_sums_xmipp/${stack}_16bit.mrc aligned_sums_xmipp/${stack}.mrc
                                mv aligned_sums_xmipp/${stack}.xmd logs/alignment/
                                rm -f aligned_sums_xmipp/${stack}*.txt
                                if [ $ssc2 -eq 1 ]; then
                                        e2proc2d.py aligned_sums_xmipp/${stack}.mrcs aligned_movies_xmipp/${stack}_movie.mrcs --outmode=int16 > /dev/null 2>&1
                                        rm -f aligned_sums_xmipp/${stack}.mrcs
                                fi
                        fi
                fi  
        fi  
        ((key++))
done

# grep shifts from log files
grep "Final shift (Average" logs/alignment/* | sed -e 's/logs\/alignment\///g;s/_align_motioncorr.log\:Final\ shift\ (Average/.mrc/g;s/)\://g' > logs/average_shift1.log
cat logs/average_shift1.log | sort -n -k2 > logs/average_shift.log
rm -f logs/average_shift1.log
echo -e "\nResults:  shifts in -> logs/average_shift.log
          detailed logs in -> logs/alignment/*.log
          NOT aligned images in -> logs/not_aligned_motioncorr.plt
          aligned movies after motioncorr -> aligned_movies_motioncorr/*_movie.mrcs
          aligned sums after motioncorr -> aligned_sums_motioncorr/*.mrc"
[ $opflow -eq 1 ] && echo "          aligned sums after xmipp optical flow -> aligned_sums_xmipp/*.mrc"
[ $ssc2 -eq 1 ] && echo "          aligned movies after xmipp optical flow -> aligned_movies_xmipp/*_movie.mrcs"
