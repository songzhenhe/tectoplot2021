# tectoplot
# bashscripts/info.sh
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

##### FORMATS MESSAGE is now in a file in tectoplot_defs

function formats() {
echo $TECTOPLOT_VERSION
cat $TECTOPLOT_FORMATS
}

##### USAGE MESSAGES

function print_help_header() {
  cat <<-EOF

  -----------------------------------------------------------------------------

  $TECTOPLOT_VERSION
  Copyright 2021, Kyle Bradley, Nanyang Technological University
  www.github.com/kyleedwardbradley/tectoplot
  kbradley@ntu.edu.sg

  What is tectoplot?

  tectoplot is a collection of scripts and programs that make it easy to plot
  topographic and seismotectonic data in publication quality figures using GMT
  and gdal. It integrates various global datasets relevant to regional seismo-
  tectonic analysis and is designed for a typical Unix command line environment.
  Extracted data and many intermediate products can be saved and queried. Map
  layering is generally specified by the order of commands given. tectoplot
  started as a script to plot TDEFNODE model outputs, and snowballed during
  Singapore's COVID circuit breaker lockdown.

  Main functions
    - Make PS/PDF maps using GMT supported projections and GMT formatting options
    - Automatic determination of UTM zone from map AOI
    - Scrapes public global earthquake catalogs (ISC/ANSS/GCMT/GFZ)
    - Calculates focal mechanism parameters as necessary (e.g. SDR->MTensor)
    - Query seismicity by AOI, polygon, time, magnitude, depth range
    - Sort seismicity data before plotting (depth, magnitude, time)
    - Label seismicity on maps and profiles according to different rules
    - Plot kinematic data from focal mechanisms (PTN axes, slip vectors)
    - Generate automatic event maps using earthquake IDs
    - Downloads various useful datasets (SRTM30, WGM, Slab2.0, crust age, etc.)
    - Plot volcanoes, populated places
    - Downloads Sentinel cloud-free satellite imagery (EOX::Maps)
    - Generates 3D perspective diagrams from swath profiles
    - Flexible profiling system, including swath extraction from grids, grid
      sampling, multi-point profiles, and signed distance along profile.
    - Profiles can be aligned to intersection of profile with an XY polyline
    - Profiles across non-DEM datasets (e.g. gravity)
    - Profiles can plot Litho1 Vp/Vp/Density
    - Profile azimuth can be taken from Slab2 down-dip direction
    - Flexible topography visualizations that can be combined together
      (hillshade, slope, sky view factor, cast shadows, texture mapping)
    - Oblique topography can be rotated/adjusted using a generated script
    - Visualization of plate motions from three published models (MORVEL,GSRM,GBM)
    - Plot GPS velocities (Kreemer et al., 2014) in different reference frames
    - Plot TDEFNODE model outputs
    - Run custom scripts in-line with access to internal variables and datasets
    - Generate georeferenced GEOTIFF and KML files without a map collar

  Requires: GMT6+, bash 3+, gdal (with gdal_calc.py), proj (geod), gawk, grep, data, sed, ls

  Datasets that are distributed alongside tectoplot with minor reformatting only:
   1. Global Strain Rate Map plate polygons, Euler poles, and GPS velocities
     C. Kreemer et al. 2014, doi:10.1002/2014GC005407
   2. MORVEL56-NNR polygons, Euler poles
     D. Argus et al., 2011 doi:10.1111/j.1365-246X.2009.04491.x
   3. Global Block Model polygons, Euler poles
     S.E. Graham et al. 2018, doi:10.1029/2017GC007391

  Portions of this code were inspired by the following:
   Thorsten Becker (ndk2meca.awk)  G. Patau (IPGP) - (psmeca.c/ultimeca.c)

  Developed for OSX Catalina, minimal testing indicates works with Fedora linux

  USAGE: tectoplot -opt1 arg1 -opt2 arg2 arg3 ...

  HELP and INSTALLATION:    tectoplot -setup
  OPTIONS:                  tectoplot -options     (mostly updated)
  VARIABLES:                tectoplot -variables   (not fully updated)
  LONG HELP:                tectoplot

  -----------------------------------------------------------------------------
EOF
}

