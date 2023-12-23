#!/bin/bash

# simplify an OBJ file by removing vertices not referenced by a face
# Assumes output faces will have same index for vertex/normal/texture points

gawk < $1 '
BEGIN {
  vertexind=1
  normalind=1
  textureind=1
  faceind=1
}
{
  if ($1=="v") {
    vertexdata[vertexind++]=$0
  } else if ($1=="vn") {
    normaldata[normalind++]=$0
  } else if ($1=="vt") {
    texturedata[textureind++]=$0
  } else if ($1=="f") {
    facedata[faceind]=$0
    i=1
    while($(i+1)!="") {
      split($(i+1), splitstr, "/")
      # Mark the vertex index as being seen
      # print "seeing vertex", splitstr[1]
      seenindex[splitstr[1]]=1
      faceindex[faceind][i]=splitstr[1]
      facecount[faceind]++
      i++
    }
    faceind++
  }
}
END {
  unseencount=0
  for (i=1; i<vertexind; i++) {
    if (seenindex[i]==0) {
      addme=1
    } else {
      addme=0
    }
    unseencount+=addme
    unseenbefore[i]=unseencount
    # print "Seen:", i, seenindex[i]
  }
  for (i=1; i<vertexind; i++) {
    if (seenindex[i]==1) {
      print vertexdata[i]
    }
  }
  for (i=1; i<normalind; i++) {
    if (seenindex[i]==1) {
      print normaldata[i]
    }
  }
  print "Textureind" textureind > "/dev/stderr"
  for (i=1; i<textureind; i++) {
    if (seenindex[i]==1) {
      print texturedata[i]
    }
  }

  for(i=1; i<faceind; i++) {
    # print facedata[i]
    printf("f ")
    for(j=1; j<= facecount[i]; j++) {
      vertbefore=faceindex[i][j]
      vertafter=vertbefore-unseenbefore[vertbefore]
      printf("%d/%d/%d ", vertafter, vertafter, vertafter)
    }
    printf("\n")
  }
}
'
