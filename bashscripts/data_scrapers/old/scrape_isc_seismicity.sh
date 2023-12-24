#!/bin/bash

# tectoplot
# bashscripts/scrape_isc_seismicity.sh
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

# Download the entire global ISC seismicity
# catalog and store in weekly data files, then process into 5 degree tiles.

# Most of the download time is the pull request, but making larger chunks leads
# to some failures due to number of events. The script can be run multiple times
# and will not re-download files that already exist. Some error checking is done
# to look for empty files and delete them.

# Example curl command:
## curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${year}&start_month=${month}&start_day=01&start_time=00%3A00%3A00&end_year=${year}&end_month=${month}&end_day=7&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > isc_seis_2019_01_week1.dat
# curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${year}&start_month=${month}&start_day=01&start_time=00%3A00%3A00&end_year=${year}&end_month=${month}&end_day=31&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > isc_seis_${year}_${month}.dat

# Strategy: Download from 1900-1950 as single file
#           Download from 1950-1980 as yearly files
#           Download from 1981-present as weekly files

# tac not available in all environments but tail usually is

function tac() {
  tail -r -- "$@";
}

function epoch_ymdhms() {
  echo "$1 $2 $3 $4 $5 $6" | gawk '{
    the_time=sprintf("%i %i %i %i %i %i",$1,$2,$3,$4,$5,$6);
    print mktime(the_time);
  }'
}

function lastday_of_month() {
  month=$(printf "%02d" $1)
  case $month in
      0[13578]|10|12) days=31;;
      0[469]|11)	    days=30;;
      02) days=$(echo $year | gawk '{
          jul=strftime("%j",mktime($1 " 12 31 0 0 0 "));
          if (jul==366) {
            print 29
          } else {
            print 28
          }
         }')
  esac
  echo $days
}

function download_and_check() {
  local s_year=$1
  local s_month=$2
  local s_day=$3
  local e_year=$4
  local e_month=$5
  local e_day=$6

  start_epoch=$(epoch_ymdhms $s_year $s_month $s_day 0 0 0)
  end_epoch=$(epoch_ymdhms $e_year $e_month $e_day 23 59 59)

  # Test whether the file is entirely within the future. If so, don't download.
  if [[ $start_epoch -ge $today_epoch ]]; then
    echo "Requested range is beyond current date. Not downloading anything."
  else
    local OUTFILE=$(printf "isc_seis_%04d%02d%02d_%04d%02d%02d.dat" $s_year $s_month $s_day $e_year $e_month $e_day)
    # echo outfile is $OUTFILE
    if [[ $start_epoch -le $today_epoch && $end_epoch -gt $today_epoch ]]; then
      echo "Requested file spans today and needs to be redownloaded."
      rm -f $OUTFILE
    fi

    # Test whether the file time spans the current date. If so, delete it so we can redownload.

    # if [[ $s_year -le $this_year && $s_month -ge $this_month && $s_day -gt $this_day ]]; then
    #   if [[ $s_year -ge $this_year && $s_month -ge $this_month && $s_day -gt $this_day ]]; then
    #     echo "Requested range is beyond current date. Not downloading anything."
    #   echo "Requested range is beyond current date. Not downloading anything."

    # Check if this is a valid ISC_SEIS file by looking for the terminating STOP command
    if [[ -e "$OUTFILE" ]]; then
        # echo "Requested file $OUTFILE already exists"
        local iscomplete=$(tail -n 10 "${OUTFILE}" | grep STOP | wc -l)  # == 1 is complete, == 0 is not
        if [[ $iscomplete -eq 0 ]]; then
          echo "${OUTFILE} is not a complete/valid ISC SEIS file. Deleting"
          rm -f "${OUTFILE}"
        fi
    fi
    if [[ ! -e "$OUTFILE" ]]; then
      echo "Dowloading seismicity from ${s_year}-${s_month}-${s_day} to ${e_year}-${e_month}-${e_day}"
      curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${s_year}&start_month=${s_month}&start_day=${s_day}&start_time=00%3A00%3A00&end_year=${e_year}&end_month=${e_month}&end_day=${e_day}&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > $OUTFILE
      local iscomplete=$(tail -n 10 "${OUTFILE}" | grep STOP | wc -l)  # == 1 is complete, == 0 is not
      if [[ $iscomplete -eq 0 ]]; then
        echo "Newly downloaded ${OUTFILE} is not a complete/valid ISC SEIS file. Deleting"
        rm -f "${OUTFILE}"
      else
        echo ${OUTFILE} >> to_add_to_cat.txt
        add_to_catalog+=("$OUTFILE")
      fi
    fi
  fi
}

