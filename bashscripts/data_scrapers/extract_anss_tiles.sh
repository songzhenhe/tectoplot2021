#!/bin/bash

# tectoplot
# bashscripts/extract_anss.sh
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

# extract_anss.sh DATADIR MINLON MAXLON MINLAT MAXLAT MINTIME MAXTIME MINMAG MAXMAG MINDEPTH MAXDEPTH OUTFILE

# This script will print all events from a tiled ANSS catalog directory (tile_lon_lat.cat) to OUTFILE
# The tile files are in Comcat CSV format without a header line.

# Additionally, this script will filter out some non-natural events by excluding lines
# containing the words: blast quarry explosion

# CSV format is:
# 1    2        3         4     5   6       7   8   9    10  11  12 13      14    15   16              17         18       19     20     21             22
# time,latitude,longitude,depth,mag,magType,nst,gap,dmin,rms,net,id,updated,place,type,horizontalError,depthError,magError,magNst,status,locationSource,magSource

# Epoch time calculation doesn't work for events before 1900 (mktime returns -1) so return 1900-01-01T00:00:00 time instead

# NOTE: OSX has a strange problem, probably with libc? that makes gawk/awk mktime fail for a few specific
# dates: 1941-09-01, 1942-02-16, and 1982-01-01. This is not a problem on a tested linux machine...

# Reads stdin, converts each item in a column and outputs same column format

# function iso8601_to_epoch() {
#   TZ=UTC
#
#   gawk '{
#     # printf("%s ", $0)
#     for(i=1; i<=NF; i++) {
#       done=0
#       timecode=substr($(i), 1, 19)
#       split(timecode, a, "-")
#       year=a[1]
#       if (year < 1900) {
#         print -2209013725
#         done=1
#       }
#       month=a[2]
#       split(a[3],b,"T")
#       day=b[1]
#       split(b[2],c,":")
#
#       hour=c[1]
#       minute=c[2]
#       second=c[3]
#
#       if (year == 1982 && month == 01 && day == 01) {
#         printf("%s ", 378691200 + second + 60*minute * 60*60*hour)
#         done=1
#       }
#       if (year == 1941 && month == 09 && day == 01) {
#         printf("%s ", -895153699 + second + 60*minute * 60*60*hour)
#         done=1
#
#       }
#       if (year == 1941 && month == 09 && day == 01) {
#         printf("%s ", -879638400 + second + 60*minute * 60*60*hour)
#         done=1
#       }
#
#       if (done==0) {
#         the_time=sprintf("%04i %02i %02i %02i %02i %02i",year,month,day,hour,minute,int(second+0.5));
#         # print the_time > "/dev/stderr"
#         epoch=mktime(the_time);
#         printf("%s ", epoch)
#       }
#     }
#     printf("\n")
#   }'
# }

DATADIR=$1

if ! [[ -d $DATADIR ]]; then
  echo "Seismicity directory $DATADIR does not exist." > /dev/stderr
  exit 1
fi

cd $DATADIR

# # Initial selection of files based on the input latitude and longitude range
selected_files=($(gawk -v minlon=${2} -v maxlon=${3} -v minlat=${4} -v maxlat=${5} '
  @include "tectoplot_functions.awk"
  BEGIN   {
    newminlon=minlon
    newmaxlon=maxlon
    if (maxlon > 180) {
      tilesabove180flag=1
      maxlon2=maxlon-360
      maxlon=180
    }
    if (minlon < -180) {
      tilesbelowm180flag=1
      minlon2=minlon+360
      minlon=-180
    }
    minlattile=rd(minlat,5);
    minlontile=rd(minlon,5);
    maxlattile=rd(maxlat,5);
    maxlontile=rd(maxlon,5);
    maxlattile=(maxlattile>85)?85:maxlattile;
    maxlontile=(maxlontile>175)?175:maxlontile;
    # print "Selecting tiles covering domain [" newminlon, newmaxlon, minlat, maxlat "] -> [" minlontile, maxlontile+5, minlattile, maxlattile+5 "]"  > "/dev/stderr"
    for (i=minlontile; i<=maxlontile; i+=5) {
      for (j=minlattile; j<=maxlattile; j+=5) {
        printf("tile_%d_%d.cat\n", i, j)
      }
    }

    if (tilesabove180flag == 1) {
      minlattile=rd(minlat,5);
      minlontile=rd(-180,5);
      maxlattile=rd(maxlat,5);
      maxlontile=rd(maxlon2,5);
      maxlattile=(maxlattile>85)?85:maxlattile;
      maxlontile=(maxlontile>175)?175:maxlontile;
      # print ":+: Selecting additional tiles covering domain [" newminlon, newmaxlon, minlat, maxlat "] -> [" minlontile, maxlontile+5, minlattile, maxlattile+5 "]"  > "/dev/stderr"
      for (i=minlontile; i<=maxlontile; i+=5) {
        for (j=minlattile; j<=maxlattile; j+=5) {
          printf("tile_%d_%d.cat\n", i, j)
        }
      }
    }

    if (tilesbelowm180flag == 1) {
      minlattile=rd(minlat,5);
      minlontile=rd(minlon2,5);
      maxlattile=rd(maxlat,5);
      maxlontile=rd(175,5);
      maxlattile=(maxlattile>85)?85:maxlattile;
      maxlontile=(maxlontile>175)?175:maxlontile;
      print ":-: Selecting additional tiles covering domain [" newminlon, newmaxlon, minlat, maxlat "] -> [" minlontile, maxlontile+5, minlattile, maxlattile+5 "]"  > "/dev/stderr"
      for (i=minlontile; i<=maxlontile; i+=5) {
        for (j=minlattile; j<=maxlattile; j+=5) {
          printf("tile_%d_%d.cat\n", i, j)
          printf("tile_%d_%d.cat... ", i, j) > "/dev/stderr"
        }
      }
    }


  }'))

# The CSV files can have commas within the ID string messing up fields.
# Remove these and also the quotation marks in ID strings to give a parsable CSV file
# echo ${selected_files[@]} | tr ' ' '\n'
# Currenly broken for AOI longitudes like: [-200, -170]. Works for [170, 190]

for this_file in ${selected_files[@]}; do
  if [[ -s ${this_file} ]]; then
    gawk < $this_file -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1' | sed 's/\"//g' | \
    gawk -F, -v minlon=${2} -v maxlon=${3} -v minlat=${4} -v maxlat=${5} -v mindate=${6} -v maxdate=${7} -v minmag=${8} -v maxmag=${9} -v mindepth=${10} -v maxdepth=${11} '
    @include "tectoplot_functions.awk"
    ($1 != "time" && $15 == "earthquake" && mindate <= $1 && $1 <= maxdate && $2 <= maxlat && $2 >= minlat && $5 >= minmag && $5 <= maxmag && $4 >= mindepth && $4 <= maxdepth) {

      # Three cases: minlon < -180 (e.g. [-190:-170], maxlon>180 (e.g. [170:190]), and otherwise (e.g. [-170:170])

      if (test_lon(minlon, maxlon, $3)==1) {
        print
      }
    }' >> ${12}
  fi
done
