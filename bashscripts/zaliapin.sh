#!/bin/bash

# tectoplot
# bashscripts/zaliapin.sh
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

# Call the Python code by Mark C. Williams implementing Zaliapin declustering
# based on nearest neighbors

# Arguments: zaliapin.sh [eq_file.txt] [python_loc] [path_to_declustering.py]
# Outputs: catalog_declustered.txt catalog_clustered.txt

# python_loc is the path to the Python executable
# path_to_declustering.py is the full path to the declustering Python code

# Input catalog is:
#  lon lat depth mag iso8601_date ID [[epoch]] ...

# Output format is
# year month day hour minute second lat lon depth mag

PYTHON=$(python3 -c "import sys; print(sys.executable)")

if [[ ! -x ${PYTHON} ]]; then
  echo "Python executable is not at ${PYTHON}"
  exit
fi

DECLUSTERER=${2}
if [[ ! -s ${DECLUSTERER} ]]; then
  echo "Python declustering code is not at ${DECLUSTERER}"
  exit 1
fi
rm -f ./zaliapin_data.txt

gawk < $1 '{
magnitude=$4
lon=$1
lat=$2
depth=$3
timecode=substr($5, 1, 19)
split(timecode, a, "-")
year=a[1]
month=a[2]
split(a[3],b,"T")
day=b[1]
split(b[2],c,":")
hour=c[1]
minute=c[2]
second=c[3]

printf("%d\t%d\t%d\t%d\t%d\t%f\t%f\t%f\t%f\t%f\n", year, month, day, hour, minute, second, lat, lon, depth, magnitude)

}' > ./zaliapin_data.txt

if [[ ! -s ./zaliapin_data.txt ]]; then
  echo "Converting earthquake data to Zaliapin input format failed."
fi

# Call the declustering software. Produces ./zaliapin_output.txt
${PYTHON} ${DECLUSTERER}

gawk < ./zaliapin_output.txt '{print $8}' > ./zaliapin_clusters.txt

# Make a list of line numbers and cluster IDs of events with unique parents
sort -u zaliapin_clusters.txt > ./zaliapin_unique.txt

paste ${1} zaliapin_clusters.txt > ./zaliapin_combined.txt

rm -f ./uniques.txt ./nonuniques.txt

gawk < ./zaliapin_combined.txt '{
  data[NR]=sprintf("%s %s %s %s %s %s %s", $1, $2, $3, $4, $5, $6, $7)
  parent[NR]=$15
  P[NR]=$14
  id[NR]=NR

  seen[$15]++
}
END {
  for (el in data) {
    if (seen[parent[el]] > 5) {
      # Significant cluster
      if (parent[el] == id[el]) {
        print data[el], P[el]+1 > "./mainshocks_data.txt"
      } else {
        print data[el], P[el]+1 > "./clustered_data.txt"
      }
    } else {
      print data[el], 1 > "./unclustered_data.txt"
    }
  }
}'

# gawk < ./zaliapin_clusters.txt 'BEGIN { rat=1 } {
#   cluster[NR]=$1
#   seen[$1]++
#   if (seen[$1] > 1) {
#     indices[rat++]=$1
#   }
# }
# END {
#   for (i=1; i<=NR; i++) {
#     clusteredflag=0
#     for (j=1; j <=rat; j++) {
#       if (cluster[i]==indices[j]) {
#         clusteredflag=1
#         break
#       }
#     }
#     if (clusteredflag == 1) {
#       print cluster[NR]+1
#     } else {
#       print 1
#     }
#   }
# }'
