#!/bin/bash
###Run movie_prep_parallel.sh first and source your EMAN2!
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
movie_soft_path="/usr/local/bin"
xmipp_soft_path="/home/sharov/soft/scipion/software/em/xmipp/bin"

# user input
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
[ $opflow -eq 1 ] && rm -rf aligned_sums_xmipp && mkdir aligned_sums_xmipp
[ -d aligned_sums ] && rm -rf aligned_sums
[ -d aligned_movies ] && rm -rf aligned_movies
mkdir aligned_movies
mkdir aligned_sums
[ -d logs/alignment ] && rm -rf logs/alignment
mkdir -p logs/alignment
[ ! -d raw_stacks ] && echo "No raw stacks found. Exiting.." && exit 1
[ ! -s logs/frame.list ] && echo "No frame list found. Exiting.." && exit 1

# set output aligned stacks if required
if [ $opflow -eq 1 ] && [ $ssc -eq 1 ]; then
        ssc1=1 && ssc2=1
        rm -rf aligned_movies_xmipp && mkdir aligned_movies_xmipp
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
key=1
echo ""
for stack in `cat ${inputFile} | sed 's/.*FoilHole/FoilHole/g;s/_frames.mrc//g'`
do
        if [ -f raw_stacks/${stack}_stack.mrcs ] && [ ! -f aligned_sums/${stack}.mrc ]
        then
                echo ""
                echo -ne "Aligning frames $key/$total: ...\r"
                # run motioncorr within time interval
                timeout 1.5m ${movie_soft_path}/motioncorr_v2.1 raw_stacks/${stack}_stack.mrcs -fod 2 -ssc $ssc1 -fct aligned_movies/${stack}_movie.mrcs -fcs aligned_sums/${stack}.mrc -dsp 0 -atm 1 -flg logs/alignment/${stack}_align.log &>/dev/null
                if [ ! -f aligned_sums/${stack}.mrc ]
                then
                        echo "raw_stacks/${stack}_stack.mrcs" >> logs/not_aligned.plt
                        echo -ne "Aligning frames $key/$total: ... FAIL!\n"
                else
                        shift=`grep "Final shift (Average" logs/alignment/${stack}_align.log | sed -e 's/Final\ shift\ (Average//g;s/)\://g'`
                        echo -ne "Aligning frames $key/$total: ... average shift ${shift}\n"
                        # convert output to 16 bit, since motioncorr produces 32 bit files
                        e2proc2d.py aligned_sums/${stack}.mrc aligned_sums/${stack}_16bit.mrc --outmode=int16 > /dev/null 2>&1
                        mv aligned_sums/${stack}_16bit.mrc aligned_sums/${stack}.mrc
                        
                        if [ $ssc1 -eq 1 ]; then
                                e2proc2d.py aligned_movies/${stack}_movie.mrcs aligned_movies/${stack}_movie_16bit.mrcs --outmode=int16 > /dev/null 2>&1
                                mv aligned_movies/${stack}_movie_16bit.mrcs aligned_movies/${stack}_movie.mrcs
                        fi

                        # run xmipp if required
                        if [ $opflow -eq 1 ] && [ -f aligned_movies/${stack}_movie.mrcs ]; then
                                # check if we want to save aligned stacks
                                echo -ne "Aligning frames $key/$total by optical flow: ...\r"
                                if [ $ssc2 -eq 1 ]; then
                                        ${xmipp_soft_path}/xmipp_movie_optical_alignment_gpu -i aligned_movies/${stack}_movie.mrcs -o aligned_sums_xmipp/${stack}.mrc --ssc --winSize 150 > logs/alignment/${stack}_align_xmipp.log
                                else
                                        ${xmipp_soft_path}/xmipp_movie_optical_alignment_gpu -i aligned_movies/${stack}_movie.mrcs -o aligned_sums_xmipp/${stack}.mrc --winSize 150 > logs/alignment/${stack}_align_xmipp.log
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
grep "Final shift (Average" logs/alignment/* | sed -e 's/logs\/alignment\///g;s/_align.log\:Final\ shift\ (Average/.mrc/g;s/)\://g' > logs/average_shift1.log
cat logs/average_shift1.log | sort -n -k2 > logs/average_shift.log
rm -f logs/average_shift1.log
echo -e "\nResults:  shifts in -> logs/average_shift.log
          detailed logs in -> logs/alignment/*.log
          NOT aligned images in -> logs/not_aligned.plt
          aligned movies after motioncorr -> aligned_movies/*_movie.mrcs
          aligned sums after motioncorr -> aligned_sums/*.mrc"
[ $opflow -eq 1 ] && echo "          aligned sums after xmipp optical flow -> aligned_sums_xmipp/*.mrc"
[ $ssc2 -eq 1 ] && echo "          aligned movies after xmipp optical flow -> aligned_movies_xmipp/*_movie.mrcs"
echo "Do not forget to move CTFFIND4 output files from Micrographs/ to your aligned_sums(_xmipp)/ folder!"
