__Some useful sed scripts:__

* replace newline with spaces

```
sed ':a;N;$!ba;s/\n/ /g'
```

* modify the line (replace 'c4' with 'c2') if it contains 'particles_grid1' or 'particles_grid2'

```
sed '/particles_grid1\|particles_grid2/s/c4/c2/' file
```
