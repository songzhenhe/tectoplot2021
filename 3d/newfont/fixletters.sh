#!/bin/bash
for ofile in *.obj; do printf "%s " $ofile; gawk < $ofile 'BEGIN { maxx=0 } ($1=="v") { maxx=($2>maxx)?$2:maxx } END {print maxx}'; done
