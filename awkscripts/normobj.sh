#!/bin/bash

gawk < $1 '
function norm(a,b,c) {
  return sqrt(a*a+b*b+c*c)
}
{
  if ($1=="v" || $1 == "vn") {
    len=norm($2,$3,$4)
    print $1, $2/len, $3/len, $4/len
  } else {
    print
  }
}
'