function iso8601_to_epoch() {
  TZ=UTC

  gawk '{
    # printf("%s ", $0)
    for(i=1; i<=NF; i++) {
      done=0
      timecode=substr($(i), 1, 19)
      split(timecode, a, "-")
      year=a[1]
      if (year < 1900) {
        print -2209013725
        done=1
      }
      month=a[2]
      split(a[3],b,"T")
      day=b[1]
      split(b[2],c,":")

      hour=c[1]
      minute=c[2]
      second=c[3]

      if (year == 1982 && month == 01 && day == 01) {
        printf("%s ", 378691200 + second + 60*minute * 60*60*hour)
        done=1
      }
      if (year == 1941 && month == 09 && day == 01) {
        printf("%s ", -895153699 + second + 60*minute * 60*60*hour)
        done=1

      }
      if (year == 1941 && month == 09 && day == 01) {
        printf("%s ", -879638400 + second + 60*minute * 60*60*hour)
        done=1
      }

      if (done==0) {
        the_time=sprintf("%04i %02i %02i %02i %02i %02i",year,month,day,hour,minute,int(second+0.5));
        # print the_time > "/dev/stderr"
        epoch=mktime(the_time);
        printf("%s ", epoch)
      }
    }
    printf("\n")
  }'
}

function has_a_line() {
  if [[ -e $1 ]]; then
    gawk '
    BEGIN {
      x=0
    }
    {
      if(NR>2) {
        x=1;
        exit
      }
    }
    END {
      if(x>0) {
        print 1
      } else {
        print 0
      }
    }' < $1
  else
    echo 0
  fi
}

function download_isc_file() {
  local parsed=($(echo $1 | gawk -F_ '{ split($5, d, "."); print $3, $4, d[1]}'))
  local year=${parsed[0]}
  local month=${parsed[1]}
  local segment=${parsed[2]}

  if [[ $1 =~ "isc_events_1900_to_1950.cat" ]]; then
    echo "Downloading seismicity for $1: Year=1900 to 1950"
    curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=1900&start_month=01&start_day=01&start_time=00%3A00%3A00&end_year=1950&end_month=12&end_day=31&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > $1
  else
    echo "Downloading seismicity for $1: Year=${year} Month=${month} Segment=${segment}"

    case ${parsed[2]} in
      1)
      curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${year}&start_month=${month}&start_day=01&start_time=00%3A00%3A00&end_year=${year}&end_month=${month}&end_day=07&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > $1
      ;;
      2)
      curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${year}&start_month=${month}&start_day=08&start_time=00%3A00%3A00&end_year=${year}&end_month=${month}&end_day=14&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > $1
      ;;
      3)
      curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${year}&start_month=${month}&start_day=15&start_time=00%3A00%3A00&end_year=${year}&end_month=${month}&end_day=21&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > $1
      ;;
      4)
      last_day=$(lastday_of_month $month)
      curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${year}&start_month=${month}&start_day=22&start_time=00%3A00%3A00&end_year=${year}&end_month=${month}&end_day=${last_day}&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > $1
      ;;
    esac
  fi
  # If curl returned a non-zero exit code or doesn't contain at least two lines, delete the file we just created
  if ! [ 0 -eq $? ]; then
    echo "File $1 had download error. Deleting."
    rm -f $1
  elif [[ $(has_a_line $1) -eq 0 ]]; then
    echo "File $1 was empty. Deleting."
    rm -f $1
  fi
}

# Change into the ISC data directory, creating if needed, and check Tiles directory
# Create tile files using touch

ISCDIR="${1}"

[[ ! -d $ISCDIR ]] && mkdir -p $ISCDIR

cd $ISCDIR

# Sort the anss_complete.txt file to preserve the order of earliest->latest
if [[ -e isc_complete.txt ]]; then
  sort < isc_complete.txt -t '_' -n -k 3 -k 4 -k 5 > isc_complete.txt.sort
  mv isc_complete.txt.sort isc_complete.txt
fi

ISCTILEDIR="Tiles/"

if [[ -d $ISCTILEDIR ]]; then
  echo "ISC tile directory exists."