function print_options() {
cat <<-EOF
    Optional arguments:
    [opt] is required if the flag is present
    [[opt]] if not specified will assume a default value or will not be used

Common command recipes:

    Seismotectonic map
    -seismo                      -t -t1 -b c -z -c

    Topography visualization with oblique perspective of topography
    -topog                       -t -t1 -ob 45 20 3

    Map centered on an earthquake event with a simple profile, legend, title,
        and oblique perspective diagram
    -eventmap [eventID] [deg]    -t -b -z -c -eqlist -aprof -title --legend -mob

    Map of recent earthquakes, labelled.
    -recenteq                    -z -c -a -eqlabel

  Data control, installation, information
    -addpath               add the tectoplot source directory to your ~.profile
    -getdata               download and validate builtin datasets
    -compile               compile accompanying program codes
    -setopenprogram        configure program to open PDFs

    -data                  list data sources and exit
    -defaults              print default values and exit (Can edit and load using -setvars)
    -formats               print information on data formats and exit
    -h|--help              print this message and exit
    -n|--narrate           echo a lot of information during processing
    -nocleanup             preserve all intermediate files instead of rm at end
    -query                 print headers for data files, print data columns in space delim/CSV format
             If no column selecting options are given, print all columns
             tectoplot -tm /PATH/ -query option1 option2
             options: csv         =   print in CSV format
                      noheader    =   don't print header line
                      nounits     =   don't print units (e.g. longitude[degrees] -> longitude)
                      data        =   print the data from the file
                      1 2 3 5 ... =   print data selected by column number
                      longitude...=   print column with field name=option
    --verbose              set gmt -V flag for all calls
    -megadebug             turn on hyper-verbose shell debugging

  Input/output controls
    -ips             [filename]                          plot on top of an unclosed .ps file. Use -pos to set position
    --keepopenps                                         don't close the PS file to allow further plotting
    -pos X Y         Set X Y position of plot origin     (GMT format -Xval -Yval; e.g -Xc -Y1i etc)
    -geotiff                                             output GeoTIFF and .tfw, frame inside
    -kml                                                 output KML, frame inside
    -noopen                                              do not open map PDF at end
    -o|--out         [filename]                          basename of output file [+.pdf, +.tif, etc added as needed]
    -pss   [size]          Set PS page size in inches (8).
    --inset          [[size]] [[deg]] [[x]] [[y]]        plot a globe with AOI polygon.
    --legend         [[width]]                           plot legend above the map area (color bar width=2i)
    -gres            [dpi]                               set dpi of grids printed to PS file (default: grid native res)
    -command                                             print tectoplot command at bottom of page
    -author          [[author_string]]                   print author and date info at bottom of page
    -authoryx        [yshift] [[xshift]]                 shift author info vertically by yshift and horizontally by xshift
                                                         If tectoplot.author does not exist in tectoplot_defs/, set it
                                                         author_string=reset will reset the author info
    -noplot                                              exit before plotting anything with GMT
    -noframe                                             don't plot a frame

  Low-level control
    -gmtvars         [{VARIABLE value ...}]              set GMT internal variables
    -psr             [0-1]                               scale factor of map ofs pssize
    -psm             [size]                              PS margin in inches (0.5)
    -cpts                                                remake default CPT files
    -setvars         { VAR1 VAL1 VAR2 VAL2 }             set bash variable values
    -vars            [variables file]                    set bash variable values by sourcing file
    -tm|--tempdir    [tempdir]                           use tempdir as temporary directory
    -e|--execute     [bash script file]                  runs a script using source command
    -i|--vecscale    [value]                             scale all vectors (0.02)

  Area of Interest options. The lat/lon AOI box is the region from which data are selected
    -r|--range       [MinLon MaxLon MinLat MaxLat]       area of interest, degrees
                     [g]                                 global domain [-180:180/-90:90]
                     [GMT ID]                            AOI from GMT style region ID string
                        Examples: [ US ; US.CO ; =NA ; =NA,=SA ; CO,VE ; CO,VE+R5 ]
                     [grid_file]                         use region of the given grid file
                     [customID]                          AOI defined in tectoplot.customrange

    Record, delete, and list custom regions (includes -R region and -J projection info)
    -radd            [customID; no whitespace]           set customID based on -r arguments
    -rdel            [customID; no whitespace]           delete customID from custom region file and exit
    -rlist                                               print customIDs and extends and exit

  Map projection definition. Default projection is Plate Carrée [GMT -JQ, reference latitude is 0].

    -RJ              [{ -Retc -Jetc }]                   provide custom R, J GMT strings

    Local projections. AOI region needs to be specified using -r in addition to -RJ
    -RJ              UTM [[zone]]                        plot UTM, zone is defined by mid longitude (-r) or specified
    -rect                                                use rectangular map frame (UTM projection only)

    Global projections (-180:180/-90:90) specified by word or GMT letter and optional arguments
    -RJ              Hammer|H ; Molleweide|W ; Robinson|N       [[Meridian]]
                     Winkel|R ; VanderGrinten|V ; Sinusoidal|I  [[Meridian]]
                     Hemisphere|A                               [[Meridian]] [[Latitude]]

    Global projections with degree range, specified by word or GMT letter and optional arguments
                     Gnomonic|F ; Orthographic|G ; Stereo|S     [[Meridian]] [[Latitude]] [[Range]]
                             |Fg              |Gg        |Sg    [global extent - do not recalculate AOI]
    Oblique Mercator projections
    -RJ              ObMercA/OA  [centerlon] [centerlat] [azimuth] [width]k [height]k
                     ObMercC/OC  [centerlon] [centerlat] [polelon] [polelat] [width]k [height]k

  Grid/graticule and map frame options
    -B               [{ -Betc -Betc }]                   provide custom B strings for map in GMT argument format
    -pgs             [gridline spacing]                  override automatic map gridline spacing
    -pgo                                                 turn grid lines on
    -pgl                                                 turn grid labels off
    -pgn                                                 don't plot grid at all
    -scale           [length] [lon] [lat]                plot a scale bar. length needs suffix (e.g. 100k).

  Profiles and oblique block diagrams:
      [width] requires unit letter, e.g. 100k, and is full width of profile
      [res] is the resolution at which we resample grids to make top tile grid (e.g. 1k)

    -aprof: plot an automatic profile using a code made of two letters: [A-Y][A-Y]
          -aprof [code1] [[code2 ...]] [width] [res]
    -cprof: profile defined by centerpoint (or eq), azimuth (or slab2)
          -cprof [centerlon or "eq"] [centerlat or "eq"] [azimuth or "slab2"] [length] [width] [res]
    -kprof: plot profiles from a KML containing a number of one- or multi-segment lines
          -kprof [kml file] [[width]] [[res]]
    -mprof: plot multiple swath profiles using a control file
          -mprof [control_file] [[A B X Y]]
                  A=width (7i) B=height (2i) X,Y=offset relative to current origin (0i -3i)
    -sprof: plot single profile between endpoints
          -sprof [lon1] [lat1] [lon2] [lat2] [width] [res]

    -aprofcodes      plot the points and letters for the -aprof codes on the map
    -oto             [[change_z | change_h]]    no vertical exaggeration on profiles
    -psel            [PID1] [[PID2...]]                  only plot profiles with specified PID from control file
    -mob             [[Azimuth(deg)]] [[Inclination(deg)]] [[VExagg(factor)]] [[Resolution(m)]]
                            create oblique perspective diagrams for profiles
    -msd             Use a signed distance formulation for profiling to generate DEM for display (for kinked profiles)
    -msl             Display only the left side of the profile so that the cut is exactly on-profile
    -litho1 [type]   Plot LITHO1.0 data for each profile. Allowed types are: density Vp Vs
    -alignxy         XY file used to align profiles.
    -showprof       [[all]] 1 2 3 ...                   plot selected profiles below map

  Topography/bathymetry:
    -t|--topo        [[ SRTM30 | GEBCO20 | GEBCO1 | ERCODE | GMRT | BEST | custom_grid_file ]] [[cpt]]
                     plot shaded relief (including a custom grid)
                     ERCODE: GMT Earth Relief Grids, dynamically downloaded and stored locally:
                     01d ~100km | 30m ~55 km | 20m ~37km | 15m ~28km | 10m ~18 km | 06m ~10km
                     05m ~9km | 04m ~7.5km | 03m ~5.6km | 02m ~3.7km | 01m ~1.9km | 15s ~500m
                     03s ~100m | 01s ~30m
                     BEST uses GMRT for elev < 0 and 01s for elev >= 0 (resampled to match GMRT)
    -ti              [[sun_az]] [[sun_elev]]             adjust illumination for default GMT terrain
    -ts                                                  don't plot shaded relief/topo grid
    -tr              [[minelev maxelev]]                 rescale CPT using data range or specified limits
    -tc|--cpt        [cptfile]                           use custom cpt file for topo grid
    -tx                                                  don't color topography (plot intensity directly)
    -tt|--topotrans  [transparency%]                     transparency of final plotted topo grid
    -clipdem                                             save terrain as dem.nc in temporary directory
    -tflat                                               set DEM elevations < 0 to 0 (no bathymetry)

  Popular recipes for topo visualization
    -t0              [[sun_el]] [[sun_az]]               single hillshade
    -t1              [[sun_el]]                          combination multiple hs/slope map

  Build your own topo visualization using these commands in sequence.
    [[fact]] is the blending factor (0-1) used to combine each layer with existing intensity map
    [[alpha]] is transparency (blend with white before multiply combine)

    -tshad           [[shad_az]] [[shad_el]] [[alpha]]   add cast shadows to intensity (fact=opacity)
    -ttext           [[frac]]   [[stretch]]  [[fact]]    add texture shade to intensity
    -tmult           [[sun_el]]              [[fact]]    add multiple hillshade to intensity
    -tuni            [[sun_az]] [[sun_el]]   [[fact]]    add unidirectional hillshade to intensity
    -tsky            [[num_angles]]          [[fact]]    add sky view factor to intensity
    -tgam            [[gamma]]                           add gamma correction to black/white intensity
    -timg            [image] [[alpha]]                   overlay referenced RGB raster instead of color ramp
    -tsent           [[alpha]] [[gamma]]                 download and overlay Sentinel cloud free (EOX::Maps at eox.at)
    -tblue           [[alpha]] [[gamma]]                 NASA Blue Marble (EOX::Maps at eox.at)
                      -tsent image is saved as \${TMP}sentinel.tif and can be plotted using -im TEMP/sentinel.tif
    -tunsetflat                                          set intensity at elevation=0 to white (no texture in oceans)
    -tsea            [[Red Green Blue]]                  recolor Sentinel images at elevation<=0
    -tclip           [lonmin] [lonmax] [latmin] [latmax] clip dem to alternative rectangular AOI

    -tsave              If -r RegionID option is being used, save the final colored topo image
    -tload              If -tload and the image exists, use that directly.
    -tdelete            If -tdelete, delete any stored topo image for custom region.

    -tn              [interval (m)]                      plot topographic contours
    -gebcotid                                            plot GEBCO TID raster

    -ob              [[az]] [[inc]] [[floor_elev]] [[frame]]   plot oblique view of topography

  Additional map layers from downloadable data:
    -a|--coast       [[quality]] [[a,b]] { gmtargs }     plot coastlines [[a]] and borders [[b]]
                     quality = a,f,h,i,l,c
    -ac              [[LANDCOLOR]] [[SEACOLOR]]          fill coastlines/sea (requires subsequent -a command)
    -acb             [[color]] [[linewidth]] [[quality]] plot country borders (quality = a,l,f)
    -acl                                                 label country centroids
    -af              [[AFLINEWIDTH]] [[AFLINECOLOR]]     plot active fault traces
    -b|--slab2       [[layers string: c]]                plot Slab2 data; default is c
                     c: slab contours  d: slab depth grid
    -gcdm                                                plot Global Curie Depth Map
    -litho1_depth    [type] [depth]                      plot litho1 depth slice (positive depth in km)
    -m|--mag         [[transparency%]]                   plot crustal magnetization
    -oca             [[trans%]] [[cpt]]                  oceanic crust age
    -pp|--cities     [[min population]] [[cpt]]          plot cities with minimum population, color by population
    -ppl             [[min population]]                  label cities with a minimum population
    -s|--srcmod                                          plot fused SRCMOD EQ slip distributions
    -v|--gravity     [[FA | BG | IS | SW | SWC ]] [transparency%] [rescale]            rescale=rescale colors to min/max
                     plot WGM12 gravity. FA = free air | BG == Bouguer | IS = Isostatic | SW = Sandwell2019 FA
    -vcurv                                               Plot Sandwell 2019 free air gravity - curvature
    -vc|--volc                                           plot Pleistocene volcanoes
    -fz                                                  plot GSFML_FZ fracure zones
    -bigbar          [cpt_file] ["title string"] [lowval] [highval]  plot large psscale beneath map


  Map layers from EarthByte data, produced for GPlates (2.2.0) and downloaded from GPlates webpage
    -ebiso           Oceanic plate isochrons
    -ebhot           Hotspots

  Turn on and off clipping using a polygon file

    -clipon          [polygonFile] | [GMT polygon ID]    turn on polygon clipping mask
    -clipout         [polygonFile] | [GMT polygon ID]    turn on inversed clipping mask
    -clipoff                                             turn off all clipping masks
    -clipline                                            plot clipping line

  GPS velocities:
    -g|--gps         [[RefPlateID]]                      plot GPS data from Kreemer 2014 / rel. to RefPlateID
    -gadd|--extragps [filename]                          plot an additional GPS / psvelo format file
    -gls                                                 list plate IDs for GPS data and exit

  Earthquake slip model with .grd and clipping path:
    -eqslip [gridfile1] [clipfile1] [[gridfile2]] [[clipfile2]] ...  Plot contoured, colored EQ slip model

  Both seismicity and focal mechanisms:
    --time           [STARTTIME ENDTIME]                 select EQ/CMT between dates (midnight AM), format YYYY-MM-DD
    -zcnoscale                                           don't rescale earthquake data by magnitude
    -zcrescale       [stretch_factor] [ref_mag]          rescale CMT/seismicity using nonlinear stretch
    -zdep            [mindepth] [maxdepth]               rescrict CMT/hypocenters to between mindepth-maxdepth[km]

    -zctime          [[start_time]] [[end_time]]         color seismicity by time range instead of depth
                                                         [not yet implemented for cross sections]
  Seismicity:
    -z|--seis        [[scale]]                           plot seismic epicenters (from scraped earthquake data)
    -zsort           [time|depth|mag] [up|down]          sort earthquake data before plotting
    -zadd            [file] [[replace]] [[cull]]         add seismicity file - repeat for 2+
                                                           replace=no global cat, cull=remove equivs from cats
    -zmag            [minmag] [[maxmag]]                 set minimum and maximum magnitude
    -zcat            [ANSS | ISC | NONE]                 select the scraped EQ catalog to use. NONE is used with -zadd
    -zcolor          [mindepth] [maxdepth]               set range of color stretch for EQ+CMT data
    -zfill           [color]                             set uniform fill color for seismicity
    -zline           [width]                             seismicity outline width; 0=no outline drawn

  Seismicity/focal mechanism data control:
    -reportdates                                         print date range of seismic, focal mechanism catalogs and exit
    -scrapedata                                          run the GCMT/ISC/ANSS scraper scripts and exit
    -eqlist          [[file]] { event1 event2 event3 ... }  highlight focal mechanisms/hypocenters with ID codes in file or list
    -eqselect                                            only consider earthquakes with IDs in eqlist
    -eqlabel         [[list]] [[r]] [[minmag]] [format]  label earthquakes in eqlist or within magnitude range
                                                         r=EQ from -r eq; format=idmag | datemag | dateid | id | date | mag
    -pg|--polygon    [polygon_file.xy] [[show]]          use a closed polygon to select data instead of AOI; show option prints polygon to map

  Focal mechanisms:
    -c|--cmt         [[source]] [[scale]]                plot focal mechanisms from global databases
    -cx              [file]                              plot additional focal mechanisms, format matches -cf option
    -ca              [nts] [tpn]                         plot selected P/T/N axes for selected EQ types
    -cc                                                  plot dot and line connecting to alternative position (centroid/origin)
    -cf              [ MomentTensor | GlobalCMT | TNP ]  choose the format of focal mechanism to plot.
    -cmag            [minmag] [[maxmag]]                 magnitude bounds for cmt
    -cr|--cmtrotate) [lon] [lat]                         rotate CMTs based on back-azimuth to a point
    -cw                                                  plot CMTs with white compressive quads
    -ct|--cmttype    [nts | nt | ns | n | t | s]         sets earthquake types to plot CMTs
    -zr1|--eqrake1   [[scale]]                           color focal mechs by N1 rake
    -zr2|--eqrake2   [[scale]]                           color focal mechs by N2 rake
    -cs                                                  plot TNP axes on a stereonet (output to stereo.pdf)
    -cadd            [file] [code] [[replace]]           plot focal mechanisms from local data file
                             code: a,c,x,m,I,K           (GMT:AkiR,GCMT,p.axes,m.tensor; ISC:I; NDK:K)
    -cslab2          [[ddist]] [[dstr]] [[ddip]]         select focal mechanisms within ddist vertical km of
                                                         slab2 surface, a nodal plane within dstr strike and
                                                         ddip dip compared to slab2 (interplate thrusts)
    -cdeep                                               select strike-slip focal mechanisms beneath Slab2
    -cunfold                                             back-tilt focal mechanisms based on Slab2 strike/dip

  Focal mechanism kinematics (CMT):
    -kg|--kingeo                                         plot strike and dip of nodal planes
    -kl|--nodalplane [1 | 2]                             plot only NP1 (lower dip) or NP2
    -km|--kinmag     [minmag maxmag]                     magnitude bounds for kinematics
    -kt|--kintype    [nts | nt | ns | n | t | s]         select types of EQs to plot kin data
    -ks|--kinscale   [scale]                             scale kinematic elements
    -kv|--slipvec                                        plot slip vectors

  Plate models (require a plate motion model specified by -p or --tdefpm)
    -f|--refpt       [Lon/Lat]                           reference point location
    -p|--plate       [[GBM | MORVEL | GSRM]] [[refplate]] select plate motion model, relative to stationary refplate
    -pe|--plateedge  [[GBM | MORVEL | GSRM]]             plot plate model polygon edges
    -pc              PlateID1 color1 [[trans1]] PlateID2 color2 [[trans2]] ... semi-transparent coloring of plate polygons
                     random [[trans]]                    semi-transparent random coloring of all plates in model
    -pf|--fibsp      [km spacing]                        Fibonacci spacing of plate motion vectors; turns on vector plot
    -px|--gridsp     [Degrees]                           Gridded spacing of plate motion vectors; turns on vector plot
    -pl                                                  label plates
    -ps              [[GBM | MORVEL | GSRM]]             list plates and exit. If -r is set, list plates in region
    -pr                                                  plot plate rotations as small circles with arrows
    -pz              [[scale]]                           plot plate boundary azimuth differences (does edge computations)
                                                         histogram is plotted into az_histogram.pdf
    -pv              [cutoff distance]                   plot plate boundary relative motion vectors (does edge computations)
                                                         cutoff distance dictates spacing between plotted velocity pairs
    -w|--euler       [Lat] [Lon] [Omega]                 plots vel. from Euler Pole (grid)
    -wp|--eulerplate [PlateID] [RefplateID]              plots vel. of PlateID wrt RefplateID
                     (requires -p or --tdefpm)
    -wg              [residual scale]                    plots -w or -wp at GPS sites (plot scaled residuals only)
    -pvg             [[res]] [[rescale]]                 plots a plate motion velocity grid. res=0.1d ; rescale=rescale colors to min/max

  User specified GIS datasets:
    -cn|--contour    [gridfile] [interval] { gmtargs }   plot contours of a gridded dataset
                                          gmtargs for -A -S and -C will replace defaults
    -gr|--grid       [gridfile] [[cpt]] [[trans%]]       plot a gridded dataset colored with a CPT
    -im|--image      [filename] { gmtargs }              plot a RGB GeoTiff file (georeferenced)
    -li|--line       [filename] [[color]] [[width]]                data: > ID (z)\n x y\n x y\n > ID2 (z) x y\n ...
    -pt|--point      [filename] [[symbol]] [[size]] [[cptfile]]    data: x y z
    -sv|--slipvector [filename]                          plot data file of slip vector azimuths [Lon Lat Az]

  TDEFNODE block model
    --tdefnode       [folder path] [lbsovrfet ]          plot TDEFNODE output data.
          l=locking b=blocks s=slip o=observed gps vectors v=modeled gps vectors
          r=residual gps vectors; f=fault slip rates; a=block name labels
          e=elastic component of velocity; t=block rotation component of velocity
          y=fault midpoint sliprates, spaced
    --tdefpm         [folder path] [RefPlateID]          use TDEFNODE results as plate model
    --tdeffaults     [1,2,3,5,...]                       select faults for coupling plotting and contouring

