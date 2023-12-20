# tectoplot
# bashscripts/seismicity.sh
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

## Functions to manage seismicity data

# This function takes a Mw magnitude (e.g. 6.2) and prints the mantissa and
# exponent of the moment magnitude, scaled by a nonlinear stretch factor.

function stretched_m0_from_mw () {
  echo $1 | gawk  -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{
            mwmod = ($1^str)/(sref^(str-1))
            a=sprintf("%E", 10^((mwmod + 10.7)*3/2))
            split(a,b,"+")
            split(a,c,"E")
            print c[1], b[2] }'
}

# Stretch a Mw value from a Mw value

function stretched_mw_from_mw () {
  echo $1 | gawk -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{print ($1^str)/(sref^(str-1))}'
}

# Take a string as argument and return an earthquake ID
# Currently just removes whitespace because USGS sometimes has spaces in IDs

function eq_event_parse() {
    echo ${1} | gawk '{val=$0; gsub(/\s/,"",val); print val}'
}
