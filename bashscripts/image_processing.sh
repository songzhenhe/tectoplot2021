# tectoplot
# bashscripts/image_processing.sh
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

### Image processing functions, mostly using gdal_calc.py
### This functions file is sourced by tectoplot

function multiply_combine() {
  if [[ ! -e "${2}" ]]; then
    info_msg "Multiply combine: Raster $2 doesn't exist. Copying $1 to $3."
    cp "${1}" "${3}"
  else
    info_msg "Executing multiply combine of $1 and $2 (1st can be multi-band) . Result=$3."
    gdal_calc.py --overwrite --quiet -A "${1}" -B "${2}" --allBands=A --calc="uint8( ( \
                   (A/255.)*(B/255.)
                   ) * 255 )" --outfile="${3}"
  fi
}

function alpha_value() {
  info_msg "Executing alpha transparency of $1 by factor $2 [0-1]. Result=$3."
  gdal_calc.py –-NoDataValue=none --overwrite --quiet -A "${1}" --allBands=A --calc="uint8( ( \
                 ((A/255.)*(1-${2})+(255/255.)*(${2}))
                 ) * 255 )" --outfile="${3}"
  gdal_edit.py -unsetnodata "${3}"
}

# function alpha_multiply_combine() {
#   info_msg "Executing alpha $2 on $1 then multiplying with $3 (1st can be multi-band) . Result=$3."
#
# }

function lighten_combine() {
  info_msg "Executing lighten combine of $1 and $2 (1st can be multi-band) . Result=$3."
  gdal_calc.py --overwrite --quiet -A "${1}" -B "${2}" --allBands=A --calc="uint8( ( \
                 (A>=B)*A/255. + (A<B)*B/255.
                 ) * 255 )" --outfile="${3}"
}

function lighten_combine_alpha() {
  info_msg "Executing lighten combine of $1 and $2 (1st can be multi-band)at alpha=$3 . Result=$4."
  gdal_calc.py --overwrite --quiet -A "${1}" -B "${2}" --allBands=B --calc="uint8( ( \
                 (A>=B)*(B/255. + (A/255.-B/255.)*${3}) + (A<B)*B/255.
                 ) * 255 )" --outfile="${4}"
}

function darken_combine_alpha() {
  info_msg "Executing lighten combine of $1 and $2 (1st can be multi-band) . Result=$3."
  gdal_calc.py --overwrite --quiet -A "${1}" -B "${2}" --allBands=A --calc="uint8( ( \
                 (A<=B)*A/255. + (A>B)*B/255.
                 ) * 255 )" --outfile="${3}"
}

function weighted_average_combine() {
  if [[ ! -e $2 ]]; then
    info_msg "Weighted average combine: Raster $2 doesn't exist. Copying $1 to $4."
    cp "${1}" "${4}"
  else
    info_msg "Executing weighted average combine of $1(x$3) and $2(x1-$3) (1st can be multi-band) . Result=$4."
    gdal_calc.py --overwrite --quiet -A "${1}" -B "${2}" --allBands=A --calc="uint8( ( \
                   ((A/255.)*(${3})+(B/255.)*(1-${3}))
                   ) * 255 )" --outfile="${4}"
  fi
}

function rgb_to_grayscale() {
  gdal_calc.py  --overwrite --quiet -A "${1}" --A_band=1 -B "${1}" --B_band=2 -C "${1}" \
              --C_band=3 --outfile="${2}" --calc="A*0.2989+B*0.5870+C*0.1140"
}

# Create an alpha mask where all near-black colors (lighter than $3 and A~B~C)
# are set to white, all others are black

function rgb_to_alpha() {
  gdal_calc.py  --overwrite --quiet -A "${1}" --A_band=1 -B "${1}" --B_band=2 -C "${1}" \
  --C_band=3 --outfile="${2}" --calc="uint8( ((A-B<10)*(A-C<10)*(A*0.2989+B*0.5870+C*0.1140)<${3}) * 255.)"
}

# Create an alpha mask from a PNG alpha channel (Band 4)

function png_to_alpha() {
  gdal_calc.py  --overwrite --quiet -A "${1}" --A_band=4 --outfile="${2}" \
  --calc="uint8((A>0)*255.)"
}

# Prints (space separated): raster maximum, mean, minimum, standard deviation
function gdal_stats() {
  gdalinfo -stats "${1}" | grep "Minimum=" | awk -F, '{print $1; print $2; print $3; print $4}' | awk -F= '{print $2}'
}

