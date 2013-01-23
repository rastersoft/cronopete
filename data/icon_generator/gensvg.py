#!/usr/bin/env python

import sys
import os

if (len(sys.argv)!=2):
    print "Usage: gensvg input_file"
    print "Example: gensvg cronopete_arrow"
    sys.exit()

# First is the name of the icon; second the inner color for the arrow; third the outline color for the arror; fourth the fill color for the container circle

colors={"white":["#bebebe","#234567","#ffffff"], "red":["#ff0000","#ff0000","#ffffff"], "green":["#00ff00","#00ff00","#ffffff"], "yellow":["#ffc000","#ffc000","#ffffff"], "orange":["#ff8000","#ff8000","#ffffff"]}

# DEFAULT_SIZE contains the outline width for the arror
default_size=18

# If do_sizes is true, will also generate PNGs in sizes 16, 22, 24, 32, 48, 64 and 128 pixels. SIZES contains the outline width for the arrow, for each size
sizes={"16":18, "22":13, "24":12 ,"32":11 , "48":10 ,"64":8, "128":4}
do_sizes=False

for number in [1,2,3,4]:

    fname=sys.argv[1]+"-"+str(number)

    fileini=open(fname+".svg","r")
    picture=fileini.read()
    fileini.close()

    for color in colors:

        if do_sizes:
            for size in sizes:
                newpic=picture[:]
                newpic=newpic.replace("fill:#234567","fill:"+colors[color][0]).replace("stroke:#123456","stroke:"+colors[color][1]).replace("stroke-width:20;","stroke-width:"+str(sizes[size])+";")
                fname2=fname+"_"+color+"_"+size+"x"+size
                fileout=open("tmp.svg","w")
                fileout.write(newpic)
                fileout.close()
                command="inkscape -f tmp.svg -e "+fname2+".png -C -w "+size+" -h "+size
                os.system(command)
                os.system("rm tmp.svg")

        newpic=picture[:]
        newpic=newpic.replace("fill:#345678","fill:"+colors[color][2]).replace("fill:#234567","fill:"+colors[color][0]).replace("stroke:#123456","stroke:"+colors[color][1]).replace("stroke-width:20;","stroke-width:"+str(default_size)+";")
        fname3=fname+"-"+color
	if color=="white":
                fname3+="-symbolic"
        fileout=open(fname3+".svg","w")
        fileout.write(newpic)
        fileout.close()
