#!/bin/bash
echo -e "Batch to process SerialEM mrc stacks: unstack in raw_images folder\n............."
# check if EMAN2 is sourced
if [ -z $EMAN2DIR ]; then
        echo "EMAN2 NOT found!" && exit 1
fi

mkdir raw_images
for i in `ls *.mrc | sed -e "s/.mrc//g"`
do
  e2proc2d.py ${i}.mrc raw_images/${i}.mrc --unstacking --threed2twod >> output.log 2>&1
done