EOF
}

function print_usage() {
  print_help_header
  print_setup
  print_options
  print_variables
}

# Needs significant updating

function print_variables {
  cat <<-EOF

Common variables to modify using -vars [file] and -setvars { VAR value ... }

Topography:     TOPOTRANS [$TOPOTRANS]

Profiles:       SPROF_MAXELEV [$SPROF_MAXELEV] - SPROF_MINELEV [$SPROF_MINELEV]

Plate model:    PLATEARROW_COLOR [$PLATEARROW_COLOR] - PLATEARROW_TRANS [$PLATEARROW_TRANS]
                PLATEVEC_COLOR [$PLATEVEC_COLOR] - PLATEVEC_TRANS [$PLATEVEC_TRANS]
                LATSTEPS [$LATSTEPS] - GRIDSTEP [$GRIDSTEP] - AZDIFFSCALE [$AZDIFFSCALE]
                PLATELINE_COLOR [$PLATELINE_COLOR] - PLATELINE_WIDTH [$PLATELINE_WIDTH]
                PLATELABEL_COLOR [$PLATELABEL_COLOR] - PLATELABEL_SIZE [$PLATELABEL_SIZE]
                PDIFFCUTOFF [$PDIFFCUTOFF]

Both CMT and Earthquakes: EQCUTMINDEPTH [$EQCUTMINDEPTH] - EQCUTMAXDEPTH [$EQCUTMAXDEPTH]
                SCALEEQS [$SCALEEQS] - SEISSTRETCH [$SEISSTRETCH] - SEISSTRETCH_REFMAG [$SEISSTRETCH_REFMAG]
                EQMAXDEPTH_COLORSCALE [$EQMAXDEPTH_COLORSCALE]

Earthquakes:    SEISSIZE [$SEISSIZE] - SEISSCALE [$SEISSCALE] - SEISSYMBOL [$SEISSYMBOL] - SEISTRANS [$SEISTRANS]
                REMOVE_DEFAULTDEPTHS [$REMOVE_DEFAULTDEPTHS] - REMOVE_DEFAULTDEPTHS_WITHPLOT [$REMOVE_DEFAULTDEPTHS_WITHPLOT]
                REMOVE_EQUIVS [$REMOVE_EQUIVS]

CMT focal mech: CMT_NORMALCOLOR [$CMT_NORMALCOLOR] - CMT_SSCOLOR [$CMT_SSCOLOR] - CMT_THRUSTCOLOR [$CMT_THRUSTCOLOR]
                CMTSCALE [$CMTSCALE] - CMTFORMAT [$CMTFORMAT] - CMTSCALE [$CMTSCALE] - PLOTORIGIN [$PLOTORIGIN]
                CMT_NORMALCOLOR [$CMT_NORMALCOLOR] - CMT_SSCOLOR [$CMT_SSCOLOR] - CMT_THRUSTCOLOR [$CMT_THRUSTCOLOR]

CMT principal axes: CMTAXESSTRING [$CMTAXESSTRING] - CMTAXESTYPESTRING [$CMTAXESTYPESTRING] - CMTAXESARROW [$CMTAXESARROW]
                    CMTAXESSCALE [$CMTAXESSCALE] - T0PEN [$T0PEN] - FMLPEN [$FMLPEN]

CMT kinematics: KINSCALE [$KINSCALE] - NP1_COLOR [$NP1_COLOR] - NP2_COLOR [$NP2_COLOR]
                RAKE1SCALE [$RAKE1SCALE] - RAKE2SCALE [$RAKE2SCALE]

Active faults:  AFLINECOLOR [$AFLINECOLOR] - AFLINEWIDTH [$AFLINEWIDTH]

Volcanoes:      V_FILL [$V_FILL] - V_SIZE [$V_SIZE] - V_LINEW [$V_LINEW]

Coastlines:     COAST_QUALITY [$COAST_QUALITY] - COAST_LINEWIDTH [$COAST_LINEWIDTH] - COAST_LINECOLOR [$COAST_LINECOLOR] - COAST_KM2 [$COAST_KM2]
                LANDCOLOR [$LANDCOLOR] - SEACOLOR [$SEACOLOR]

Gravity:        GRAV_RESCALE [$GRAV_RESCALE]

Magnetics:      MAG_RESCALE [$MAG_RESCALE]

Point data:     POINTCOLOR [$POINTCOLOR] - POINTSIZE [$POINTSIZE] - POINTLINECOLOR [$POINTLINECOLOR] - POINTLINEWIDTH [$POINTLINEWIDTH]

Grid contours:  CONTOURNUMDEF [$CONTOURNUMDEF] - GRIDCONTOURWIDTH [$GRIDCONTOURWIDTH] - GRIDCONTOURCOLOUR [$GRIDCONTOURCOLOUR]
                GRIDCONTOURSMOOTH [$GRIDCONTOURSMOOTH] - GRIDCONTOURLABELS [$GRIDCONTOURLABELS]

EOF
}

