#!/bin/bash
# clean the folders after EPU acquisition, removing all xml | jpg | dm and all metadata

find . \( -name "*.xml" -o -name "*.jpg" -o -name "*.dm" -o -name "FoilHoles" -o -name "Metadata" -o -name "GridSquare*" \) -exec rm -rf {} +
