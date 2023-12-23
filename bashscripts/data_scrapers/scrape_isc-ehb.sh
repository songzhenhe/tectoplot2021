#!/bin/bash

# tectoplot
# bashscripts/scrape_isc-ehb.sh
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

# This script will download the ISC-EHB yearly data files in HDR format.

# Output is a file containing centroid (gcmt_centroid.txt) and origin (gcmt_origin.txt) location focal mechanisms in tectoplot 27 field format:

[[ ! -d $ISCEHBDIR ]] && mkdir -p $ISCEHBDIR

cd $ISCEHBDIR

echo "Downloading ISC-EHB data in HDF format"

for year in $(seq 1964 2017); do
  if [[ ! -s ${year}.hdf ]]; then
    echo "Downloading ${year}.hdf.gz"
    curl "ftp://isc-mirror.iris.washington.edu/pub/isc-ehb/${year}.hdf.gz" > ${year}.hdf.gz
    if gunzip -t ${year}.hdf.gz; then
      gunzip ${year}.hdf.gz
    else
      rm -f ${year}.hdf.gz
    fi
  fi
done


# read(1,100)
#   1    2     3    4   5   6    7   8   9  10 11   12
# 1 ahyp,isol,iseq,iyr,mon,iday,ihr,min,sec,ad,glat,glon,
#   13    14     15 16 17 18   19   20   21    22  23  24
# 2 depth,iscdep,mb,ms,mw,ntot,ntel,ndep,igreg,se,ser,sedep,
#   25      26      27      28  29    30  31    32   33
# 3 rstadel,openaz1,openaz2,az1,flen1,az2,flen2,avh,ievt
# 100  format(a1,a3,a2,i2,2i3,1x,2i3,f6.2,a1,2f8.3,2f6.1,3f4.1,
# 1 4i4,3f8.2,3f6.1,4i4,f5.1,i10)

# 1 ahyp,isol,iseq,iyr,mon,iday,ihr,min,sec,ad,glat,glon,
# 2 depth,iscdep,mb,ms,mw,ntot,ntel,ndep,igreg,se,ser,sedep,
# 3 rstadel,openaz1,openaz2,az1,flen1,az2,flen2,avh,ievt

# DEQMd17  1 28  13 40 29.27   39.753 140.633 151.3 153.9 4.9 0.0 4.9 999 921  91 227    0.83    1.71    0.58   0.2  27.5  48.5 147  17  57  13  1.1 610147532
#-___--__---___-___---______-________--------______------____----____----____----____--------________--------______------______----____----____-----__________
# FEQMo17 12 31  20 27 48.77   -8.132  68.047  10.0  13.3 4.8 4.3 5.1 242 239   1 426    0.91    4.23    0.00  13.0  46.0  58.6  28  45 118  32  2.9 611613251
# 1 3 2 2 3 3 1 3 3 6 1 8 8 6 6 4 4 4 4 4 4 4 4 8 8 8 6 6 6 4 4 4 4 5 10
# iyr =
rm -f ehb_events.cat
for ehbfile in *.hdf; do
  gawk < $ehbfile '
    @include "tectoplot_functions.awk"
    BEGIN  {
      FIELDWIDTHS = "1 3 2 2 3 3 1 3 3 6 1 8 8 6 6 4 4 4 4 4 4 4 8 8 8 6 6 6 4 4 4 4 5 10"
    }
    {
        decade=$4
        if (decade<64) {
          year=decade+2000
        } else {
          year=decade+1900
        }
        month=$5+0
        day=$6+0
        hour=$7+0
        minute=$8+0
        second=$9+0
        lat=$12+0
        lon=$13+0
        depth=$14+0
        mag=$16+0
        id=trim($34)
        the_time=sprintf("%04i %02i %02i %02i %02i %02i",year,month,day,hour,minute,int(second+0.5));
        epoch=mktime(the_time);
        timestring=sprintf("%4d-%02d-%02dT%02d:%02d:%02d", year, month, day, hour, minute, second)
        print lon, lat, depth, mag, timestring, id, epoch
    }
    ' >> ehb_events.cat
done
