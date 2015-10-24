#!/bin/bash
#This script runs ctffind4 in parallel on unaligned movie stacks (frames + total exp)
########### user input #################
ctffind_bin="/home/sharov/soft/ctffind-4.0.16/ctffind"
frames_avg="1"          # Number of frames to average together
pix="1.41"              # Pixel size, A
dstep="14"              # Camera pixel size, um
acc="300"               # Acceleration voltage, kV
sph="0.001"             # Spherical aberration
amp="0.1"               # Amplitude contrast
size="512"              # Size of power spectrum to compute, px
min_res="30"            # Minimum resolution, A
max_res="2.82"          # Maximum resolution, A
min_def="5000.0"        # Minimum defocus, um
max_def="50000.0"       # Maximum defocus
step_def="500.0"        # Defocus search step
ast="100.0"             # Expected (tolerated) astigmatism
########### end of user input ##########
export LC_ALL="en_US.UTF-8"
mag=`echo "scale=2; $dstep*10000/$pix" | bc`
if [ "$#" -ne 1 ]
        then
                echo "usage: `basename $0` NumberOfParallelProcesses" && exit 1
fi
ProcNum=$1
rm -rf tmp logs/percent.list logs/proc* logs/pid.list >> /dev/null 2>&1
[ -d raw_stacks ] || ( echo "Error: raw_stacks folder not found!" && exit 1 )
[ -d logs ] || ( echo "Error: logs folder not found!" && exit 1 )
[ -d Micrographs ] && echo "Error: Micrographs folder already exist!" && exit 1
[ -d tmp ] || mkdir tmp
mkdir Micrographs
trap "setterm -cursor on" SIGHUP SIGINT SIGTERM
ls raw_stacks/*.mrc > logs/raw_stacks.list
MicNum=`wc -l < logs/raw_stacks.list`
ctfestimate () {
for ima in `cat $1`
        do
                name=`echo $ima | sed -e 's/_stack.mrcs//'`
                ln -s "${PWD}/raw_stacks/${name}"_stack.mrcs ${PWD}/tmp/"${name}".mrc
                ${ctffind_bin} > Micrographs/${name}_sum_corr_ctffind3.log << EOF
${PWD}/tmp/${name}.mrc
yes
${frames_avg}
Micrographs/${name}_sum_corr.ctf
${pix}
${acc}
${sph}
${amp}
${size}
${min_res}
${max_res}
${min_def}
${max_def}
${step_def}
${ast}
no
EOF
                echo "      DFMID1      DFMID2      ANGAST          CC" >> Micrographs/${name}_sum_corr_ctffind3.log
                awk 'END{printf "%12.2f%12.2f%12.2f%12.2f%14s\n\n",$2,$3,$4,$6,"Final Values"}' Micrographs/${name}_sum_corr.txt >> Micrographs/${name}_sum_corr_ctffind3.log
                echo " CS[mm], HT[kV], AmpCnst, XMAG, DStep[um]" >> Micrographs/${name}_sum_corr_ctffind3.log
                printf "%5.1f%9.1f%8.2f%10.1f%9.3f\n" "$sph" "$acc" "$amp" "$mag" "$dstep" >> Micrographs/${name}_sum_corr_ctffind3.log
                echo "${name}" >> logs/percent.list
        done
}
split -n l/${ProcNum} -a 1 -de logs/raw_stacks.list logs/proc
ProcNum2=$((ProcNum-1))
for nu in `seq 0 ${ProcNum2}`
        do
                ctfestimate logs/proc${nu} &
                echo $! >> logs/pid.list
        done
ProI=0
setterm -cursor off
echo -en "Estimating CTF from movie stacks in folder raw_stacks/. Completed:"
while [ "$ProI" -eq 0 ]
        do
                kill -0 `cat logs/pid.list` 2>/dev/null
                ProI=$?
                c=`cat logs/percent.list 2>/dev/null | wc -l`
                sw=`echo "scale=2;$c/${MicNum}*100" | bc`
                sww=`printf "%0*d\n" 2 $sw 2> /dev/null`
                echo -en "${sww}%\b\b\b"
                sleep 1
        done
setterm -cursor on
rm -rf tmp logs/percent.list logs/proc* logs/pid.list
echo -e "Done! Output files for each stack are in Micrographs/ folder\n"
