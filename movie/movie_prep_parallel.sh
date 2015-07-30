#!/bin/bash
###
###Script was tested only with mrc files/frame stacks (16-bit int) coming out of EPU version 1.4.3.1159REL
###It will create stacks of (frames + total exposure) for further processing by motioncorr
###
#source /home/sharov/soft/EMAN2.1/eman2.bashrc
if [ "$#" -ne 1 ] || [ "$1" != "mrc" ]; then
	echo "usage: `basename $0` mrc" # Right now it is not working with tifs
	exit 1
fi

echo -n "Specify number of frames in *_frames.mrc files: [7]  "
read num
num=${num:-7}
re='^[0-9]+$'
if ! [[ $num =~ $re ]]; then
	echo "error: Not a number" >&2; exit 1
fi

[ ! -d logs ] && mkdir logs
[ -d raw_stacks ] && rm -rf raw_stacks
mkdir raw_stacks
trap "setterm -cursor on" SIGHUP SIGINT SIGTERM
#find . -name "FoilHole*.${1}" > logs/del.list
#grep "frames" logs/del.list > logs/frame.list
frames=`grep -c frames logs/frame.list`
[ $frames -lt 8 ] && echo "Need more than 7 images to process in parallel correctly" && exit 1
AllIma=`wc -l < logs/del.list`
RawNumF=`echo "scale=2;$AllIma/$frames" | bc`
if [ "$RawNumF" != "2.00" ]
	then
	echo "ERROR: number of frames stacks and ${1} files don't match! please check files"
	exit 1
fi

stackcreate () {
for ima in `cat $1`
do
	name=`echo "$ima" | sed -e 's/_frames.mrc//'`
	names=`echo "$name" | sed 's/.*FoilHole/FoilHole/'`
	if [ -f raw_stacks/${names}_stack.mrcs ];then
		echo "${names}" >> logs/percent.list
	else
		FrameNum=`e2iminfo.py ${name}_frames.mrc | head -1 | awk '{print $NF}'`
		if [ "$FrameNum" -ne $num ];then
			echo ${name}_frames.mrc >> logs/incomplete_stacks.list
		else
			#Normalize the frames
			e2proc2d.py ${name}_frames.mrc raw_stacks/${names}_stack.mrcs --process=threshold.clampminmax.nsigma:nsigma=4 --process=normalize.edgemean --mult=-1 --outmode=int16 > /dev/null 2>&1
			#add high-dose image (rotated 90 degrees)
			e2proc2d.py ${name}.mrc raw_stacks/${names}_stack.mrcs --rotate=90 --process=threshold.clampminmax.nsigma:nsigma=4 --process=normalize.edgemean --mult=-1 --outmode=int16 > /dev/null 2>&1
			[ $? -ne 0 ] && echo "raw_stacks/${names}_stack.mrcs" >> logs/eman_problems.list
			echo "${names}" >> logs/percent.list
		fi
	fi
done
}

split -n l/8 -a 1 -de logs/frame.list logs/proc
for nu in `seq 0 7`
do
	stackcreate logs/proc${nu} &
	echo $! >> logs/pid.list
done
ProI=0
setterm -cursor off
echo -en "Creating stacks in folder raw_stacks/. Completed:"
while [ "$ProI" -eq 0 ]
do
	kill -0 `cat logs/pid.list` 2>/dev/null
	ProI=$?
	c=`cat logs/percent.list 2>/dev/null | wc -l`
	sw=`echo "scale=2;$c/${frames}*100" | bc`
	sww=`printf "%0*d\n" 2 $sw 2> /dev/null`
	echo -en "${sww}%\b\b\b"
	sleep 1
done
echo -e "\n"
setterm -cursor on
