# tectoplot
# euleradd.awk
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


# gawk function to add two Euler poles given as latitude/longitude/rotation rate

# This function uses two poles of rotation given in the form A->B  C->B -- to find -->  A->C
# Call like this: awk -f euleradd.awk eulerpairs.txt
# Where eulerpairs.txt (or stdin if piped in) are in the form lat1 lon1 rate1 lat2 lon2 rate2

# Example input
# lat1   lon1   rate1   lat2   lon2   rate2
# 50.37  -3.29  0.544   44.44  23.09  0.608
# Example output
# -1.95016 -74.4483 0.197499

function atan(x) { return atan2(x,1) }
function acos(x) { return atan2(sqrt(1-x*x), x) }
function asin(x) { return atan2(x, sqrt(1-x*x)) }

function deg2rad(Deg){ return ( 4.0*atan(1.0)/180 ) * Deg }
function rad2deg(Rad){ return ( 45.0/atan(1.0) ) * Rad }

function euleradd(eLat_d1, eLon_d1, eV1, eLat_d2, eLon_d2, eV2) {
	eLat_r1 = deg2rad(eLat_d1)
	eLon_r1 = deg2rad(eLon_d1)
	eLat_r2 = deg2rad(eLat_d2)
	eLon_r2 = deg2rad(eLon_d2)

	a11 = eV1*cos(eLat_r1)*cos(eLon_r1)
	a21 = eV1*cos(eLat_r1)*sin(eLon_r1)
	a31 = eV1*sin(eLat_r1)

	a12 = eV2*cos(eLat_r2)*cos(eLon_r2)
	a22 = eV2*cos(eLat_r2)*sin(eLon_r2)
	a32 = eV2*sin(eLat_r2)

	a1 = a11-a12
	a2 = a21-a22
	a3 = a31-a32

  eVA = sqrt(a1*a1+a2*a2+a3*a3)

  if (eVA == 0) {
		elat_rA = 0
		elon_rA = 0
	}
	else {
		elat_rA = asin(a3/eVA)
		elon_rA = atan2(a2,a1)
	}
  print(rad2deg(elat_rA), rad2deg(elon_rA), eVA)
}

BEGIN{
}
NF {
	printf euleradd($1, $2, $3, $4, $5, $6)
}
