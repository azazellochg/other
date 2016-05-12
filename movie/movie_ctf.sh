#!/bin/bash
#This script runs ctffind4 in parallel on either movie stacks or aligned sums
########### user input #################
ctffind_bin="/home/sharov/soft/ctffind-4.0.17/ctffind"
threads="1"             # Number of threads per process
frames_avg="1"          # Number of frames to average together (only relevant for CTF estimation from movie stacks)
pix="1.1"               # Pixel size, A
dstep="14"              # Camera pixel size, um
acc="300"               # Acceleration voltage, kV
sph="0.01"              # Spherical aberration, mm
amp="0.1"               # Amplitude contrast
size="512"              # Size of power spectrum to compute, px
min_res="30"            # Minimum resolution, A
max_res="2.2"           # Maximum resolution, A
min_def="5000.0"        # Minimum defocus, nm
max_def="50000.0"       # Maximum defocus, nm
step_def="500.0"        # Defocus search step, nm
ast="100.0"             # Expected (tolerated) astigmatism, A
########### end of user input ##########
export LC_ALL="en_US.UTF-8"
mag=`echo "scale=2; $dstep*10000/$pix" | bc`
if [ "$#" -ne 1 ]
        then
                echo "usage: `basename $0` NumberOfParallelProcesses" && exit 1
fi
ProcNum=$1
rm -rf .tmp logs/percent.list logs/proc* logs/pid.list >> /dev/null 2>&1

# check input
echo "Please select input folder containing total sums (*.mrc) or movies: (*.mrcs) "
inputFolder=`zenity --title="Select input folder with images" --file-selection --directory`
[ ! -d ${inputFolder} ] && echo "ERROR! Input folder ${inputFolder} not found!" && exit 1
if [ `ls "${inputFolder}" | head -1 | egrep '(.mrc)\b'` ]; then
        inputType=0
elif [ `ls "${inputFolder}" | head -1 | egrep '(.mrcs)\b'` ]; then
        inputType=1
else
        echo "Input file format is not recognized!" && exit 1
fi
[ -d logs ] || ( echo "Warning: logs folder not found!" && mkdir logs )
[ -d Micrographs ] && echo "Error: Micrographs folder already exist! Please remove it." && exit 1
[ -d .tmp ] || mkdir .tmp
mkdir Micrographs
trap "setterm -cursor on" SIGHUP SIGINT SIGTERM
rm -f logs/input_files_for_ctf.list
[ ${inputType} -eq 0 ] && ls ${inputFolder}/*.mrc > logs/input_files_for_ctf.list
[ ${inputType} -eq 1 ] && ls ${inputFolder}/*.mrcs > logs/input_files_for_ctf.list
MicNum=`wc -l < logs/input_files_for_ctf.list`

# main functions
ctfestimateMovies () {
for ima in `cat $1`
        do
                name=`basename $ima | egrep -o 'FoilHole_[0-9]*_Data_[0-9]*_[0-9]*_[0-9]{8,8}_[0-9]{4,4}'`
                ln -s "${ima}" ${PWD}/.tmp/"${name}".mrc
                ${ctffind_bin} --omp-num-threads $threads > Micrographs/${name}_ctffind3.log << EOF
.tmp/${name}.mrc
yes
${frames_avg}
Micrographs/${name}.ctf
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
                echo "      DFMID1      DFMID2      ANGAST          CC" >> Micrographs/${name}_ctffind3.log
                awk 'END{printf "%12.2f%12.2f%12.2f%12.2f%14s\n\n",$2,$3,$4,$6,"Final Values"}' Micrographs/${name}.txt >> Micrographs/${name}_ctffind3.log
                echo " CS[mm], HT[kV], AmpCnst, XMAG, DStep[um]" >> Micrographs/${name}_ctffind3.log
                printf "%5.1f%9.1f%8.2f%10.1f%9.3f\n" "$sph" "$acc" "$amp" "$mag" "$dstep" >> Micrographs/${name}_ctffind3.log
                echo "${name}" >> logs/percent.list
        done
}
ctfestimateSums () {
for ima in `cat $1`
        do
                name=`basename $ima | egrep -o 'FoilHole_[0-9]*_Data_[0-9]*_[0-9]*_[0-9]{8,8}_[0-9]{4,4}'`
                ln -s "${ima}" ${PWD}/.tmp/"${name}".mrc
                ${ctffind_bin} --omp-num-threads $threads > Micrographs/${name}_ctffind3.log << EOF
.tmp/${name}.mrc
Micrographs/${name}.ctf
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
                echo "      DFMID1      DFMID2      ANGAST          CC" >> Micrographs/${name}_ctffind3.log
                awk 'END{printf "%12.2f%12.2f%12.2f%12.2f%14s\n\n",$2,$3,$4,$6,"Final Values"}' Micrographs/${name}.txt >> Micrographs/${name}_ctffind3.log
                echo " CS[mm], HT[kV], AmpCnst, XMAG, DStep[um]" >> Micrographs/${name}_ctffind3.log
                printf "%5.1f%9.1f%8.2f%10.1f%9.3f\n" "$sph" "$acc" "$amp" "$mag" "$dstep" >> Micrographs/${name}_ctffind3.log
                echo "${name}" >> logs/percent.list
        done
}

# split list of input files into $ProcNum parts for parallel run
split -n l/${ProcNum} -a 2 -de logs/input_files_for_ctf.list logs/proc
ProcNum2=$((ProcNum-1))
if [ $inputType -eq 0 ]; then
        for nu in `seq -f "%02.0f" 0 ${ProcNum2}`
                do
                        ctfestimateSums logs/proc${nu} &
                        echo $! >> logs/pid.list
                done
fi
if [ $inputType -eq 1 ]; then
        for nu in `seq -f "%02.0f" 0 ${ProcNum2}`
                do
                        ctfestimateMovies logs/proc${nu} &
                        echo $! >> logs/pid.list
                done
fi

# display progress bar
ProI=0
setterm -cursor off
echo -en "Estimating CTF from images in folder ${inputFolder}. Completed:"
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
rm -rf .tmp logs/percent.list logs/proc* logs/pid.list
echo -e "\nDone! Output files are in Micrographs/ folder. Defocus and maximum detected resolution are in ctfrings.txt file. The values are sorted by resolution.\n"
rm -f ctfrings.txt
for i in `ls Micrographs/*.txt | grep -v '_avrot'`
        do
                awk 'END{if( $7 ~ /^[0-9]+/ ){print FILENAME,$2,$7}else{print FILENAME,"None","None"}}' ${i};
        done | sed 's/txt/mrc/' | sort -n -k3 > ctfrings.txt
bad_ctf=`grep -c "None" ctfrings.txt`
[ $bad_ctf -ne 0 ] && echo "Found $bad_ctf micrographs where CTFFIND4 has probably crashed! Check ctfrings.txt file."
