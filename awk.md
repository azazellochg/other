__Some useful awk scripts:__

* replace columns in one file with columns of another (fiels have to contain equal number of lines).
The following will replace columns 11,12,10 in file1 with columns 2,3,4 of file2, respectively [(link):](http://stackoverflow.com/questions/7846476/replace-column-in-one-file-with-column-from-another-using-awk)

```
awk 'FNR==NR{a[NR]=$2;b[NR]=$3;c[NR]=$4;next}{$11=a[FNR];$12=b[FNR];$10=c[FNR];}1' file2 file1 > output
```

* check if value if not in array.
The following example will read file1 (one column file) into array and compare it to field 22 in file2.
NF<3 skips the header of star file:

```
awk 'NR==FNR{a[$0];next}NF<3||!($22 in a)' file1 file2 > output
```

* print field if NR is in array.
The following will grep numbers from lines.txt file and print field $4 for lines from input.txt, if line number is present in the array:

```
awk 'FNR==NR{array[$1]=1;next}(FNR in array){print $4}' lines.txt input.txt  > output.txt
```

* change values of certain columns.
The following script will change columns $6,$17,$18 and can be used to go from C4 to C2 data star file:

```
awk '{if (NF<3) {print} else {$6="28.000000"; $17=$17*2; $18=$18*2; print} }' file_data.star
```

* calculate average and stdev for a single column (#11):

```
awk 'NF>3{x+=$11}END{print x/NR}' micrgraphs_ctf.star
awk 'NF>3{x+=$11;y+=$11^2}END{print sqrt(y/NR-(x/NR)^2)}' micrographs_ctf.star
```