function print_setup() {
cat <<-EOF

Install tectoplot and dependencies (via homebrew or miniconda) using the following
command:

/usr/bin/env bash -c "\$(curl -fsSL https://raw.githubusercontent.com/kyleedwardbradley/tectoplot/main/install_tectoplot.sh)"

SETUP: Installing and configuring tectoplot and its dependencies

On a clean OSX machine, you can use Homebrew to install all of the necessary
components to run tectoplot.

1.	Install homebrew, then use it to install dependencies.

  > /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  > brew update
  > brew install git
  > brew install gcc
  > brew install gmt
  > brew install gawk
  > brew install ghostscript

2.	Clone the tectoplot repository into a new folder. Please ensure that the full path
    to this folder does not contain a whitespace (space,tab) character.

  > git clone https://github.com/kyleedwardbradley/tectoplot.git tectoplot

3.	Add the new directory to your path environment variable

  > cd tectoplot
  > ./tectoplot -addpath
  > . ~/.profile

4.	Define the directory where downloaded data will reside.

  > tectoplot -setdatadir "/full/path/to/data/directory/"

5.	Download the online datasets into the data directory. If an error occurs,
    run this command again until all downloads clear.

  > tectoplot -getdata

6.	Compile accompanying codebase (-getdata downloaded some of these codes)

  > tectoplot -compile

7.	Scrape and process the seismicity and focal mechanism catalogs. This will
     take a very long time!

  > tectoplot -scrapedata

8.	If Preview is not your PDF viewer, set an alternative that is callable from
    the command line

  > tectoplot -setopen evince

9.	Test! Create a new folder for maps, change into it, and create a plot of
    the Solomon Islands including bathymetry, CMTs, and seismicity:

  > mkdir ~/regionalplots/ && cd ~/regionalplots/
  > tectoplot -r SB -t -z -c

EOF
}

function datamessage() {
  . $TECTOPLOT_PATHS_MESSAGE
}

function defaultsmessage() {
  cat $TECTOPLOT_DEFAULTS_FILE
}
