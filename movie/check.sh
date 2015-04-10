#!/bin/bash
# this script check if every mrc file has a pair (frames and total)

if [ "$#" -ne 1 ] || [ "$1" != "mrc" ]; then
echo "usage: `basename $0` mrc" # Right now it is not working with tifs
exit 1
fi

[ -f logs/del.list2 ] && rm -f logs/del.list2
[ -f logs/bad_files.txt ] && rm -f logs/bad_files.txt
[ ! -d logs ] && mkdir logs
[ ! -f logs/del.list ] && find . -name "FoilHole*.${1}" | sed -rn 's/FoilHole_[0-9]*_Data_[0-9]*_([^\.]+)\.'$1'/\1\t\0/p' | sort | cut -f2 > logs/del.list

sed 's/_frames//g;s/.mrc//g' logs/del.list | uniq > logs/del.list2
while read file;
        do
        [ -f ${file}.mrc -a -f ${file}_frames.mrc ] || echo "Check file: ${file}*.mrc" && echo "${file}" >> logs/bad_files.txt
        done < logs/del.list2
echo "Bad files are in: logs/bad_files.txt"
