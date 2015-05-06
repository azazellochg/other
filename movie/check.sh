#!/bin/bash
#since sometimes total exposure is written to the disk before the frame stack,so for each frame stack the script will look for total exposure file
#registered 1 minute before (timestamp in filename), i.e. for *2358_frames.mrc it will check for *2357.mrc

if [ "$#" -ne 1 ] || [ "$1" != "mrc" ]; then
	echo "usage: `basename $0` mrc" # Right now it is not working with tifs
	exit 1
fi

echo -n "Do you want to rename movie stacks to match total exposure? (0 - no, 1 - yes, default: 0): "
read rep
rep=${rep:-0}
re='^[0-1]+$'
if ! [[ $rep =~ $re ]]; then
	echo "error: Wrong answer!" >&2; exit 1
fi

[ ! -d logs ] && mkdir logs
[ -f logs/suspicious_frames.txt ] && rm -f logs/suspicious_frames.txt
find . -name "FoilHole*.${1}" > logs/del.list
count=0
for img in `grep frames logs/del.list | sed 's/_frames.mrc//g'` #grep frames only
	do
	timestamp=`echo "${img}"| awk -F "_" '{print $(NF-1),$NF}'`
	timestamp_prev=`date "--date=${timestamp} 1 minutes ago" +%Y%m%d_%H%M`
		if [ -f "${img}".mrc ];then 					# if corresponding total exposure exists, OK
			HiDo="${img}.mrc"
		else    							# if not, then check time shift
			HiDo=`echo ${img} | sed -r 's/.{13}$/'${timestamp_prev}'/'`
			if [ -f "${HiDo}".mrc ];then
				echo "time stamp shift detected = ${HiDo}.mrc"
				echo -e "corresponding frame stack = ${img}_frames.mrc\n"
				[ $rep -eq 1 ] && mv ${HiDo}.mrc ${img}.mrc && ((count++))
			else							# otherwise the corresponding total exposure was not found
				echo $ima >> logs/suspicious_frames.txt
				continue
			fi
		fi
	done
echo "$count stacks renamed!"
