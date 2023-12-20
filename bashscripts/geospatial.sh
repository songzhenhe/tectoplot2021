# tectoplot
# bashscripts/geospatial.sh
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

################################################################################
# Grid (raster) file functions

# Grid z range query function. Try to avoid querying the full grid when determining the range of Z values

function grid_zrange() {
   output=$(gmt grdinfo -C $@)
   zmin=$(echo "${output}" | gawk  '{printf "%f", $6+0}')
   zmax=$(echo "${output}" | gawk  '{printf "%f", $7+0}')
   if [[ $(echo "$zmin == 0 && $zmax == 0" | bc) -eq 1 ]]; then
      output=$(gmt grdinfo -C -L $@)
   fi
   echo "${output}" | gawk  '{printf "%f %f", $6+0, $7+0}'
}

################################################################################
# XY (point and line) file functions

# XY range query function from a delimited text file
# variable=($(xy_range data_file.txt [[delimiter]]))
# Ignores lines that do not have numerical first and second columns

function xy_range() {
  local IFSval=""
  if [[ $2 == "" ]]; then
    IFSval=" "
  else
    IFSval="-F${2:0:1}"
  fi
  gawk < "${1}" ${IFSval} '
    BEGIN {
      minlon="NaN"
      while (minlon=="NaN") {
        getline
        if ($1 == ($1+0) && $2 == ($2+0)) {
          minlon=($1+0)
          maxlon=($1+0)
          minlat=($2+0)
          maxlat=($2+0)
        }
      }
    }
    {
      if ($1 == ($1+0) && $2 == ($2+0)) {
        minlon=($1<minlon)?($1+0):minlon
        maxlon=($1>maxlon)?($1+0):maxlon
        minlat=($2<minlat)?($2+0):minlat
        maxlat=($2>maxlat)?($2+0):maxlat
      }
    }
    END {
      print minlon, maxlon, minlat, maxlat
    }'
}




# gawk code inspired by lat_lon_parser.py by Christopher Barker
# https://github.com/NOAA-ORR-ERD/lat_lon_parser

# This function will take a string in the (approximate) form
# +-[deg][chars][min][chars][sec][chars][north|*n*]|[south|*s*]|[east|*e*]|[west|*w*][chars]
# and return the appropriately signed decimal degree
# -125°12'18" -> -125.205
# 125 12 18 WEST -> -125.205


function coordinate_parse() {
  echo "${1}" | gawk '
  @include "tectoplot_functions.awk"
  {
    printf("%.10f\n", coordinate_decimal($0))
  }'
}

# Convert first line/polygon element in KML file $1, store output XY file in $2

function kml_to_first_xy() {
  ogr2ogr -f "OGR_GMT" ./tectoplot_tmp.gmt "${1}"
  gawk < ./tectoplot_tmp.gmt '
    BEGIN {
      count=0
    }
    ($1==">") {
      count++
      if (count>1) {
        exit
      }
    }
    ($1+0==$1) {
      print $1, $2
    }' > "${2}"
    rm -f ./tectoplot_tmp.gmt
}
