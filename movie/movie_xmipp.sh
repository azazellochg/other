#!/bin/bash
### This script runs optical flow alignment, assuming motioncorr was done
### and input aligned movies are in aligned_movies_motioncorr folder

#source /home/sharov/soft/EMAN2.1/eman2.bashrc
#exporting CUDA 5.5  and scipion libs
export LD_LIBRARY_PATH="/home/sharov/soft/scipion/software/lib:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"
export LC_ALL="en_US.UTF-8"

# check if EMAN2 is sourced
if [ -z $EMAN2DIR ]; then
        echo "EMAN2 NOT found!" && exit 1
fi
trap 'kill -HUP -$$' exit; nvidia-smi -l 300 >/dev/null & # by Jonathan
# set path to software
xmipp_soft_path="/home/sharov/soft/scipion/software/em/xmipp/bin"

# user input
echo -n "Do you want to save aligned movie stacks? (0 - no, 1 - yes, default: 1): "
read ssc
ssc=${ssc:-1}
re='^[0-1]+$'
if ! [[ $ssc =~ $re ]]; then
        echo "error: Wrong answer!" >&2; exit 1
fi

# create necessary folders and check input
([ -d aligned_sums_xmipp ] || [ -d aligned_movies_xmipp ]) && echo "ERROR! Output folders aligned_sums_xmipp and aligned_movies_xmipp already exist! Please remove them!" && exit 1
mkdir aligned_sums_xmipp
[ $ssc -eq 1 ] && mkdir aligned_movies_xmipp
[ ! -d aligned_movies_motioncorr ] && echo "ERROR! Input folder 'aligned_movies_motioncorr', containing stacks aligned by motioncorr, was not found" && exit 1
[ ! -d logs/alignment ] && mkdir -p logs/alignment
ls aligned_movies_motioncorr > logs/xmipp_input_movies.list
total=`wc -l < logs/xmipp_input_movies.list`

#run optical flow
key=1
echo ""
for stack in `cat logs/xmipp_input_movies.list | sed 's/.*FoilHole/FoilHole/g;s/_movie.mrcs//g'`
do
        if [ -f aligned_movies_motioncorr/${stack}_movie.mrcs ] && [ ! -f aligned_sums_xmipp/${stack}.mrc ]
        then
                echo ""
                echo -ne "Aligning frames $key/$total: ...\r"
                # check if we want to save aligned stacks
                echo -ne "Aligning frames $key/$total by optical flow: ...\r"
                if [ $ssc -eq 1 ]; then
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
                if [ $ssc -eq 1 ]; then
                        e2proc2d.py aligned_sums_xmipp/${stack}.mrcs aligned_movies_xmipp/${stack}_movie.mrcs --outmode=int16 > /dev/null 2>&1
                        rm -f aligned_sums_xmipp/${stack}.mrcs
                fi
        fi
        ((key++))
done
echo -e "\nResults:
          detailed logs in -> logs/alignment/*.txt
          aligned sums after xmipp optical flow -> aligned_sums_xmipp/*.mrc"
[ $ssc -eq 1 ] && echo "          aligned movies after xmipp optical flow -> aligned_movies_xmipp/*_movie.mrcs"
