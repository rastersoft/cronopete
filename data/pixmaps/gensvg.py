#!/usr/bin/env python

import sys
import os



if (len(sys.argv)!=2):
    print "Usage: gensvg input_file"
    sys.exit()
    
colors={"white":["#234567","#234567"], "red":["#ff0000","#ff0000"], "green":["#00ff00","#00ff00"], "yellow":["#ffc000","#ffc000"], "orange":["#ff8000","#ff8000"]}
sizes={"16":18, "22":13, "24":12 ,"32":11 , "48":10 ,"64":8, "128":4}
default_size=18

do_sizes=False

fileini=open(sys.argv[1]+".svg","r")
picture=fileini.read()
fileini.close()

fname=sys.argv[1]
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
    newpic=newpic.replace("fill:#234567","fill:"+colors[color][0]).replace("stroke:#123456","stroke:"+colors[color][1]).replace("stroke-width:20;","stroke-width:"+str(default_size)+";")
    fname3=fname+"_"+color
    fileout=open(fname3+".svg","w")
    fileout.write(newpic)
    fileout.close()
