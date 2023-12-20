
# tectoplot
# bashscripts/test_dependencies.sh
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

# This function tests the existence of installed software and will issue a
# message advising how to fix a missing program. If the error is critical, it
# will exit.

# Call by sourcing this file: source ${BASHSCRIPTSDIR}test_dependencies.sh

# The following variables must have values prior to sourcing:
# GMTREQ
# GAWKREQ

[[ $1 =~ "verbose" ]] && echo "Checking dependencies..."

# Check GMT version (modified code from Mencin/Vernant 2015 p_tdefnode.bash)
if [ `which gmt` ]; then
  [[ $1 =~ "verbose" ]] && echo -n "Found gmt: " && which gmt | gawk '{ printf("%s ", $0)}' && gmt --version
	GMT_VERSION=$(gmt --version)
	if [ ${GMT_VERSION:0:1} != $GMTREQ ]; then
		echo "GMT version $GMTREQ or greater is required"
		exit 1
	fi
  echo GSHHG data are in $(gmt gmtget DIR_GSHHG)
else
	echo "Error: Cannot call gmt"
fi

if [ `which gawk` ]; then
  [[ $1 =~ "verbose" ]] && echo -n "Found gawk: " && which gawk | gawk '{ printf("%s ", $0)}' && gawk --version | head -n 1
	GAWK_VERSION=$(gawk --version | gawk '(NR==1) { print substr($0,9,1) }')
	if [ ${GAWK_VERSION} != $GAWKREQ ]; then
		echo "gawk version $GAWKREQ or greater is required"
	fi
else
	echo "Error: Cannot call gawk"
fi

if [ `which ${CCOMPILER}` ]; then
  [[ $1 =~ "verbose" ]] && echo -n "Found c compiler: " && which ${CCOMPILER} | gawk '{ printf("%s ", $0)}' && ${CCOMPILER} -dumpversion
else
	echo "Error: Cannot call c compiler ${CCOMPILER}"
  echo "Affected functions: texture map/sky view factor/shadow ; Litho1.0"
fi

if [ `which ${CXXCOMPILER}` ]; then
  [[ $1 =~ "verbose" ]] && echo -n "Found C++ compiler: " && which ${CXXCOMPILER} | gawk '{ printf("%s ", $0)}' && ${CXXCOMPILER} -dumpversion
else
	echo "Error: Cannot call c++ compiler ${CXXCOMPILER}"
  echo "Affected functions: texture map/sky view factor/shadow ; Litho1.0"
fi

if [ `which ${F90COMPILER}` ]; then
  [[ $1 =~ "verbose" ]] && echo -n "Found fortran compiler: " && which ${F90COMPILER}
else
	echo "Error: Cannot call fortran compiler ${F90COMPILER}"
  echo "Affected functions: Reasenberg declustering"
fi

if [ `which geod` ]; then
  [[ $1 =~ "verbose" ]] && echo -n "Found geod: " && which geod | gawk '{ printf("%s ", $0)}' && geod 2>&1 | head -n 1
else
	echo "Error: Cannot call geod"
  echo "Affected functions: Plate motions, GPS"
fi

[[ $1 =~ "verbose" ]] && echo "GDAL: tested with v. 3.2.0. Earlier versions may not work!"

if [ `which gdalinfo` ]; then
  [[ $1 =~ "verbose" ]] && echo -n "  Found gdalinfo: " && which gdalinfo | gawk '{ printf("%s ", $0)}' && gdalinfo --version
else
	echo "Error: Cannot call gdalinfo"
  echo "Affected functions: Topography visualizations"
fi


if [ `which gdal_calc.py` ]; then
  [[ $1 =~ "verbose" ]] && echo -n "  Found gdal_calc.py: " && which gdal_calc.py
else
	echo "Error: Cannot call gdal_calc.py"
  echo "Affected functions: Most topography / imagery visualizations"
fi

if [ `which gdalwarp` ]; then
  if [ `which gdaldem` ]; then
    if [[ $1 =~ "verbose" ]]; then
      echo -n "  Found gdalwarp: "
      which gdalwarp
    fi
  else
  	echo "Error: Cannot call gdaldem"
    echo "Affected functions: Some topography visualizations (texture shading, svf, shadows)"
  fi
fi

if [ `which gdaldem` ]; then
  if [[ $1 =~ "verbose" ]]; then
    echo -n "  Found gdaldem: "
    which gdaldem
  fi
else
	echo "Error: Cannot call gdaldem"
  echo "Affected functions: Topography visualizations"
fi
