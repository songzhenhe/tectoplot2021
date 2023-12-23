#!/bin/bash

# tectoplot
# bashscripts/gk.sh
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

# gk.sh [catalogfile] [method]

# Use a spatial-temporal window (e.g. Gardner-Knopoff) method to decluster a
# seismicity catalog.

# This implementation is based on the algorithm of R. Musson (1999) and is
# basically a refactoring of the declustering algorithm by G. Weatherill,
# M. Pagani, and D. Monelli distributed with the Hazard Modeler's Toolkit

# An additional feature of this code is the ability to ignore small clusters
# (e.g. N<=3). This isn't really valid from a 'catalog' perspective, but it is
# useful if you just want to identify which mainshocks have a significant number
# of foreshocks/aftershocks.

# Input is a tectoplot earthquake catalog.
# Input format: lon lat depth mag iso8601_date ID [[epoch]] ...

# Output is two catalog files with trailing field indicating cluster ID.
# Cluster 1 is non-clustered (independent) events.
# catalog_declustered.txt: independent events and mainshocks
# catalog_clustered.txt  : clustered events

# We sort by decreasing magnitude so that larger earthquakes will be identified
# as mainshocks first. We search for foreshocks within a certain fraction of the
# aftershock window.

# Remove non-mainshock events from catalog?
DECLUSTER_METHOD_L=$2
DECLUSTER_MINSIZE=$3

# Sort by magnitude upon input, then pipe to gawk for declustering.

sort -r -k 4 $1 | gawk -v method=${DECLUSTER_METHOD_L} -v min_cluster_size=${DECLUSTER_MINSIZE} '
@include "tectoplot_functions.awk"


function time_window_days(method, mag) {
  if (method == "gk") {
    # Gardner and Knopoff, 1974
    return (mag > 6.5)? 10.0^(0.032 * mag + 2.7389) : 10.0^(0.5409 * mag - 0.547)
  } else if (method == "gruenthal") {
    return (mag > 6.5)? 10.0^(0.024 * mag + 2.8) : abs(exp(sqrt(17.32*mag+0.62)-3.95))
  } else if (method == "urhammer") {
    return abs(exp(sqrt(1.235*mag+0.62)-2.87))
  }
}

function dist_window_km(method, mag) {
  if (method == "gk") {
    return 10.0^(0.1238 * mag + 0.983)
  } else if (method == "gruenthal") {
    return exp(sqrt(1.02*mag+0.037)+1.77)
  } else if (method == "urhammer") {
    return exp(0.804*mag-1.024);
  }
}

BEGIN {
  lookback_fraction=0.5   # Fraction of aftershock window to consider foreshocks
}
{
  eventdata[NR]=$0
  lonr[NR]=deg2rad($1)
  latr[NR]=deg2rad($2)
  depth[NR]=$3
  mag[NR]=$4
  time_window[NR]=time_window_days(method, $4)
  distance_window[NR]=dist_window_km(method, $4)
  epoch[NR]=iso8601_to_epoch($5)
  id[NR]=NR
}
END {

  # Start with cluster ID of 2 so that independent EQs can go to cluster 1

  cluster_index=2

  # NR is the number of earthquakes we loaded
  for (i=1; i<=NR; ++i)
  {
    if (cluster_id[i]==0)
    {  # This event is not yet in a cluster, so it is a mainshock.
      # How many dependent events have we assigned to this mainshock?
      assigned[i]=0
      for (j=1; j<=NR; ++j)
      {
        if (cluster_id[j]==0)
        {
          # Potentially comparable event is also not yet in a cluster
          dt = (epoch[j]-epoch[i])/68400;    # Calculate days between events
          if ((dt <= time_window[i]) && (dt >= -time_window[i] * lookback_fraction))
          {
            # Event falls within time window
            # Caclulate approximate distance across Earth surface, in km
            d=2*6378.1*asin(sqrt(sinsq((latr[j]-latr[i])/2)+cos(latr[i])*cos(latr[j])*(sinsq((lonr[j]-lonr[i])/2))))
            if (d < distance_window[i])
            { # Found an event that qualifies, assign it to the current cluster
              cluster_id[j]=cluster_index
              assigned[i]++
            }
          }
        }
      }
      if (assigned[i]>1) {  # assigned should always be >= 1 because each EQ sees itself
        cluster_id[i]=cluster_index;
        cluster_index=cluster_index+1;
      } else {
        cluster_id[i]=1   # This earthquake is independent, so assign it to cluster 1
      }
    }
  }

  # At this point, we could refine the clustering by relabeling clusters with a
  # small number of events to be independent events. This would significantly
  # reduce the number of clusters

  # Because the data are sorted by magnitude, the largest event (mainshock) is
  # the first element with each cluster_index value.

  # Count the number of events associated with each cluster ID
  for (i=1; i<= NR; i++) {
    seen[cluster_id[i]]++
  }

  # Make a list of cluster ID codes to set to 1
  for (key in seen) {
    if (seen[key] < min_cluster_size) {
      set_to_1[key]=1
    }
  }

  # For each earthquake
  for (i=1; i<= NR; i++) {

    seenagain[cluster_id[i]]++
    # Check if it is in the set_to_1 class
    # If so, set cluster_id to 1
    for (newkey in set_to_1) {
      if (cluster_id[i] == newkey) {
        cluster_id[i]=1
      }
    }

    # Output to one of two files
    # If it is an independent event OR the first event with a specific ID
    if (cluster_id[i] == 1 || seenagain[cluster_id[i]] == 1) {  # Declustered data (ind. + mainshocks)
      print eventdata[i], cluster_id[i] > "./catalog_declustered.txt"
    } else {
      print eventdata[i], cluster_id[i] > "./catalog_clustered.txt"
    }
  }

}'
