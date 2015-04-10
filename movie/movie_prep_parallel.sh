#!/bin/bash
###
###Script works only with mrc files/stacks of frames (16-bit int) coming from EPU version 1.4.3.1159REL
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
[ -d logs ] && rm -rf logs
mkdir logs
[ -d raw_stacks ] && rm -rf raw_stacks
mkdir raw_stacks
trap "setterm -cursor on" SIGHUP SIGINT SIGTERM
#find . -name "Grid*.${1}" -exec rm {} \;
find . -name "FoilHole*.${1}" | sed -rn 's/FoilHole_[0-9]*_Data_[0-9]*_([^\.]+)\.'$1'/\1\t\0/p' | sort | cut -f2 > logs/del.list
cat logs/del.list | grep frames > logs/frame.list
frames=`cat logs/frame.list | grep frames | wc -l`
[ $frames -lt 8 ] && echo "Need more than 7 different images to process in parallel correctly" && exit 1
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
name=`echo $ima | sed -e 's/_frames.mrc//'`
base=`echo $name | awk -F "_" '{$NF=""}1' |  sed -e "s/ /_/g" -e "s/_$//"`
HourMin=`echo $name | awk -F "_" '{print $(NF)}'`
if [[ "$HourMin" == 0000 ]]
then
RealNum=2359
else
Min=${HourMin:2:2}
Hours=${HourMin:0:2}
InMid=`echo "scale=0; $Hours*60+$Min-1" | bc`
InMd1=`printf "%0*d\n" 2 $((InMid/60))`
InMd2=`printf "%0*d\n" 2 $((InMid%60))`
RealNum=`echo ${InMd1}${InMd2}`
fi
if [ ! -f ${name}.mrc ]
then
HiDo=${base}_${RealNum}
elif [ -f ${name}.mrc ]
then
HiDo=$name
else
echo $ima >> logs/suspicious_frames.plt
continue
fi
if [ -f raw_stacks/${name}_stack.mrcs ]
then
echo "${name}" >> logs/percent.list
else
FrameNum=`e2iminfo.py ${name}_frames.mrc | head -1 | awk '{print $11}'`
if [ "$FrameNum" -ne $num ]
then
echo ${name}_frames.mrc >> logs/incomplete_stacks.list
else
#Normalize the frames
e2proc2d.py ${name}_frames.mrc raw_stacks/${name}_stack.mrcs --process=threshold.clampminmax.nsigma:nsigma=4 --process=normalize.edgemean --mult=-1 > /dev/null 2>&1
#add high-dose image (rotated 90 degrees)
e2proc2d.py ${HiDo}.mrc raw_stacks/${name}_stack.mrcs --rotate=90 --process=threshold.clampminmax.nsigma:nsigma=4 --process=normalize.edgemean --mult=-1 > /dev/null 2>&1
[ $? -ne 0 ] && echo "raw_stacks/${name}_stack.mrcs" >> logs/eman_problems.list
echo "${name}" >> logs/percent.list
fi
fi
done
}
Avleng=$(($frames/8))
Rem=$(($frames%8))
for i in `seq 1 7`
do
x=$(($Avleng*$i))
t=$(($Avleng-1))
s=$(($x-$t))
sed -n ${s},${x}p logs/frame.list > logs/proc${i}.list
done
r=$(($Avleng*7+1))
sed -n ${r},\$p logs/frame.list > logs/proc8.list
for nu in `seq 1 8`
do
stackcreate logs/proc${nu}.list &
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
