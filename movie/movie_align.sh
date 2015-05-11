#!/bin/bash
###Run movie_prep_parallel.sh first!
#source /home/sharov/soft/EMAN2.1/eman2.bashrc
trap 'kill -HUP -$$' exit; nvidia-smi -l 300 >/dev/null & # by Jonathan
movie_soft_path="/usr/local/bin"
[ -d aligned_sums ] && rm -rf aligned_sums
[ -d aligned_movies ] && rm -rf aligned_movies
mkdir aligned_movies
mkdir aligned_sums
[ -d logs/alignment ] && rm -rf logs/alignment
mkdir -p logs/alignment
[ ! -d raw_stacks ] && echo "No stacks found. Exiting.." && exit 1
bold=`tput bold`
normal=`tput sgr0`
testname=`ls raw_stacks/* | head -1`
FrameNum=`e2iminfo.py ${testname} | head -1 | awk '{print $2}'`
[ ! -s logs/frame.list ] && echo "No frame list found. Exiting.." && exit 1
echo -n "Do you want to save aligned movie stacks? (0 - no, 1 - yes, default: 1): "
read ssc
ssc=${ssc:-1}
re='^[0-1]+$'
if ! [[ $ssc =~ $re ]]; then
echo "error: Wrong answer!" >&2; exit 1
fi
total=`wc -l < logs/frame.list`
key=1
echo ""
for stack in `cat logs/frame.list | sed 's/.*FoilHole/FoilHole/g;s/_frames.mrc//g'`
do
if [ -f raw_stacks/${stack}_stack.mrcs ] && [ ! -f aligned_sums/${stack}.mrc ]
then
echo -ne "Aligning frames $key/$total: ...\r"
timeout 1.5m ${movie_soft_path}/motioncorr_v2.1 raw_stacks/${stack}_stack.mrcs -fod 2 -ssc $ssc -fct aligned_movies/${stack}_movie.mrcs -fcs aligned_sums/${stack}.mrc -dsp 0 -atm -${FrameNum} -flg logs/alignment/${stack}_align.log &>/dev/null
if [ ! -f aligned_sums/${stack}.mrc ]
then
echo "raw_stacks/${stack}_stack.mrcs" >> logs/not_aligned.plt
echo -ne "Aligning frames $key/$total: ... FAIL!\n"
else
shift=`grep "Final shift (Average" logs/alignment/${stack}_align.log | sed -e 's/Final\ shift\ (Average//g;s/)\://g'`
echo -ne "Aligning frames $key/$total: ... average shift ${shift}\n"
fi
fi
((key++))
done
grep "Final shift (Average" logs/alignment/* | sed -e 's/Final\ shift\ (Average//g;s/)\://g' > logs/average_shift1.log
cat logs/average_shift1.log | sort -n -k2 > logs/average_shift.log
rm -f logs/average_shift1.log
echo -e "\nResults: shifts in -> logs/average_shift.log
          detailed logs in -> logs/alignment/*.log
          NOT aligned images in -> logs/not_aligned.plt
	  aligned movies for Relion -> aligned_movies/*_movie.mrcs
	  aligned sums for Relion -> aligned_sums/*.mrc"
