#!/bin/bash
# clean the folders after EPU acquisition, removing all xml | jpg | dm and all metadata
[ -f bad_files.txt ] && rm -f bad_files.txt
find . \( -name "*.xml" -o -name "*.jpg" -o -name "*.dm" -o -name "FoilHoles" -o -name "Metadata" \) >> bad_files.txt
