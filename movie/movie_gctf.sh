#!/bin/bash
# This script runs gctf on either movie stacks or aligned sums
########### user input #################
gctf_bin="/home/sharov/soft/Gctf_v0.50/bin/Gctf-v0.50_sm_30_cu5.5_x86_64"
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
ast="1000"              # Expected (tolerated) astigmatism, A

epa="0"                 # Do EPA (Equiphase average used for output CTF file)
ring="0"                # Plot a max resolution ring on a PSD file
########### end of user input ##########
export LC_ALL="en_US.UTF-8"
rm -rf Micrographs
rm -rf logs/gctf.log logs/percent.list logs/pid.list >> /dev/null 2>&1

# check input
echo "Please select input folder containing total sums (*.mrc) or movies: (*.mrcs) "
inputFolder=`zenity --title="Select input folder with images" --file-selection --directory`
[ ! -d ${inputFolder} ] && echo "ERROR! Input folder ${inputFolder} not found!" && exit 1
if [ `ls "${inputFolder}" | head -1 | egrep '(.mrc)\b'` ]; then
        inputType=0
elif [ `ls "${inputFolder}" | head -1 | egrep '(.mrcs)\b'` ]; then
        inputType=1
        echo "Movies are not supported by this script yet! Sorry!" && exit 1
else
        echo "Input file format is not recognized!" && exit 1
fi
[ -d logs ] || ( echo "Warning: logs folder not found!" && mkdir logs )
[ -d Micrographs ] && echo "Error: Micrographs folder already exist! Please remove it." && exit 1
mkdir Micrographs
trap "setterm -cursor on" SIGHUP SIGINT SIGTERM
rm -f logs/input_files_for_ctf.list
[ ${inputType} -eq 0 ] && ls ${inputFolder}/*.mrc > logs/input_files_for_ctf.list
[ ${inputType} -eq 1 ] && ls ${inputFolder}/*.mrcs > logs/input_files_for_ctf.list
MicNum=`wc -l < logs/input_files_for_ctf.list`

# main functions
ctfestimateMovies () {
:
}

# create links
for ima in `cat logs/input_files_for_ctf.list`
        do
                name=`basename $ima | egrep -o 'FoilHole_[0-9]*_Data_[0-9]*_[0-9]*_[0-9]{8,8}_[0-9]{4,4}'`
                ln -s "${ima}" Micrographs/"${name}".mrc
        done

# functions
ctfestimateSums () {
        ${gctf_bin} --apix "${pix}" --kV $acc --cs "${sph}" --ac "${amp}" --dstep $dstep --defL "${min_def}" --defH "${max_def}" --defS "${step_def}" --astm $ast --resL "${min_res}" --resH "${max_res}" \
                --do_EPA $epa --boxsize $size --plot_res_ring $ring --gid 0 --logsuffix _ctffind3.log Micrographs/* > logs/gctf.log
}

# main part
if [ $inputType -eq 0 ]; then
        ctfestimateSums &
        echo $! >> logs/pid.list
fi
if [ $inputType -eq 1 ]; then
        ctfestimateMovies &
        echo $! >> logs/pid.list
fi

# display progress bar
ProI=0
setterm -cursor off
echo -en "Estimating CTF from images in folder ${inputFolder}. Completed:"
while [ "$ProI" -eq 0 ]
        do
                kill -0 `cat logs/pid.list` 2>/dev/null
                ProI=$?
                c=`ls Micrographs/*_ctffind3.log 2>/dev/null | wc -l`
                sw=`echo "scale=2;$c/${MicNum}*100" | bc`
                sww=`printf "%0*d\n" 2 $sw 2> /dev/null`
                echo -en "${sww}%\b\b\b"
                sleep 2
        done
setterm -cursor on
rm -rf logs/pid.list
rm -f Micrographs/*.mrc
echo -e "\nDone! Output is in Micrographs/ folder and in micrographs_all_gctf.star file.\n"
