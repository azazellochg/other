#!/bin/bash
#since sometimes total exposure is registered faster than frame stack, for each file without pair the script will look for total exposure file
#registered 1 minute before (timestamp in filename), i.e. for *2358_frames.mrc it will check for *2357.mrc
# then this script check if every mrc file has a pair (frames and total)

if [ "$#" -ne 1 ] || [ "$1" != "mrc" ]; then
echo "usage: `basename $0` mrc" # Right now it is not working with tifs
exit 1
fi

[ -f logs/del.list2 ] && rm -f logs/del.list2
[ -f logs/orphan_files.txt ] && rm -f logs/orphan_files.txt
[ ! -d logs ] && mkdir logs
[ ! -f logs/del.list ] && find . -name "FoilHole*.${1}" | sed -rn 's/FoilHole_[0-9]*_Data_[0-9]*_([^\.]+)\.'$1'/\1\t\0/p' | sort | cut -f2 > logs/del.list

for ima in `grep frames logs/del.list | sed 's/_frames.mrc//g'`
do
base=`echo $ima | awk -F "_" '{$NF=""}1' |  sed -e "s/ /_/g" -e "s/_$//"`
HourMin=`echo $ima| awk -F "_" '{print $(NF)}'`
if [[ "$HourMin" == 0000 ]]
then
RealNum=2359
date_old=`echo "${base:(-8)}"`
date_new=`date "--date=${date_old} -1 day" +%Y%m%d`
base=`echo ${base} | sed -r 's/.{8}$/'$date_new'/'`
else
Min=${HourMin:2:2}
Hours=${HourMin:0:2}
InMid=`echo "scale=0; $Hours*60+$Min-1" | bc`
InMd1=`printf "%0*d\n" 2 $((InMid/60))`
InMd2=`printf "%0*d\n" 2 $((InMid%60))`
RealNum=`echo ${InMd1}${InMd2}`
fi
if [ ! -f ${ima}.mrc ]
then
HiDo=${base}_${RealNum}
[ -f ${HiDo}.mrc ] && echo "time stamp shift detected, real total exposure file = ${HiDo}.mrc" && echo -e "                           corresponding frame stack = ${ima}_frames.mrc\n" && mv ${HiDo}.mrc ${ima}.mrc
elif [ -f ${ima}.mrc ]
then
HiDo=$ima
else
echo $ima >> logs/suspicious_frames.plt
continue
fi
done

sed 's/_frames//g;s/.mrc//g' logs/del.list | uniq > logs/del.list2
while read filename;
        do
        [ -f ${filename}.mrc -a -f ${filename}_frames.mrc ] || ( echo "Check file: ${filename}*.mrc" && echo "${filename}" >> logs/orphan_files.txt )
        done < logs/del.list2
[ -f logs/orphan_files.txt ] && echo "Bad files are in: logs/orphan_files.txt"
