#!/bin/bash

# tectoplot
# bashscripts/scrape_gcmt.sh
# Copyright (c) 2021 Kyle Bradley, all rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors
#    may be used to endorse or promote products derived from this software without
#    specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# This script will download GCMT data in ndk format and produce an event catalog
# in tectoplot CMT format. That catalog will be merged with other catalogs to
# produce a final joined catalog.

# Output is a file containing centroid (gcmt_centroid.txt) and origin (gcmt_origin.txt) location focal mechanisms in tectoplot 27 field format:

[[ ! -d $GCMTDIR ]] && mkdir -p $GCMTDIR

cd $GCMTDIR

[[ ! -e jan76_dec17.ndk ]] && curl "https://www.ldeo.columbia.edu/~gcmt/projects/CMT/catalog/jan76_dec17.ndk" > jan76_dec17.ndk

years=("2018" "2019" "2020")
months=("jan" "feb" "mar" "apr" "may" "jun" "jul" "aug" "sep" "oct" "nov" "dec")

for year in ${years[@]}; do
  YY=$(echo $year | tail -c 3)
  for month in ${months[@]}; do
    [[ ! -e ${month}${YY}.ndk ]] && curl "https://www.ldeo.columbia.edu/~gcmt/projects/CMT/catalog/NEW_MONTHLY/${year}/${month}${YY}.ndk" > ${month}${YY}.ndk
  done
done

echo "Downloading Quick CMTs"

curl "https://www.ldeo.columbia.edu/~gcmt/projects/CMT/catalog/NEW_QUICK/qcmt.ndk" > quick.ndk

rm -f gcmt_extract_pre.cat
echo "Extracting GCMT focal mechanisms from NDK to tectoplot format"

for ndkfile in *.ndk; do
  res=$(grep 404 $ndkfile)
  if [[ $res =~ "<title>404" ]]; then
    echo "ndk file $ndkfile was not correctly downloaded... deleting."
    rm -f $ndkfile
  else
    echo "Extracting $ndkfile"
    ${CMTTOOLS} $ndkfile K G >> gcmt_extract_pre.cat
  fi
done

# Go through the catalog and remove Quick CMTs (PDEQ) that have a PDEW equivalent

gawk < gcmt_extract_pre.cat '
 {
   seen[$2]++
   id[NR]=$2
   catalog[NR]=$12
   data[NR]=$0
 }
 END {
   for(i=1;i<=NR;i++) {
     if (seen[id[i]] > 1 && catalog[i]=="PDEQ") {
       print data[i] > "./gcmt_pdeq_removed.cat"
     } else {
       print data[i]
     }
   }
 }' > gcmt_extract.cat
