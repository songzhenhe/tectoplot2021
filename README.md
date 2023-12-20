# tectoplot

tectoplot
Copyright (c) 2021 Kyle Bradley, all rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
   may be used to endorse or promote products derived from this software without
   specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

### NOTE:

This script and its associated code is being actively developed during my spare time to support my own research projects, and large changes can occur that can accidentally break functionality. There are definitely bugs and significant oversights here and there, which will be worked out over time. Eventually the code will be more robust and will be more thoroughly tested and documented. In the mean time, a general changelog can be found at the top of the main tectoplot script. I am commiting updates fairly often as of May 2021.

If you use this script, please keep an eye on your data and validate any plots and outputs before you use them!

At present, not all the data files linked in the script are downloadable from original sources; these are distributed with the script instead. This mainly includes the plate and plate motion models and GPS data, which do need a small amount of customization before use, like splitting polygons that cross the antimeridian, etc.


## Overview

tectoplot is a bash script and associated helper scripts that makes seismotectonic maps, cross sections, and oblique block diagrams. It tries to simplify the process of visualizing data while also maintaining flexibility by running from the command line in a Unix environment and operating mainly on flat text-format data files. tectoplot started as a basic script to automate making shaded relief maps with GMT, and has snowballed over time to incorporate additional functions like plate motion models, swath profiles of topography or other data, cross sections, perspective block diagrams, etc.

tectoplot is mainly intended for small-scale geological studies where maps are 10+km across and data are in geographic coordinates. More detailed areas with projected data are currently beyond the scope of the program.

Calculations generally leave behind the intermediate steps and final data in a temporary folder. This gives access to (for instance) raw swath profile data, filtered seismicity data, clipped DEMs or grids, etc. Some functions generate scripts that can be used to adjust displays or can be the basis of more complex plots (e.g. perspective diagrams).

tectoplot will download and manage various publicly available datasets, like SRTM/GEBCO bathymetry, ISC/GCMT seismicity and focal mechanisms, global populated places, gravity and magnetic data, volcanoes, active faults, etc. It tries to simplify the seismicity catalogs to ensure that maps do not have (for instance) multiple versions of the same event. This process is currently a bit ad-hoc and could be improved. tectoplot can plot either centroid or origin locations for CMT data and will also draw lines to show the alternative locations, on both maps and profiles.

tectoplot's cross section functionality supports multiple profiles incorporating various kinds of data (swath grids like topography or gravity, along-profile sampled grids like Slab2.0 depth grids, XYZ data, XYZ seismicity data scaled by magnitude, and focal mechanisms). Profiles can be aligned in the X direction using an XY polyline that crosses the profiles, such as a trench axis, and can be aligned in the Z direction by matching profile values to 0 at this intersection point. This allows stacking of profiles. Profiles can have more than two vertices, and attempts are made to project data intelligently onto such profiles. Notably, a signed distance function is available that will extract topography in a distance-from-track and distance-along-track-of-closest-point-on-track space, which avoids some of the nasty artifacts arising from kinked profiles.

## Credits
This script relies very heavily on GMT 6 (www.generic-mapping-tools.org), gdal (gdal.org), and GNU awk (gawk).

NDK import in cmt_tools.sh is heavily modified from ndk2meca.awk by Thorsten Becker (sourced from http://www-udc.ig.utexas.edu/external/becker/software/ndk2meca.awk)

Moment tensor diagonalization in done in awk (yes, you read that correctly).

Various CMT calculations are modified from GMT's psmeca.c/ultimeca.c by G. Patau (IPGP)

tectoplot includes source redistributions of:
 Texture shading by Leland Brown and TIFF generation by Brett Casebolt (C source)
    -> Including two new sub-programs for sky view factor and cast shadows (C source, Kyle Bradley)
 Reasenberg seismicity declustering (Fortran source).
 Zaliapin et al. (2008) seismicity declustering (Python code by Mark Williams, UNR)


## Installation

  For full functionality, tectoplot requires that the following programs be
  callable from a shell script. The tested versions are indicated below
  (as of May 3, 2021). Earlier or later versions may or may not work fully.

  gmt (6.1.1) geod (7.2.1) gawk (5.1.0) gdal (3.2.0) python (3.9) gs (9.26-9.53)
  gcc / g++ / gfortran or other CC, CXX, F90 compilers

  Note that gs 9.53 will pipe warnings to stdout about transparency. It's fine to
  downgrade to an earlier version like gs 9.26

  1. Decide what you want to install and where you want to install it:

  - (recommended) tectoplot   
  - (recommended) tectoplot-examples
  - dependencies installed via homebrew (install if necessary)
  - (recommended) dependencies installed via miniconda (install if necessary)

  tectoplot will compile several helper programs written in C/C++/Fortran and
  will use gcc, g++, and gfortran by default.

  Installing via homebrew will try to install the following packages and their
  dependencies:
  (OSX + Linux): git gawk proj gcc gmt@6 ghostscript

  Installing via miniconda will try to install the following packages and their
  dependencies from conda-forge, and will configure tectoplot to use the miniconda
  compilers when a conda environment is active:
  (OSX): python=3.9 git gmt gawk ghostscript clang_osx-64 clangxx_osx-64 gfortran_linux-64
  (Linux): python=3.9 git gmt gawk ghostscript gcc_linux-64 gxx_linux-64 gfortran_linux-64

  2. TO INSTALL TECTOPLOT EASILY: Run the following command from a terminal to
     download and execute the easy installation script:

/usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/kyleedwardbradley/tectoplot/main/install_tectoplot.sh)"

  This script will prompt for options and paths, and then clone the tectoplot and tectoplot-example
  repositories, download homebrew + dependencies, or download miniconda+dependencies.

## Cloning the repository directly

git clone https://github.com/kyleedwardbradley/tectoplot

## Setting up tectoplot after installation

If you did not use the installation script, you will need to do the following steps:

1.	Add the new directory to your path environment variable

  > cd tectoplot
  > ./tectoplot -addpath
  > . ~/.profile

2.	Define the directory where downloaded data will reside. tectoplot will
    download a lot of data if asked, and will store cached DEM tiles in this
    directory, so make sure you have ~20 GB of disk space.

  > tectoplot -setdatadir "/full/path/to/data/directory/"

3.	Download the online datasets into the data directory. If an error occurs,
    run this command again until all downloads clear.

  > tectoplot -getdata

4.	Compile accompanying codes (-getdata may have downloaded some of these codes)

  > tectoplot -compile

5.	Scrape and process the seismicity and focal mechanism catalogs. This will
     take a -very- long time!

  > tectoplot -scrapedata

6.	If Preview is not your PDF viewer, set an alternative that is callable from
    the command line (e.g. evince in this case)

  > tectoplot -setopen evince




## Examples

Example calls to tectoplot and resulting PDF files can be found at this repository:

https://github.com/kyleedwardbradley/tectoplot-examples