else
  echo "Creating tile files in ISC tile directory :${ISCTILEDIR}:."

  mkdir -p ${ISCTILEDIR}
  for long in $(seq -180 5 175); do
    for lati in $(seq -90 5 85); do
      touch ${ISCTILEDIR}"tile_${long}_${lati}.cat"
    done
  done
fi

if ! [[ $2 =~ "rebuild" ]]; then

  rm -f isc_just_downloaded.txt

  if [[ -e isc_last_downloaded_event.txt ]]; then
    lastevent_epoch=$(tail -n 1 isc_last_downloaded_event.txt | gawk -F, '{ printf("%sT%s", $3, substr($4, 1, 8)) }' | iso8601_to_epoch)
  else
    lastevent_epoch=$(echo "1900-01-01T00:00:01" | iso8601_to_epoch)
  fi
  echo "Last event from previous scrape has epoch $lastevent_epoch"

  this_year=$(date -u +"%Y")
  this_month=$(date -u +"%m")
  this_day=$(date -u +"%d")
  this_hour=$(date -u +"%H")
  this_minute=$(date -u +"%M")
  this_second=$(date -u +"%S")

  today_epoch=$(epoch_ymdhms $this_year $this_month $this_day $this_hour $this_minute $this_second)


  # new format for isc is isc_events_year_month_segment.cat

  # Look for the last entry in the list of catalog files
  final_cat=($(tail -n 1 ./isc_list.txt 2>/dev/null | gawk -F_ '{split($5, a, "."); print $3, $4, a[1]}'))

  # If there is no last entry (no file), regenerate the list
  if [[ -z ${final_cat[0]} ]]; then
    echo "Generating new catalog file list..."
    echo "isc_events_1900_to_1950.cat" > ./isc_list.txt
    for year in $(seq 1951 $this_year); do
      for month in $(seq 1 12); do
        if [[ $(echo "($year == $this_year) && ($month > $this_month)" | bc) -eq 1 ]]; then
          break 1
        fi
        for segment in $(seq 1 4); do
          if [[ $(echo "($year == $this_year) && ($month == $this_month)" | bc) -eq 1 ]]; then
            [[ $(echo "($segment == 2) && ($this_day < 7)"  | bc) -eq 1 ]] && break
            [[ $(echo "($segment == 2) && ($this_day < 14)"  | bc) -eq 1 ]] && break
            [[ $(echo "($segment == 3) && ($this_day < 21)"  | bc) -eq 1 ]] && break
          fi
          echo "isc_events_${year}_${month}_${segment}.cat" >> ./isc_list.txt
        done
      done
    done
  else
  # Otherwise, add the events that postdate the last catalog file.
    echo "Adding new catalog files to file list..."
    final_year=${final_cat[0]}
    final_month=${final_cat[1]}
    final_segment=${final_cat[2]}

    for year in $(seq $final_year $this_year); do
      for month in $(seq 1 12); do
        if [[  $(echo "($year == $this_year) && ($month > $this_month)" | bc) -eq 1 ]]; then
          break 1
        fi
        for segment in $(seq 1 4); do
          # Determine when to exit the loop as we have gone into the future
          if [[ $(echo "($year >= $this_year) && ($month >= $this_month)" | bc) -eq 1 ]]; then
             [[ $(echo "($segment == 2) && ($this_day < 7)"  | bc) -eq 1 ]] && break
             [[ $(echo "($segment == 3) && ($this_day < 14)"  | bc) -eq 1 ]] && break
             [[ $(echo "($segment == 4) && ($this_day < 21)"  | bc) -eq 1 ]] && break
          fi
          # Determine whether to suppress printing of the catalog ID as it already exists
          if ! [[ $(echo "($year <= $final_year) && ($month < $final_month)" | bc) -eq 1 ]]; then
            if [[ $(echo "($year == $final_year) && ($month == $final_month) && ($segment <= $final_segment)" | bc) -eq 0 ]]; then
              echo "isc_events_${year}_${month}_${segment}.cat" >> ./isc_list.txt
            fi
          fi
        done
      done
    done
  fi

  # Get a list of files that should exist but are not marked as complete
  cat isc_complete.txt isc_list.txt | sort -r -n -t "_" -k 3 -k 4 -k 5 | uniq -u > isc_incomplete.txt

  isc_list_files=($(tail -r isc_incomplete.txt))

  # echo ${isc_list_files[@]}

  testcount=0
  last_index=-1
  for d_file in ${isc_list_files[@]}; do
    download_isc_file ${d_file}
    if [[ ! -e ${d_file} || $(has_a_line ${d_file}) -eq 0 ]]; then
      echo "File ${d_file} was not downloaded or has no events. Not marking as complete"
    else
      echo ${d_file} >> isc_just_downloaded.txt
      if [[ $last_index -ge 0 ]]; then
        # Need to check whether the last file exists still before marking as complete (could have been deleted)
        echo "File ${d_file} had events... marking earlier file ${isc_list_files[$last_index]} as complete."
        [[ -e ${isc_list_files[$last_index]} ]] && echo ${isc_list_files[$last_index]} >> isc_complete.txt
      fi
    fi
    last_index=$(echo "$last_index + 1" | bc)
    testcount=$(echo "$testcount + 1" | bc)
  done
