#!/bin/env python3

import sys
import os
import xml.etree.ElementTree as ET


def parseXml(fn):
    """ Parsing Falcon 4 defects xml file to txt in Motioncor format."""
    defects = []  # x y w h
    tree = ET.parse(fn)
    root = tree.getroot()

    for item in root:
        if item.tag == "point":
            point = item.text.split(",")
            defects.append((int(point[0]), int(point[1]), 1, 1))
        elif item.tag == "area":
            area = item.text.split(",")
            defects.append((int(area[0]),
                            int(area[1]),
                            int(area[2])-int(area[0])+1,
                            int(area[3])-int(area[1])+1))
        elif item.tag == "col":
            area = item.text.split("-")
            defects.append((int(area[0]), 0,
                            int(area[1])-int(area[0])+1,
                            4096))
        elif item.tag == "row":
            area = item.text.split("-")
            defects.append((0, int(area[0]),
                            4096,
                            int(area[1])-int(area[0])+1))

    if defects:
        with open("defects.txt", "w") as f:
            for d in defects:
                print(d)
                f.write(" ".join(str(i) for i in d) + "\n")
        print("Saved to defects.txt")


def main():
    if len(sys.argv) == 2:
        parseXml(sys.argv[1])
    else:
        raise ValueError(f"Unrecognized input, please use: {os.path.basename(sys.argv[0])} SensorDefects.xml")


if __name__ == "__main__":
    main()
