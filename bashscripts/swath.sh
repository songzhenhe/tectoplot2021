#!/bin/bash
#
# tectoplot
# smart_swath_update.sh
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

# smart_swath.sh profile_width[km] along_profile_dist_ave[km] cross_profile_dist_ave[km] xyfile gridfile resampleres[deg]
# OUTPUT: data_lr_sort.txt;

echo "${@}"

# Script that calculates a swath profile in dt,da space (distance along profile, signed distance from profile).
function xy_range() {
  local IFSval=""
  if [[ $2 == "" ]]; then
    IFSval=""
  else
    IFSval="-F${2:0:1}"
  fi
  gawk < $1 ${IFSval} '
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

function line_azimuth_index() {
  gawk < $1 '
      function acos(x)       { return atan2(sqrt(1-x*x), x)   }
      function getpi()       { return atan2(0,-1)             }
      function deg2rad(deg)  { return (getpi() / 180) * deg   }
      function rad2deg(rad)  { return (180 / getpi()) * rad   }
      BEGIN {
        getline
        lon1 = deg2rad($1)
        lat1 = deg2rad($2)
      }
      {
        lon2 = deg2rad($1)
        lat2 = deg2rad($2)
        Bx = cos(lat2)*cos(lon2-lon1);
        By = cos(lat2)*sin(lon2-lon1);
        theta = atan2(sin(lon2-lon1)*cos(lat2), cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(lon2-lon1));
        printf "%d %.3f\n", NR-2, (rad2deg(theta)+360-90)%360;
        lon1=lon2
        lat1=lat2
      }'
}

# and also calculates an along-profile mean that can be used to calculate residual values

# Old Method:
# Clip the raster using a degree-unit buffer around the input line
# Resample the clipped raster to the desired grid spacing
# Convert to x,y,z format and select points within the buffer region
# For each grid point, calculate:
#   The distance along the line of the closest point on the line (dt)
#   The distance of the grid point to that closest point (da)
#   The sign of the da distance (negative=left of profile, positive=to right of profile)

# Set this to 0 if we don't want to do along-strike averaging in this script
smoothflag=1

# New method:
# Generate a clipping polygon ourselves from the path
# smart_swath.sh profile_width[km] along_profile_dist_ave[km] cross_profile_dist_ave[km] xyfile gridfile resampleres[deg]

gmt gmtset GMT_VERBOSE n

if [[ ! $# -eq 6 ]]; then
  echo "Usage: smart_swath_update.sh profile_width(km) dt_smooth(km) da_smooth(km) XYtrackfile Gridfile resampleres(deg)"
  exit 1
fi

WIDTHKM=${1} # profile half-width, in degrees
LINEXYFILE=$(echo "$(cd "$(dirname "${4}")"; pwd)/$(basename "${4}")")
GRIDFILE=$(echo "$(cd "$(dirname "${5}")"; pwd)/$(basename "${5}")")
SAMPRES="${6}"d # Resample grid to this resolution. Give degrees without suffix.

if [[ ! -e $LINEXYFILE ]]; then
  echo "XY file $LINEXYFILE does not exist"
  exit 1
fi

DISTLIM=${2};  # maximum along-profile averaging distance, in kilometers, no suffix
DALIM=${3}     # number in km, no suffix

RECTBUFSCRIPT=$(dirname "$0")"/rectbuffer.sh"

echo "Building buffer: rectbuffer.sh $LINEXYFILE $WIDTHKM"
${RECTBUFSCRIPT} $LINEXYFILE $WIDTHKM

# This section breaks across the antimeridian 180:-180 line.

# # output is track_buffer.txt and trackfile.txt in current directory
# myrange=($(xy_range track_buffer.txt))
#
# buf_min_x=$(echo "${myrange[0]}-${WIDTHKM}/100" | bc -l)
# buf_max_x=$(echo "${myrange[1]}+${WIDTHKM}/100" | bc -l)
# buf_min_z=$(echo "${myrange[2]}-${WIDTHKM}/100" | bc -l)
# buf_max_z=$(echo "${myrange[3]}+${WIDTHKM}/100" | bc -l)

# Do I even need to cut the grid or is this just messing things up?

NEWR=$(gmt gmtinfo -I1m track_buffer.txt)

echo "Cutting grid with gmt grdcut $GRIDFILE -Gcutgrid.nc ${NEWR} -Vn"
# Cut out the relevant grid to avoid very large file manipulations
gmt grdcut $GRIDFILE -Gcutgrid.nc ${NEWR} -Vn

# Sometimes this will produce a grid with longitudes that are quite large so
# fix that here if necessary
# gmt grdedit -L+n cutgrid.nc

echo "Nulling grid and getting XYZ"
# Resample the grid to the desired point spacing
gmt grdsample cutgrid.nc -Gresamplegrid.nc -I${SAMPRES} -R -Vn

# Mask out and nullify any values falling outside our polygon
gmt grdmask track_buffer.txt -Rresamplegrid.nc -NNaN/1/1 -Gmask.nc -Vn
gmt grdmath -Vn resamplegrid.nc mask.nc MUL = grid_masked.nc
gmt grd2xyz -Vn grid_masked.nc | grep -v "NaN" > grid_masked.xyz

# Calculate the incremental length along profile between points
gmt mapproject ${LINEXYFILE} -G+uk+i -Vn | gawk '{print $3}' > line_dist_km.txt

# Create points along the line at the specified spacing
gmt sample1d ${LINEXYFILE} -Af -fg -I${SAMPRES} -Vn > line_trackinterp.txt

# Calculate the azimuth of the line segments
# sed 1d < line_trackinterp.txt > shift1_line_trackinterp.txt
# paste line_trackinterp.txt shift1_line_trackinterp.txt | grep -v "\s>"  > geodin_line_trackinterp.txt

# gawk < geodin_line_trackinterp.txt '
#     function acos(x) { return atan2(sqrt(1-x*x), x) }
#     {
#         lon1 = $1*3.14159265358979/180;
#         lat1 = $2*3.14159265358979/180;
#         lon2 = $3*3.14159265358979/180;
#         lat2 = $4*3.14159265358979/180;
#         Bx = cos(lat2)*cos(lon2-lon1);
#         By = cos(lat2)*sin(lon2-lon1);
#         theta = atan2(sin(lon2-lon1)*cos(lat2), cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(lon2-lon1));
#         printf "%d %.3f\n", NR-1, (theta*180/3.14159265358979+360-90)%360;
#     }' > az_line_trackinterp.txt

line_azimuth_index line_trackinterp.txt > az_line_trackinterp.txt

echo "Calculating distance from track"
# Calculate distance of each point to the nearest point track
gawk < grid_masked.xyz '{print $1, $2}' | gmt mapproject -Lline_trackinterp.txt -fg -Vn > tmp.txt
# Column 3 is the distance from the track
# Columns 4,5 are the lon/lat of the nearest point

echo "Calculating decimal segment ID"
# Calculate the segment ID of the nearest point
gawk < grid_masked.xyz '{print $1, $2}' | gmt mapproject -Lline_trackinterp.txt+p -fg -Vn > tmp2.txt
# Column 5 is the segment fractional point.

# Calculate the distance along the track of each projected point

# We need to sort the points so they are in order, and then unsort the data

paste tmp.txt tmp2.txt | gawk '{print $0, NR}' | tr '\t' ' ' | sort -n -k 10 | gawk '{print $4, $5, $11}' > projptstrack.txt

# Calculate the true distance along track of the closest point on the track
gmt mapproject projptstrack.txt -G+uk | sort -n -k 3 | gawk '{print $1, $2, $4}' > dist_projptstrack.txt
# dist_projptstrack.txt: lon lat distance

lastpt=$(echo "$(wc -l < line_trackinterp.txt) - 1" | bc)

# Calculate the azimuth from each point to its nearest point on the track
paste tmp.txt tmp2.txt dist_projptstrack.txt grid_masked.xyz | tr '\t' ' '  | gawk -v last=$lastpt '
    function acos(x) { return atan2(sqrt(1-x*x), x) }
    {
      if ($10 == 0 || $10 == last) {
#nothing
      }
      else {
        lon1 = $1*3.14159265358979/180;
        lat1 = $2*3.14159265358979/180;
        lon2 = $4*3.14159265358979/180;
        lat2 = $5*3.14159265358979/180;
        Bx = cos(lat2)*cos(lon2-lon1);
        By = cos(lat2)*sin(lon2-lon1);
        theta = atan2(sin(lon2-lon1)*cos(lat2), cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(lon2-lon1));
        printf "%s %s %0.05f %0.05f %s %s %s %d %.3f %s\n", $1, $2, $3/1000.0000, $13, $4, $5, $10, $10, (theta*180/3.14159265358979+360-90)%360, $16;
      }
    }' | sort -k 7 -n > az_pts_to_nearest.txt

# az_pts_to_nearest.txt has 10 fields:
# lon lat dist_from_track(km) Point_number lon_nearest lat_nearest fractional_point fractional_point azimuth z_value


# Prints out values of decimal vertex that are greater than 0 but less than 1 as 0. This is OK for joining with the track
# as it places the points at the first point anyway.

# Exclude points that are closest to the first and last segments (maybe not necessary?)
# Join the segment azimuth to the data using the ID fields from both files.

join -1 8 -2 1 az_pts_to_nearest.txt az_line_trackinterp.txt > data_join.txt

# This produces 11 fields
# lon lat dist_from_track(km) Point_number lon_nearest lat_nearest fractional_point fractional_point azimuth z_value seg_azimuth

echo "Determining handedness"
# Use fields 9 (theta) and 11 (line segment azimuth) to determine if the points are to the left or the right of the profile
gawk < data_join.txt 'BEGIN{minx=0;maxx=0;maxy=0;miny=0}{
  paz=$11
  az=$9
  if (az > 180) {
    if (paz > az || paz <= az-180) {
      side=-1
    }
    else {
      side=1
    }
  } else {  # (az <=180)
    if (paz > az && paz <= az+180) {
      side=-1
    }
    else {
      side=1
    }
  }
  print $2, $3, $4*side, $5, $6, $7, $8, $9, $10, $11
  if ($4*side < miny) {
    miny=$4*side
  }
  if ($4*side > maxy) {
    maxy=$4*side
  }
  if ($5 < minx) {
    minx=$5
  }
  if ($5 > maxx) {
    maxx=$5
  }
} END {
  print miny "/" maxy "/" minx "/" maxx > "./bounds.txt"
 }' > data_lr.txt

damin=$(gawk -F/ < bounds.txt '{print $1}')
damax=$(gawk -F/ < bounds.txt '{print $2}')

# Sort by da
sort data_lr.txt -n -k 3 > data_lr_sort.txt

[[ $smoothflag -eq 0 ]] && exit

INPUTFILE="data_lr_sort.txt"

# This implements an along-strike distance window (DISTLIM) and an across-strike
# Distance window (DALIM), both given in km.

echo "Smoothing along-track ($DISTLIM) and across-track ($DALIM)"

echo "" | gawk -v damin=$damin -v damax=$damax -v dalim=$DALIM -v distlim=$DISTLIM '
function acos(x) { return atan2(sqrt(1-x*x), x) }
BEGIN {
  pi=atan2(0,-1);
  id=1;
  # Read in the data (lon, lat, da, val) and convert to radians for lat/lon
  while (getline < "'"$INPUTFILE"'")
  {
    split($0,ft," ");
    lon[id]=ft[1]*pi/180;
    lat[id]=ft[2]*pi/180;
    da[id]=ft[3];
    val[id]=ft[9];
    ind[id]=id;
    count[id]=0
    sum[id]=0
    mean[id]=0
    id=id+1
  }
  close("'"$INPUTFILE"'");
  # for each entry, determine the maximum and minimum indices of the points that
  # are close enough for consideration in da space. minind[id] maxind[id]
  for (i=1;i<=id-1;i++) {
    # print ind[i];
    curda=da[i];

    # Find the minimum da point to consider
    j=i;
    while (da[j] >= curda-dalim && j > 0) {
      j=j-1;
    }
    # Find the maximum da point to consider
    k=i;
    while (da[k] < curda+dalim && k <= id) {
      k=k+1;
    }
    # print "Point", ind[i], "with da ", curda, " has min index ", j, "with value ", da[j], "and max index ", k, "with value ", da[k]
    for (cind=j; cind<=k; cind++) {
      if (cind == i) {
        sum[i]=sum[i]+val[cind];
        count[i]=count[i]+1;
      } else {
        d = acos(sin(lat[i])*sin(lat[cind]) + cos(lat[i])*cos(lat[cind])*cos(lon[cind]-lon[i]) ) * 6371;
        # print "d is ", d
        if (d <= distlim) {
          sum[i]=sum[i]+val[cind];
          # printf "%s,", sum[i]
          count[i]=count[i]+1;
        }
      }
    }
    if (count[i] != 0) {
      print lon[i]*180/pi, lat[i]*180/pi, sum[i]/count[i]
    } else {
      print lon[i]*180/pi, lat[i]*180/pi, -99999;
    }
  }
}' > data_mean_newest.txt

echo "Building mean raster from smoothed data"
gmt xyz2grd -Rgrid_masked.nc data_mean_newest.txt -Ggrid_smoothed.nc -Vn

gmt grdsample grid_smoothed.nc -fg -Rcutgrid.nc -Ggridwindowed_resample.nc -Vn
gmt grdsample cutgrid.nc -fg -Rgridwindowed_resample.nc -Gcutgrid_resample.nc -Vn

echo "Calculating residual raster"
gmt grdmath -Vn cutgrid_resample.nc gridwindowed_resample.nc SUB = grid_residual.nc
# #
# rm -f cutgrid_resample.nc gridwindowed_resample.nc data_mean_newest.txt
# rm -f grid_masked.nc az_pts_to_nearest.txt line_dist_km.txt dist_projptstrack.txt
# rm -f bounds.txt rotbounds.txt data_lr.txt data_join.txt tmp.txt tmp2.txt
# rm -f  az_trackfile.txt line_trackinterp.txt mask.nc
# rm -f projptstrack.txt rectbuf_back.txt resamplegrid.nc shift1_line_trackinterp.txt
# rm -f  data_lr_sort.txt grid_masked.xyz geodin_line_trackinterp.txt az_line_trackinterp.txt
