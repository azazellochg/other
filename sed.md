__Some useful sed scripts:__

* replace newline with spaces

```
sed ':a;N;$!ba;s/\n/ /g'
```
