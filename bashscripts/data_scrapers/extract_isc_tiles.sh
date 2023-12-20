#!/bin/bash

# tectoplot
# bashscripts/extract_isc_tiles.sh
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

# extract_isc_tiles.sh DATADIR MINLON MAXLON MINLAT MAXLAT MINTIME MAXTIME MINMAG MAXMAG MINDEPTH MAXDEPTH OUTFILE

# extract_isc_tiles.sh $ISCTILEDIR $MINLON $MAXLON $MINLAT $MAXLAT $STARTTIME $ENDTIME $EQ_MINMAG $EQ_MAXMAG $EQCUTMINDEPTH $EQCUTMAXDEPTH ${F_SEIS_FULLPATH}isc_extract_tiles.cat
# This script will print all events from a tiled ISC catalog directory (tile_lon_lat.cat)
# where the files are in tiled ISC CSV format without a header line.

# Additionally, the script will filter out some non-natural events by excluding lines
# containing: blast quarry explosion

# CSV format is:
# 1       2         3           4          5        6         7     8      9         10     11   12+
# EVENTID,AUTHOR   ,DATE      ,TIME       ,LAT     ,LON      ,DEPTH,DEPFIX,AUTHOR   ,TYPE  ,MAG  [, extra...]

# Epoch time calculation doesn't work for events before 1900 (mktime returns -1) so return 1900-01-01T00:00:00 time instead

# OSX Catalina 10.15.7 (19H15) has a strange problem, probably with libc? that makes gawk/awk mktime fail for a few specific
# dates: 1941-09-01, 1942-02-16, and 1982-01-01. This is not a problem on a tested linux machine. Odd..

# Reads stdin, converts each item in a column and outputs same column format

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
        }
      }
    }


  }'))

# Currenly broken for AOI longitudes like: [-200, -170]. Works for [170, 190]
# ISC CSV files don't have location strings or quotation marks, unlike Comcat CSV
# echo Selected ${selected_files[@]}
# CSV format is:
# 1       2         3           4          5        6         7     8      9         10     11   12+
# EVENTID,AUTHOR   ,DATE      ,TIME       ,LAT     ,LON      ,DEPTH,DEPFIX,AUTHOR   ,TYPE  ,MAG  [, extra...]
#  752622,ISC      ,1974-01-14,03:59:31.48, 28.0911, 131.4943, 10.0,TRUE  ,ISC      ,mb    , 4.3

for this_file in ${selected_files[@]}; do
  gawk < $this_file -F, -v minlon=${2} -v maxlon=${3} -v minlat=${4} -v maxlat=${5} -v mindate=${6} -v maxdate=${7} -v minmag=${8} -v maxmag=${9} -v mindepth=${10} -v maxdepth=${11} '
  ($5 <= maxlat && $5 >= minlat && $11 >= minmag && $11 <= maxmag && $7 >= mindepth && $7 <= maxdepth) {

    if ((maxlon <= 180 && (minlon <= $6 && $6 <= maxlon)) || (maxlon > 180 && (minlon <= $6+360 || $6+360 <= maxlon))) {

      # Now we check if the event actually falls inside the specified time window
      timecode=sprintf("%sT%s", $3, substr($4, 1, 8))
      if (mindate <= timecode && timecode <= maxdate) {
        print
      }
    }
  }' >> ${12}
done