# Apply a gamma stretch to an 8 bit image
function gamma_stretch() {
  info_msg "Executing gamma stretch of ($1^(1/(gamma=$2))). Output file is $3"
  gdal_calc.py --overwrite --quiet -A "${1}" --allBands=A --calc="uint8( ( \
          (A/255.)**(1/${2})
          ) * 255 )" --outfile="${3}"
}

# Linearly rescale an image $1 from ($2, $3) to ($4, $5) output to $6
function histogram_rescale() {
  gdal_translate -q "${1}" "${6}" -scale "${2}" "${3}" "${4}" "${5}"
}


# Rescale image $1 to remove values below $2% and above $3%, output to $4
function histogram_percentcut_byte() {
  # gdalinfo -hist produces a 256 bucket equally spaced histogram
  # Every integer after the first blank line following the word "buckets" is a histogram value

  cutrange=($(gdalinfo -hist "${1}" | tr ' ' '\n' | awk -v mincut="${2}" -v maxcut="${3}" '
    BEGIN {
      outa=0
      outb=0
      ind=0
      sum=0
      cum=0
    }
    {
      if($1=="buckets") {
        outa=1
        getline # from
        getline # minimum
        minval=$1+0
        getline # to
        getline # maximum:
        maxval=$1+0
      }
      if (outb==1 && $1=="NoData") {
        exit
      }
      if($1=="" && outa==1) {
        outb=1
      }
      if (outb==1 && $1==int($1)) {
        vals[ind]=$1
        cum=cum+$1
        cums[ind++]=cum*100
        sum+=$1
      }
    }
    # Now calculate the percentiles
    END {
      print minval
      print maxval
      for (key in vals) {
        range[key]=(maxval-minval)/255*key+minval
      }
      foundmin=0
      for (key in cums) {
        if (cums[key]/sum >= mincut && foundmin==0) {
          print range[key]
          foundmin=1
        }
        if (cums[key]/sum >= maxcut) {
          print range[key]
          exit
        }
        # print key, cums[key]/sum, range[key]
      }
    }'))
    gdal_translate -q "${1}" "${4}" -scale "${cutrange[2]}" "${cutrange[3]}" 1 254 -ot Byte
    gdal_edit.py -unsetnodata "${4}"
}

# If raster $2 has value $3, outval=$4, else outval=raster $1, put into $5
function image_setval() {
  gdal_calc.py --type=Byte --overwrite --quiet -A "${1}" -B "${2}" --calc="uint8(( (B==${3})*$4.+(B!=${3})*A))" --outfile="${5}"
}

# Linearly rescale an image $1 from ($2, $3) to ($4, $5), stretch by $6>0, output to $7
function histogram_rescale_stretch() {
  gdal_translate -q "${1}" "${7}" -scale "${2}" "${3}" "${4}" "${5}" -exponent "${6}"
}

# Select cells from $1 within a [$2 $3] value range; else set to $4. Output to $5
function histogram_select() {
   gdal_calc.py --overwrite --quiet -A "${1}" --allBands=A --calc="uint8(( \
           (A>=${2})*(A<=${3})*(A-$4) + $4
           ))" --outfile="${5}"
}

# Select cells from $1 within a [$2 $3] value range; set to $4 if so, else set to $5. Output to $6
function histogram_select_set() {
   gdal_calc.py --overwrite --quiet -A "${1}" --allBands=A --calc="uint8(( \
           (A>=${2})*(A<=${3})*(${4}-${5}) + $5
           ))" --outfile="${6}"
}

function overlay_combine() {
  info_msg "Overlay combining $1 and $2. Output is $3"
  gdal_calc.py --overwrite --quiet -A "${1}" -B "${2}" --allBands=A --calc="uint8( ( \
          (2 * (A/255.)*(B/255.)*(A<128) + \
          (1 - 2 * (1-(A/255.))*(1-(B/255.)) ) * (A>=128))/2 \
          ) * 255 )" --outfile="${3}"
}

function flatten_sea() {
  info_msg "Setting DEM elevations less than 0 to 0"
  gdal_calc.py --overwrite --type=Float32 --format=NetCDF --quiet -A "${1}" --calc="((A>=0)*A + (A<0)*0)" --outfile="${2}"
}

# Takes a RGB tiff ${1} and a DEM ${2} and sets R=${3} G=${4} B=${5} for cells where DEM<=0, output to ${6}

