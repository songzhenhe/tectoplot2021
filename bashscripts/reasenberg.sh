#!/bin/bash

# tectoplot
# bashscripts/reasenberg.sh
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

# Use the Fortran code of Reasenberg to decluster an earthquake catalog

# reasenberg.sh [catalog_file] [path_to_reasenberg_executable]

#FORMAT(i4,5i2,f3.1,2a1,f7.3,f8.3,f5.1,a1)
#C    THAT CORRESPONDS TO:
#C                         I4 --> YEAR
#C                        5I2 --> MONTH/DAY/HOUR/MINUTE/SEC
#C                       F3.1 --> MAGNITUDE
#C                        2A1 --> TYPE OF EVENT/MAGNITUDE TYPE.
#C                                IT FOLLOWS THE SCECDC FORMAT CODE.
#C                       F7.3 --> LATITUDE IN DEGREES
#C                       F8.3 --> LONGITUDE IN DEGREES
#C                       F5.1 --> DEPTH IN KM
#C                         A1 --> QUALITY OF THE LOCATION

# Input catalog is:
#  lon lat depth mag iso8601_date ID [[epoch]] ...

# First, convert the catalog to Reasenberg format for cluster2000x

# year month day lat lon mag
# jyr, itime(2), itime(3), xjlat, xjlon, xmag1

CATALOG=${1}
REASENBERG=${2}
DECLUSTER_MINSIZE=${3}

rm -f ./shiftyear.txt ./catalog_pre.txt ./catalog.txt ./decluster2000x.cat ./to_decluster.txt

gawk < ${CATALOG} -v lastyear=2021 'BEGIN {
  eqcode="EQ"
  eqquality="H"
  maxyear=-9999
  minyear=9999
}{
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

maxyear=(year>maxyear)?year:maxyear
minyear=(year<minyear)?year:minyear

years[NR]=year
string[NR]=sprintf("%d %d %f %f %f\n", month, day, lat, lon, magnitude)
catalog[NR]=$0

}
END {
  shiftyear=(1999-maxyear)
  print shiftyear > "./shiftyear.txt"
  for (key in string) {
    if ((years[key]+shiftyear) < 1900) {
      print catalog[key], "1" >> "./catalog_pre.txt"
    } else {
      print catalog[key] >> "./catalog.txt"
      printf("%d %s", years[key]+shiftyear, string[key]) >> "./to_decluster.txt"
    }
  }
}'

rm -f ./cluster.ano ./cluster.clu ./cluster.dec ./cluster.out ./catalog_declustered.txt ./catalog_clustered.txt
${REASENBERG}
# Outputs: cluster.ano ($11 has cluster ID-1)
gawk < cluster.ano '{print $11+1}' > cluster.id
[[ -s catalog_pre.txt ]] && cat catalog_pre.txt | tr '\t' ' ' > ./reasenberg_results.txt
paste catalog.txt cluster.id | tr '\t' ' ' >> ./reasenberg_results.txt

gawk < ./reasenberg_results.txt -v mineqs=${DECLUSTER_MINSIZE} '
{
  seen[$8]++
  data[NR]=$0
  cluster[NR]=$8
}
END {
  for(i=1;i<=NR;i++) {
    if (cluster[i] == 1 || seen[$8] < mineqs) {
      # Independent events
      print data[i] > "./catalog_declustered.txt"
    } else {
      print data[i] > "./catalog_clustered_presort.txt"
    }
  }
}'

# Sort the earthquake catalog by Cluster ID, Magnitude (descending) and then
# by time (ascending). The mainshock of earliest event of those that share the
# largest magnitude. We can find foreshocks this way as well.

# 91.0921 -10.1229 4 6.5 2014-06-14T11:10:59 usc000rfh2 1402715459	2
sort ./catalog_clustered_presort.txt -n -k8,8r -k4,4r -k5,5 | gawk '{
  seen[$8]++
  if (seen[$8] > 1) {
    # event is an aftershock or foreshock
    print > "./catalog_clustered.txt"
  } else {
    # Event is a mainshock - not dependent
    print >> "./catalog_declustered.txt"
  }
}'
