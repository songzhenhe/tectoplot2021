#!/bin/bash
# script to output OBJ objects that are translated and scaled (but not rotated)

# Expects to read two files: a OBJ file to replicate and a data file
# Data file format:
# xoffset yoffset zoffset scale Red Green Blue

gawk -v material="$3" '
  BEGIN {
    itemind=0
    sphereind=1
    vertexind=0

    # This variable keeps track of the actual vertex number
    lastvertexind=0
  }

  # Read in the template obj file
  # obj format lines such as v x y z etc, whitespace separated, empty lines ignored
  # vertex normal are not adjusted

  (NR==FNR && substr($1,0,1) != "#" && $1 != "") {
    itemind++
    full[itemind]=$0
    for(ind=1;$(ind)!="";ind++) {
      obj[itemind][ind]=$(ind)
    }
    len[itemind]=ind-1
  }
  # x y z scale r g b
  (NR!=FNR) {
    xoff=$1
    yoff=$2
    zoff=$3
    scale=$4
    red=$5
    green=$6
    blue=$7
    print "o Sphere_" sphereind++
    if (material != "") {
      print "usemtl", material
    }
    vertexind=0
    for (i in len) {
      if (obj[i][1]=="v") {
        # Execute the scale and translation of the object
        print "v", obj[i][2]*scale+xoff, obj[i][3]*scale+yoff, obj[i][4]*scale+zoff, red, green, blue
        vertexind++
      } else if (obj[i][1]=="f") {
        # Face vertices have to be incremented to account for prior spheres
        printf("f ");
        for (k=2; k<=len[i]; k++) {
          printf("%d ", obj[i][k]+lastvertexind)
        }
        printf("\n")
      }
    }
    lastvertexind+=vertexind
  }
  ' $1 $2
