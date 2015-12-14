To sort micrographs by max resolution detected by CTFFIND4:
  * max res is column #6 (CTFFIND version <= 4.0.15) or #7 in txt file!

```
for i in `ls aligned_sums/*.txt | grep -v '_avrot'`;do awk 'END{print FILENAME,$6}' ${i};done | sort -n -k2 > ctfrings.txt
```

To select micrographs with resolution better than N Angstrom (check that #14 is _rlnMicrographName):

```
awk '$2>N{print $1}' ctfrings.txt > above_NA.txt
awk 'NR==FNR{a[$0];next}NF<3||!($14 in a)' above_NA.txt Refine3D/*_data.star > Refine3D/*_below_NA_data.star
```