else
  # Rebuild the tile from the downloaded
  echo "Rebuilding tiles from complete files"
  rm -f ${ISCTILEDIR}tile*.cat
  cp isc_complete.txt isc_just_downloaded.txt
  lastevent_epoch=$(echo "1900-01-01T00:00:01" | iso8601_to_epoch)

  for long in $(seq -180 5 175); do
    for lati in $(seq -90 5 85); do
      touch ${ISCTILEDIR}"tile_${long}_${lati}.cat"
    done
  done
fi

# If we downloaded a file (should always happen as newest file is never marked complete)

#   EVENTID,AUTHOR   ,DATE      ,TIME       ,LAT     ,LON      ,DEPTH,DEPFIX,AUTHOR   ,TYPE  ,MAG

if [[ -e isc_just_downloaded.txt ]]; then

  selected_files=$(cat isc_just_downloaded.txt)
  rm -f ./not_tiled.cat

  # For each candidate file, examine events and see if they are younger than the
  # last event that has been added to a tile file. Keep track of the youngest
  # event added to tiles and record that for future scrapes.

  for isc_file in $selected_files; do
    echo "Processing file $isc_file into tile files"
    cat $isc_file | sed -n '/^  EVENTID/,/^STOP/p' | sed '1d;$d' | sed '$d' | gawk -F, -v tiledir=${ISCTILEDIR} -v minepoch=$lastevent_epoch '
    @include "tectoplot_functions.awk"
    BEGIN { added=0 }
    {
      timecode=sprintf("%sT%s", $3, substr($4, 1, 8))
      split(timecode, a, "-")
      year=a[1]
      if (year < 1900) {
        print -2209013725
        done=1
      }
      month=a[2]
      split(a[3],b,"T")
      day=b[1]
      split(b[2],c,":")

      hour=c[1]
      minute=c[2]
      second=c[3]

      if (year == 1982 && month == 01 && day == 01) {
        epoch=378691200 + second + 60*minute * 60*60*hour
        done=1
      }
      if (year == 1941 && month == 09 && day == 01) {
        epoch=-895153699 + second + 60*minute * 60*60*hour
        done=1

      }
      if (year == 1941 && month == 09 && day == 01) {
        epoch=-879638400 + second + 60*minute * 60*60*hour
        done=1
      }
      if (done==0) {
        the_time=sprintf("%04i %02i %02i %02i %02i %02i",year,month,day,hour,minute,int(second+0.5));
        epoch=mktime(the_time);
      }

      if (epoch > minepoch) {
        tilestr=sprintf("%stile_%d_%d.cat", tiledir, rd($6,5), rd($5,5));
        print $0 >> tilestr
        added++
      } else {
        print $0 >> "./not_tiled.cat"
      }
    }
    END {
      print "Added", added, "events to ISC tiles."
    }'
  done

  # not_tiled.cat is a file containing old events that have alread been tiled
  # It is kept for inspection purposes but is deleted with each scrape

  last_downloaded_file=$(tail -n 1 isc_just_downloaded.txt)
  last_downloaded_event=$(cat $last_downloaded_file | sed -n '/^  EVENTID/,/^STOP/p' | sed '1d;$d' | sed '$d' | tail -n 1)

  # Check whether the event has the correct format
  if [[ ! -z ${last_downloaded_event} ]]; then
    echo "Marking last downloaded event: $last_downloaded_event"
    echo $last_downloaded_event > isc_last_downloaded_event.txt
    # Update last_downloaded_event.txt
  fi

fi
