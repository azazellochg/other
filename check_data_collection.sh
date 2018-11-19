#!/bin/bash

# This script will send an email if no new files appear in a folder

# INPUT PARAMETERS ######
cista="/net/cista1/Krios3Gatan/Gregory"         # folder to watch
period=15                                       # check every N minutes; Nitrogen filling is ~10min, dark reference is ~3.5min
email="gsharov@mrc-lmb.cam.ac.uk"               # email

#########################

#inotifywait -m -q -e create -e moved_to --format '%:e %w%f' $cista1 |
#    while read file; do
#        echo "The file '$file' appeared in directory '$cista1'"
#        # do something with the file
#    done


while true
do

        function check_files {
        last=`ls --time-style='+%s' -ltr "${cista}" | tail -n1 | awk '{print $6,$7,$8}'`
        lastSec=`echo $last | cut -d' ' -f1`
        lastDate=`date --date="@${lastSec}"`
        lastFn=`echo $last | cut -d' ' -f2`
        currentSec=`date '+%s'`
        diff=$((currentSec-lastSec))
        }

        check_files
        echo "$lastFn was last modified $diff seconds ago!"

        if [[ $diff -gt $((period*60)) ]]
        then
                echo "No changes in last $period minutes! Sending an email...and trying again in 30 min."
                echo -e "\nHi bro,\n\nno new files were detected in $cista during last $period minutes! Something is wrong?..\n\nLast modified file was $lastFn at $lastDate\n" | \
                mail -s "ALERT: No new files detected! Check your data collection!" ${email}

                # next check is in 30 minutes
                sleep 30m
                check_files
                if [[ $diff -gt $((30*60)) ]]
                then
                        echo "No changes in last 30 minutes! Sending an email and giving up.."
                        echo -e "\nNo new files were detected in $cista during last 30 minutes! I give up..\n" | \
                        mail -s "ALERT: No new files detected in last 30 min!" ${email}
                        break
                fi
        else
                sleep ${period}m
        fi
done