function recolor_sea() {

  gdal_calc.py --overwrite --quiet -A "${1}" -B "${2}" --B_band=1 --calc  "uint8(254*((A>0)*B/255. + (A<=0)*${3}/255.))" --type=Byte --outfile=outA.tif
  gdal_calc.py --overwrite --quiet -A "${1}" -B "${2}" --B_band=2 --calc  "uint8(254*((A>0)*B/255. + (A<=0)*${4}/255.))" --type=Byte --outfile=outB.tif
  gdal_calc.py --overwrite --quiet -A "${1}" -B "${2}" --B_band=3 --calc  "uint8(254*((A>0)*B/255. + (A<=0)*${5}/255.))" --type=Byte --outfile=outC.tif

  # merge the out files
  rm -f "${6}"
  gdal_merge.py -q -co "PHOTOMETRIC=RGB" -separate -o "${6}" outA.tif outB.tif outC.tif
}

# This function reformats an input CPT file to be in r/g/b (or h/s/v) format,
# replacing GMT color names (e.g. seashell4) with r/g/b colors. Comments, BFN,
# and trailing annotation fields are also printed.

function replace_gmt_colornames_rgb() {
  gawk '
  BEGIN {
    firstline=0
  }
  {
    if(NR == FNR){
      colors[$1] = $2
    } else {
      if (substr($0,0,1)!="#") {
        firstline++
        if (firstline==1) {
          if (NF==4 || NF==5) {
            format="a/b/c"
          } else if (NF==8 || NF==9) {
            format="a b c"
          } else {
            format="none"
          }
        }

        if (format=="none") {
          print
        } else if (format=="a/b/c") {

          if ($2 in colors) {
            $2=colors[$2]
          }
          if (NF==2) {  # B colorname or B 3/4/5
            print $1 "\t" $2
          } else {
            num1=split($2, c1, "/")
            if (num1 != 3) {
              print("CPT format inconsistent - expecting Z1 A/B/C Z2 A/B/C [N]") > "/dev/stderr"
              exit
            }
            if ($4 in colors) {
              $4=colors[$4]
            } else {
              num2=split($4, c2, "/")
              if (num2 != 3) {
                print("CPT format inconsistent - expecting Z1 A/B/C Z2 A/B/C [N]") > "/dev/stderr"
                exit
              }
            }
            print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5
          }
        } else {
          if (NF==2) {
            if ($2 in colors) {
              $2=colors[$2]
            }
          }
          print $1, $2 "/" $3 "/" $4, $5, $6 "/" $7 "/" $8, $9
        }
      } else {
        print
      }
    }
  }' ${GMTCOLORS} "$1"
}

function gmt_colorname_to_rgb() {
  grep ^"${1} " $GMTCOLORS | head -n 1 | gawk '{print $2}'
}

# This function takes a GMT CPT file in R/G/B format and prints a gdal color
# interval file, respecting the input hinge value. Comments and BFN are removed.

function cpt_to_gdalcolor () {
  if [[ "$2" == "" ]]; then
    gawk < "$1" '{
      if ($1 != "B" && $1 != "F" && $1 != "N" && substr($0,0,1) != "#") {
        print $1, $2
      }
    }' | tr '/' ' ' | gawk '{
      if ($2==255) {$2=254.9}
      if ($3==255) {$3=254.9}
      if ($4==255) {$4=254.9}
      print
    }'
  else
    gawk < "$1" -v hinge="${2}" '{
      if ($1 != "B" && $1 != "F" && $1 != "N" && substr($0,0,1) != "#") {
        if (count==1) {
          print $1+0.01, $2
          count=2
        } else {
          print $1, $2
        }
        if ($3 == hinge) {
          if (count==0) {
            print $3-0.0001, $4
            count=1
          }
        }
      }
    }' | tr '/' ' ' | gawk '{
      if ($2==255) {$2=254.9}
      if ($3==255) {$3=254.9}
      if ($4==255) {$4=254.9}
      print
    }'
  fi
}

# This function takes a clean RGB CPT and scales the z values by the input factor
# Comments, annotation letters, and BFN are preserved.

function scale_cpt() {
  gawk < "${1}" -v scale="${2}" '
  BEGIN {
    firstline=0
  }
  {
    if (substr($0,0,1)!="#") {
      if (NF >2) {
        $1=$1*scale
        $3=$3*scale
        print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5
      } else {
        print
      }
    } else {
      print
    }
  }'
}
