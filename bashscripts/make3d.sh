#
# tectoplot/bashscripts/make3d.sh
#
#

# Create a global Fibonacci grid of white dots sampled every PLY_FIB_KM km
# If DEM exists, sample it to set elevations; otherwise use the Earth radius

if [[ $makeplyflag -eq 1 && $makeplysurfptsflag -eq 1 && $plydemonlyflag -eq 0 ]]; then
  ##### MAKE FIBONACCI GRID POINTS
  # Surface area of Earth = 510,000,000 km^2
#  echo  FIB_N=\$\(echo "510000000 / \( ${PLY_FIB_KM} * ${PLY_FIB_KM} - 1 \) / 2" \| bc\)

  FIB_N=$(echo "510000000 / ( ${PLY_FIB_KM} * ${PLY_FIB_KM} ) / 2" | bc)
    echo "" | gawk  -v n=${FIB_N}  -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '
    @include "tectoplot_functions.awk"
    # function asin(x) { return atan2(x, sqrt(1-x*x)) }
    BEGIN {
      phi=1.618033988749895;
      pi=3.14159265358979;
      phi_inv=1/phi;
      ga = 2 * phi_inv * pi;
    } END {
      for (i=-n; i<=n; i++) {
        longitude = ((ga * i)*180/pi)%360;

        latitude = asin((2 * i)/(2*n+1))*180/pi;
        # LON EDIT TAG - TEST
        if ( (latitude <= maxlat) && (latitude >= minlat)) {
          if (test_lon(minlon, maxlon, longitude)==1) {
            if (longitude < -180) {
              longitude=longitude+360;
            }
            if (longitude > 180) {
              longitude=longitude-360
            }
            print longitude, latitude
          }
        }
        # if (((longitude <= maxlon && longitude >= minlon) || (longitude+360 <= maxlon && longitude+360 >= minlon)) && {
        #   print longitude, latitude
        # }
      }
    }' | gmt gmtselect ${RJSTRING[@]} ${VERBOSE} > ${F_3D}ply_gridfile.txt

numsurfpts=$(wc -l < ${F_3D}ply_gridfile.txt | gawk '{print $1}')
cat <<-EOF > ${F_3D}tectoplot_surface.ply
ply
format ascii 1.0
element vertex ${numsurfpts}
property float x
property float y
property float z
property uchar red
property uchar green
property uchar blue
end_header
EOF

    if [[ -s ${F_TOPO}dem.nc ]]; then
      gmt grdtrack ${F_3D}ply_gridfile.txt -G${F_TOPO}dem.nc | gawk '
        @include "tectoplot_functions.awk"
        BEGIN {
          r=6371/100
        }
        ($3>0) {
          r=(6371+$3/1000)/100
          phi=deg2rad($1)
          theta=deg2rad(90-$2)
          print r*sin(theta)*cos(phi), r*sin(theta)*sin(phi), r*cos(theta), 255, 255, 255
        }' >> ${F_3D}tectoplot_surface.ply
    else
      # If no DEM exists, instead use a constant elevation shell equal to Earth's radius
      gawk < ${F_3D}ply_gridfile.txt '
      @include "tectoplot_functions.awk"
      BEGIN {
        r=6371/100
      }
      {
        phi=deg2rad($1)
        theta=deg2rad(90-$2)
        print r*sin(theta)*cos(phi), r*sin(theta)*sin(phi), r*cos(theta), 255, 255, 255
      }' >> ${F_3D}tectoplot_surface.ply
    fi
fi

# FLOAT_TEXT_STRING="1234"
# plyfloatingtextflag=1

# Another try at 3D floating text
if [[ $makeplyflag -eq 1 && $plyfloatingtextflag -eq 1 && $plydemonlyflag -eq 0 ]]; then
#  ${F_3D}floattext.dat contains lon lat elevation

echo "${PLY_FLOAT_TEXT_LON} ${PLY_FLOAT_TEXT_LAT} ${PLY_FLOAT_TEXT_DEPTH}" > ${F_3D}floattext.dat

${FLOAT_TEXT} ${PLY_FLOAT_TEXT_FONT_DIR} ${F_3D}sentence.obj ${PLY_FLOAT_TEXT_STRING}


# gawk < ${F_3D}sentence.obj -v v_exag=${PLY_VEXAG} -v text_lat=${PLY_FLOAT_TEXT_LAT} -v text_lon=${PLY_FLOAT_TEXT_LON} -v text_depth=${PLY_FLOAT_TEXT_DEPTH} -v text_scale=${PLY_FLOAT_TEXT_SCALE} '


# The problem with calculating from the extent of the text is that it changes as
# different letters are added to the string. We want to specify a fixed scaling of
# the text in terms of units/degree latitude. Then we don't need to rescale(), we
# just add x+lonscale, y

# New method: scale is the width (in longitude, degrees) of the floating text
# New method: scale is the width (in longitude, degrees) of the floating text

  gawk -v v_exag=${PLY_VEXAG} -v scale=${PLY_FLOAT_TEXT_SCALE} '
  @include "tectoplot_functions.awk"

  BEGIN {
    havematrix=0
    itemind=0
    sphereind=1
    vertexind=0
    v_scale=scale
    print "mtllib materials.mtl"
    minx=9999
    maxx=-9999
    miny=9999
    maxy=-9999
  }

    # First input file is the floating text OBJ

    (NR==FNR && substr($1,0,1) != "#" && $1 != "") {
      itemind++
      full[itemind]=$0
      for(ind=1;$(ind)!="";ind++) {
        obj[itemind][ind]=$(ind)
      }
      if ($1=="v") {
        maxx=($2>maxx)?$2:maxx
        minx=($2<minx)?$2:minx
        maxy=(-$4>maxy)?-$4:maxy
        miny=(-$4<miny)?-$4:miny
      }
      len[itemind]=ind-1
    }

    # Second input file is one or more points in the format
    # lon lat elev(m)

    (NR!=FNR) {

      depth=(6371-$3*v_exag)/100
      lon=$1
      lat=$2
      phi=deg2rad(lon)
      theta=deg2rad(90-lat)

      # xoff=depth*sin(theta)*cos(phi)
      # yoff=depth*sin(theta)*sin(phi)
      # zoff=depth*cos(theta)

      # This actually needs to be adjusted based on the latitude of the target site?
      # sdr_rotation_matrix(-90, lat, 0)
      # calc_ecef_to_enu_matrix(lon, lat)

      latscale=scale
      lonscale=scale*haversine_m(lon, lat, lon, lat+scale)/haversine_m(lon, lat, lon+scale, lat)
      print "latscale, lonscale:", latscale, lonscale > "/dev/stderr"
      # minlon=lon
      # maxlon=lon+scale
      # minlat=lat
      # maxlat=minlat+(maxy-miny)/(maxx-minx)*scale*haversine_m(minlon, minlat, maxlon, minlat)/haversine_m(minlon, minlat, minlon, minlat+scale)


      usedmtl=0
      print "o FloatText_" sphereind++
      vertexind=0
      for (this_ind in len) {
        if (obj[this_ind][1] == "v" || obj[this_ind][1] == "vn") {

          this_x=obj[this_ind][2]
          this_y=-obj[this_ind][4]
          this_z=obj[this_ind][3]

          # New approach: directly rescale x, y, z points to [lon, lon+dist] [lat, lat+val], depth
          # and then project points to X,Y,Z ECEF coordinates
          # (Will only work with 2D text for now)

          # print "rescale_lon: rescale_value(" this_x ", " minx " , " maxx " , " minlon " , " maxlon " )" > "/dev/stderr"
          # print "rescale_lat: rescale_value(" this_y ", " miny " , " maxy " , " minlat " , " maxlat " )" > "/dev/stderr"

          rescale_lon=lon+lonscale*this_x
          rescale_lat=lat+latscale*this_y

          #rescale_lon=rescale_value(this_x, minx, maxx, minlon, maxlon)
          #rescale_lat=rescale_value(this_y, miny, maxy, minlat, maxlat)

          # print "rescale_lon, this_x: " rescale_lon, this_x > "/dev/stderr"
          # print "rescale_lat, this_y: " rescale_lat, this_y > "/dev/stderr"

          rescale_lon_rad=deg2rad(rescale_lon)
          rescale_lat_rad=deg2rad(90-rescale_lat)

          # print "rescale_lon, rescale_lat = ", rescale_lon, rescale_lat > "/dev/stderr"

            x_new=depth*sin(rescale_lat_rad)*cos(rescale_lon_rad)
            y_new=depth*sin(rescale_lat_rad)*sin(rescale_lon_rad)
            z_new=depth*cos(rescale_lat_rad)
            #
            #
            # multiply_rotation_matrix(obj[this_ind][2], obj[this_ind][3], obj[this_ind][4])
            #
            #
            # # Reorient the text OBJ from geocentric to E/N/U coordinates
            # # multiply_ecef_matrix(obj[this_ind][2], obj[this_ind][3], obj[this_ind][4])
            #
            # multiply_ecef_matrix(v[0], v[1], v[2])
            #
            # # X=-w[1], Y=w[2], and Z=w[0]
            #
            #
            #
            if (obj[this_ind][1]=="v") {
            #   x_val=-w[1]*v_scale+xoff
            #   y_val=w[2]*v_scale+yoff
            #   z_val=w[0]*v_scale+zoff
            #
            #
            #   veclen=sqrt(x_val*x_val+y_val*y_val+z_val*z_val)
            #   if (obj[this_ind][3] == 0) {
            #     # If the point was a 0-level point on the font, it should be at the depth elevation
            #     x_val=x_val/veclen*depth
            #     y_val=y_val/veclen*depth
            #     z_val=z_val/veclen*depth
            #   } else {
            #     # If the point was not 0-level point on the font, it should be at the depth+depth/100 elevation
            #     x_val=x_val/veclen*(depth-1/100)
            #     y_val=y_val/veclen*(depth-1/100)
            #     z_val=z_val/veclen*(depth-1/100)
            #   }

              # Vertex color is pure white
              # print "v", -w[1]*v_scale+xoff, w[2]*v_scale+yoff, w[0]*v_scale+zoff, 255, 255, 255
              print "v", x_new, y_new, z_new, 255, 255, 255
              vertexind++
            }
            if (obj[this_ind][1]=="vn") {
              print "vn", x_new/depth, y_new/depth, z_new/depth
            }

        } else if (obj[this_ind][1]=="f") {
          if (usedmtl==0) {
            print "usemtl FloatingText"
            usedmtl=1
          }
          # Face vertices have to be incremented to account for prior floating text
          printf("f ")
          for (k=2; k<=len[this_ind]; k++) {
            printf("%d/%d/%d ", obj[this_ind][k]+lastvertexind,obj[this_ind][k]+lastvertexind,obj[this_ind][k]+lastvertexind)
          }
          printf("\n")
        } else if (obj[this_ind][1]=="vt") {

          printf("vt ")
          for (k=2; k<=len[this_ind]; k++) {
            printf("%s ", obj[this_ind][k])
          }
          printf("\n")
        }
      }
      # print lastvertexind, vertexind > "/dev/stderr"
      lastvertexind+=vertexind
    }
  ' ${F_3D}sentence.obj ${F_3D}floattext.dat > ${F_3D}floating_text.obj


# # Now add floating 3D text
# if [[ $makeplyflag -eq 1 && $plyfloatingtextflag -eq 1 && $plydemonlyflag -eq 0 ]]; then
#
# echo ${FLOAT_TEXT} ${PLY_FLOAT_TEXT_FONT_DIR} ${PLY_FLOAT_TEXT_STRING} ${F_3D}sentence.obj
#
# ${FLOAT_TEXT} ${PLY_FLOAT_TEXT_FONT_DIR} ${PLY_FLOAT_TEXT_STRING} ${F_3D}sentence.obj
#
# gawk < ${F_3D}sentence.obj -v v_exag=${PLY_VEXAG} -v text_lat=${PLY_FLOAT_TEXT_LAT} -v text_lon=${PLY_FLOAT_TEXT_LON} -v text_depth=${PLY_FLOAT_TEXT_DEPTH} -v text_scale=${PLY_FLOAT_TEXT_SCALE} '
# @include "tectoplot_functions.awk"
#
# BEGIN {
#   print "mtllib materials.mtl"
#   depth=(6371-text_depth*v_exag)/100
#   phi=deg2rad(text_lon)
#   theta=deg2rad(90-text_lat)
#
#   scale=(text_scale)
#
#   calc_ecef_to_enu_matrix(lon, lat)
#
#   # sdr_rotation_matrix(strike, dip, rake)
#   xoff=depth*sin(theta)*cos(phi)
#   yoff=depth*sin(theta)*sin(phi)
#   zoff=depth*cos(theta)
#   print "o FloatText"
#
# }
# {
#   vertexind=0
#   if ($1 == "v" || $1 == "vn") {
#
#       # $ Orient text
#       # multiply_rotation_matrix(obj[this_ind][2], obj[this_ind][3], obj[this_ind][4])
#
#       # Reorient the text from geocentric to E/N/U coordinates
#       multiply_ecef_matrix($2, $3, $4)
#
#       if ($1=="v") {
#         print "v", w[0]*scale+xoff, w[1]*scale+yoff, w[2]*scale+zoff
#         vertexind++
#       }
#       if ($1=="vn") {
#         print "vn", w[0], w[1], w[2]
#       }
#
#   } else if ($1=="f") {
#     if (usedmtl==0) {
#       print "usemtl FloatingText"
#       usedmtl=1
#     }
#     print
#   }
# }
# ' > ${F_3D}floating_text.obj

  # rm -f ${F_3D}sentence.obj

cat <<-EOF >> ${F_3D}materials.mtl
newmtl FloatingText
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 1.000000 1.000000 1.000000
Tr 1.0
illum 2
Ns 0.000000
EOF

fi

  # Now treat the focal mechanisms
if [[ $makeplyflag -eq 1 && -s ${CMTFILE} && $plydemonlyflag -eq 0 ]]; then

  # This function takes a normalized focal mechanism OBJ file and a tectoplot
  # format CMT file as arguments

  # Parameters set by -v:
  # cmttype           CENTROID or ORIGIN; determines position of FMS
  # v_exag            vertical exaggeration of seismicity (not topography)
  # eq_poly_scale     linear term for scaling focal mechanisms
  # eq_poly_pow       exponential term for scaling focal mechanisms

  PLY_POLYSCALE_FOC=$(echo "${PLY_SCALE} * ${PLY_POLYSCALE}" | bc -l)


  gawk -v cmttype=${CMTTYPE} -v v_exag=${PLY_VEXAG} -v eq_poly_scale=${PLY_POLYSCALE_FOC} -v eq_poly_pow=${PLY_POLYMAG_POWER} '
  @include "tectoplot_functions.awk"

  BEGIN {
    havematrix=0
    itemind=0
    sphereind=1
    vertexind=0
    print "mtllib materials.mtl"
  }

    # First input file is a template focal mechanism OBJ

    (NR==FNR && substr($1,0,1) != "#" && $1 != "") {
      itemind++
      full[itemind]=$0
      for(ind=1;$(ind)!="";ind++) {
        obj[itemind][ind]=$(ind)
      }
      len[itemind]=ind-1
    }

    # Second input file is CMT points in the format
    # lon lat depth mag strike dip rake

    (NR!=FNR) {

      if (cmttype=="CENTROID") {
        lon=$5; lat=$6; rawdepth=$7;
      } else {
        lon=$8; lat=$9; rawdepth=$10;
      }

      mag=$13
      strike=$16
      dip=$17
      rake=$18

      depth=(6371-rawdepth*v_exag)/100
      phi=deg2rad(lon)
      theta=deg2rad(90-lat)

      xoff=depth*sin(theta)*cos(phi)
      yoff=depth*sin(theta)*sin(phi)
      zoff=depth*cos(theta)
      scale=(eq_poly_scale*(mag ^ eq_poly_pow))

      calc_ecef_to_enu_matrix(lon, lat)
      sdr_rotation_matrix(strike, dip, rake)

      usedmtl=0
      print "o Focal_" sphereind++
      vertexind=0
      for (this_ind in len) {
        if (obj[this_ind][1] == "v" || obj[this_ind][1] == "vn") {

            $ Orient FMS
            multiply_rotation_matrix(obj[this_ind][2], obj[this_ind][3], obj[this_ind][4])

            # Reorient the FMS from geocentric to E/N/U coordinates
            multiply_ecef_matrix(v[0], v[1], v[2])

            if (obj[this_ind][1]=="v") {
              print "v", w[0]*scale+xoff, w[1]*scale+yoff, w[2]*scale+zoff
              vertexind++
            }
            if (obj[this_ind][1]=="vn") {
              print "vn", w[0], w[1], w[2]
            }

        } else if (obj[this_ind][1]=="f") {
          if (usedmtl==0) {
            print "usemtl FocalTexture"
            usedmtl=1
          }
          # Face vertices have to be incremented to account for prior spheres
          printf("f ")
          for (k=2; k<=len[this_ind]; k++) {
            printf("%d/%d/%d ", obj[this_ind][k]+lastvertexind,obj[this_ind][k]+lastvertexind,obj[this_ind][k]+lastvertexind)
          }
          printf("\n")
        } else if (obj[this_ind][1]=="vt") {

          printf("vt ")
          for (k=2; k<=len[this_ind]; k++) {
            printf("%s ", obj[this_ind][k])
          }
          printf("\n")
        }
      }
      # print lastvertexind, vertexind > "/dev/stderr"
      lastvertexind+=vertexind
    }
  ' ${FOCAL_NCUBE} ${CMTFILE} > ${F_3D}focal_mechanisms.obj

cat <<-EOF >> ${F_3D}materials.mtl
newmtl FocalTexture
Ka 0.200000 0.200000 0.200000
Kd 1.000000 1.000000 1.000000
Ks 1.000000 1.000000 1.000000
Tr 1.0
illum 2
Ns 0.000000
map_Ka Textures/focaltexture.jpg
map_Kd Textures/focaltexture.jpg
map_Ks Textures/focaltexture.jpg
EOF

  if [[ -s ${F_3D}focal_mechanisms.obj ]]; then
    # cp ${FOCAL_MATERIAL} ${F_3D}
    mkdir -p  ${F_3D}/Textures/
    cp ${FOCAL_TEXTURE} ${F_3D}/Textures/
    cp ${FOCAL_TEXTURE_DIM} ${F_3D}/Textures/
  fi

fi

# Now work on the seismicity data
if [[ $makeplyflag -eq 1 && -s ${F_SEIS}eqs.txt && $plydemonlyflag -eq 0 ]]; then
        # gmt grdtrack using the existing DEM
        numeqs=$(wc -l < ${F_SEIS}eqs.txt | gawk '{print $1}')
cat <<-EOF > ${F_3D}tectoplot_header.ply
ply
format ascii 1.0
element vertex ${numeqs}
property float x
property float y
property float z
property uchar red
property uchar green
property uchar blue
element material 1
property uchar ambient_red
property uchar ambient_green
property uchar ambient_blue
property float ambient_coeff
property uchar diffuse_red
property uchar diffuse_green
property uchar diffuse_blue
property float diffuse_coeff
property uchar specular_red
property uchar specular_green
property uchar specular_blue
property float specular_coeff
property float specular_power
property float opacity
end_header
EOF

      PLY_POLYSCALE_SEIS=$(echo "${PLY_SCALE} * ${PLY_POLYSCALE}" | bc -l)


      replace_gmt_colornames_rgb ${F_CPTS}seisdepth.cpt > ${F_CPTS}seisdepth_fixed.cpt
      gawk -v v_exag=${PLY_VEXAG} -v eq_polymag=${PLY_POLYMAG} -v eq_poly_scale=${PLY_POLYSCALE_SEIS} -v eq_poly_pow=${PLY_POLYMAG_POWER} '
      @include "tectoplot_functions.awk"
        BEGIN {
          colorind=0
          maxdepth="none"
        }
        (NR==FNR) {
          if ($1+0==$1) {
            minz[NR]=$1
            split($2, arr, "/")
            red[NR]=arr[1]
            green[NR]=arr[2]
            blue[NR]=arr[3]
            colorind=NR
          }
        }
        (NR!=FNR) {
          if (maxdepth == "none") {
            maxdepth=$3
          } else if ($3 > maxdepth) {
            maxdepth = $3
          }

          # Earthquake data comes in the format lon lat depth mag etc.

          phi=deg2rad($1)
          theta=deg2rad(90-$2)
          depth=(6371-$3*v_exag)/100

          for(i=1; i<= colorind; i++) {
            if (minz[i]<$3) {
              curcolor_ind=i
            } else {
              break
            }
          }

          if ($4 < eq_polymag) {
            print depth*sin(theta)*cos(phi), depth*sin(theta)*sin(phi), depth*cos(theta), red[curcolor_ind], green[curcolor_ind], blue[curcolor_ind]
          } else {
            print depth*sin(theta)*cos(phi), depth*sin(theta)*sin(phi), depth*cos(theta), (eq_poly_scale*($4 ^ eq_poly_pow)), red[curcolor_ind], green[curcolor_ind], blue[curcolor_ind] >> "./eq_polypts.txt"
          }
        }
        END {
          print maxdepth > "./eq_maxdepth.txt"
        }' ${F_CPTS}seisdepth_fixed.cpt ${F_SEIS}eqs.txt > ${F_3D}tectoplot_vertex.ply

        [[ -s eq_polypts.txt ]] && mv eq_polypts.txt ${F_3D}eq_polypts.txt

        # Replicate the polyhedra
        if [[ -s ${F_3D}eq_polypts.txt ]]; then
          echo "mtllib materials.mtl" > ${F_3D}eq_poly.obj
          ${REPLICATE_OBS} ${REPLICATE_SPHERE4} ${F_3D}eq_polypts.txt "SphereColor" >> ${F_3D}eq_poly.obj
        fi

cat <<-EOF >> ${F_3D}materials.mtl
newmtl SphereColor
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 1.0
illum 1
Ns 0.000000
EOF

        cat ${F_3D}tectoplot_header.ply ${F_3D}tectoplot_vertex.ply > ${F_3D}tectoplot.ply

        echo "255 255 255 0.3 255 255 255 0.4 255 255 255 0.6 0.4 ${PLY_PT_OPACITY}" >> ${F_3D}tectoplot.ply
fi

# Make the 3D mesh from topography

# If the grid is center-cell (pixel node) registered, we won't be able to make a complete
# global mesh as there will be a gap between e.g. 179.5 and -179.5. If it is
# gridline registered, we will have a gap between 179 and -180. How do I correctly
# generate the vertices, faces, and texture coordinates for the grid? Answer: I
# have to add a final column of vertices duplicating the first column, AND
# calculate the texture coordinates in a way that works...


# # Experiment to use gmt triangulate instead of using our own algorithm
# if [[ $makeplyflag -eq 1 && $makeplydemmeshflag -eq 1 && -s ${F_TOPO}dem.nc ]]; then
#   dem_orig_info=($(gmt grdinfo ${F_TOPO}dem.nc -C -Vn))
#   dem_orig_numx=${dem_orig_info[9]}
#   dem_orig_numy=${dem_orig_info[10]}
#
#   dem_orig_minlon=${dem_orig_info[1]}
#   dem_orig_maxlon=${dem_orig_info[2]}
#
#   if [[ $(echo "$dem_orig_minlon < -179 && $dem_orig_minlon > -181" | bc) -eq 1 ]]; then
#     if [[ $(echo "$dem_orig_maxlon > 179 && $dem_orig_maxlon < 181" | bc) -eq 1 ]]; then
#       # echo "Let's close the globe!"
#       closeglobeflag=1
#     fi
#   fi
#
#   if [[ $plymaxsizeflag -eq 1 ]]; then
#     #PLY_MAXSIZE
#     if [[ $(echo "${dem_orig_numx} > ${PLY_MAXSIZE}" | bc) -eq 1 ]]; then
#       PERCENTRED=$(echo "${PLY_MAXSIZE} / $dem_orig_numx * 100" | bc -l)
#       info_msg "[-makeply]: Reducing DEM by ${PERCENTRED}"
#       gdal_translate -q -of "netCDF" -r bilinear -outsize ${PERCENTRED}"%" 0 ${F_TOPO}dem.nc ${F_TOPO}dem_plyrescale.nc
#       dem_info=($(gmt grdinfo ${F_TOPO}dem_plyrescale.nc -C -Vn))
#       dem_numx=${dem_info[9]}
#       dem_numy=${dem_info[10]}
#       # info_msg "[-makeply]: New size is", $dem_numx, $dem_numy
#       PLY_DEM=${F_TOPO}dem_plyrescale.nc
#     else
#       PLY_DEM=${F_TOPO}dem.nc
#       dem_numx=${dem_orig_numx}
#       dem_numy=${dem_orig_numy}
#     fi
#   else
#     PLY_DEM=${F_TOPO}dem.nc
#     dem_numx=${dem_orig_numx}
#     dem_numy=${dem_orig_numy}
#   fi
#
#   gmt grd2xyz ${PLY_DEM} -C ${VERBOSE} > ${F_TOPO}dem_indices.txt
#   gmt grd2xyz ${PLY_DEM} ${VERBOSE} > ${F_TOPO}dem_values.txt
# fi
#

if [[ $makeplyflag -eq 1 && $makeplydemmeshflag -eq 1 && -s ${F_TOPO}dem.nc ]]; then
  info_msg "[-makeply]: Using DEM to create a mesh"
        # Now convert the DEM to an OBJ format surface at the same scaling factor
        # Default format is scanline orientation of ASCII numbers: −ZTLa. Note that −Z only applies to 1-column output.

        dem_orig_info=($(gmt grdinfo ${F_TOPO}dem.nc -C -Vn))
        dem_orig_numx=${dem_orig_info[9]}
        dem_orig_numy=${dem_orig_info[10]}

        dem_orig_minlon=${dem_orig_info[1]}
        dem_orig_maxlon=${dem_orig_info[2]}

        if [[ $(echo "$dem_orig_minlon < -179 && $dem_orig_minlon > -181" | bc) -eq 1 ]]; then
          if [[ $(echo "$dem_orig_maxlon > 179 && $dem_orig_maxlon < 181" | bc) -eq 1 ]]; then
            # echo "Let's close the globe!"
            closeglobeflag=1
          fi
        fi

        if [[ $plymaxsizeflag -eq 1 ]]; then
          #PLY_MAXSIZE
          if [[ $(echo "${dem_orig_numx} > ${PLY_MAXSIZE}" | bc) -eq 1 ]]; then
            PERCENTRED=$(echo "${PLY_MAXSIZE} / $dem_orig_numx * 100" | bc -l)
            info_msg "[-makeply]: Reducing DEM by ${PERCENTRED}"
            gdal_translate -q -of "netCDF" -r bilinear -outsize ${PERCENTRED}"%" 0 ${F_TOPO}dem.nc ${F_TOPO}dem_plyrescale.nc
            dem_info=($(gmt grdinfo ${F_TOPO}dem_plyrescale.nc -C -Vn))
            dem_numx=${dem_info[9]}
            dem_numy=${dem_info[10]}
            # info_msg "[-makeply]: New size is", $dem_numx, $dem_numy
            PLY_DEM=${F_TOPO}dem_plyrescale.nc
          else
            PLY_DEM=${F_TOPO}dem.nc
            dem_numx=${dem_orig_numx}
            dem_numy=${dem_orig_numy}
          fi
        else
          PLY_DEM=${F_TOPO}dem.nc
          dem_numx=${dem_orig_numx}
          dem_numy=${dem_orig_numy}
        fi

        gmt grd2xyz ${PLY_DEM} -C ${VERBOSE} > ${F_TOPO}dem_indices.txt
        gmt grd2xyz ${PLY_DEM} ${VERBOSE} > ${F_TOPO}dem_values.txt

        replace_gmt_colornames_rgb ${F_CPTS}topo.cpt > ${F_CPTS}topo_fixed.cpt

        # We are currently only using the texturing approach even though we
        # have retained the CPT face coloring approach. The texturing is actually
        # nicer and faster as we can subsample the DEM to make a coarse mesh now.

        # The texture file will be the shaded relief which has the same dimensions
        # as the DEM, so we can output vt coordinates easily.

        # I need to modify this so that vectorx[i] etc are UNIT SPHERE coordinates
        # and then output them scaled by 1) topo height, 2) Earth radius (ocean height),
        # 3) box bottom radius

        MAP_PS_DIM=($(gmt psconvert base_fake.ps -Te -A0.01i -V 2> >(grep Width) | gawk  -F'[ []' '{print $10, $17}'))

        # echo "Going in with map_lat_in=${MAP_PS_DIM[0]} -v map_lon_in=${MAP_PS_DIM[1]}"
# echo "gawk -v axestext=${PLY_SIDEBOXTEXT} -v axesflag=${PLY_SIDEBOXINTERVAL_SPECIFY} -v axesvert=${PLY_SIDEBOXINTERVAL_VERT} -v axeshorz=${PLY_SIDEBOXINTERVAL_HORZ}"

        gawk -v axestext=${PLY_SIDEBOXTEXT} -v axesflag=${PLY_SIDEBOXINTERVAL_SPECIFY} -v axesvert=${PLY_SIDEBOXINTERVAL_VERT} -v axeshorz=${PLY_SIDEBOXINTERVAL_HORZ} -v map_lat_in=${MAP_PS_DIM[0]} -v map_lon_in=${MAP_PS_DIM[1]} -v mtlname=${PLY_MTLNAME} -v zoffset=${PLY_ZOFFSET} -v v_exag=${PLY_VEXAG_TOPO} -v v_exag_data=${PLY_VEXAG} -v width=${dem_numx} -v height=${dem_numy} -v closeglobe=${closeglobeflag} -v makeocean=${plymakeoceanflag} -v makebox=${plysideboxflag} -v boxdepth=${PLY_SIDEBOXDEPTH} -v boxcolor=${PLY_SIDEBOXCOLOR} '
        @include "tectoplot_functions.awk"
           BEGIN {
             colorind=0
             vertexind=1
             # Set up the material file
             print "mtllib materials.mtl"
             minphi="none"
             maxphi="none"
             mintheta="none"
             maxtheta="none"

             if (axesflag+0==1) {
               axesvertcommand=sprintf(" -Bya%sf", axesvert*1000)
               axeshorzcommand=sprintf(" -Bxa%sf", axeshorz)
             } else {
               axesvertcommand=" -Byaf"
               axeshorzcommand=" -Bxaf"
             }

             if (axestext+0==1) {
               axescommand=sprintf("-BWES%s%s", axeshorzcommand, axesvertcommand)
             } else {
               axescommand="-Btlbr"
             }
           }

           # Read the CPT file first

           (NR==FNR) {
             if ($1+0==$1) {
               minz[NR]=$1
               split($2, arr, "/")
               red[NR]=arr[1]
               green[NR]=arr[2]
               blue[NR]=arr[3]
               colorind=NR
             }
           }

           # Read the vertices (DEM grid points) second
         (NR!=FNR) {
           if (minphi == "none") {
             minphi = $1
           } else if (minphi > $1) {
             minphi = $1
           }
           if (maxphi == "none") {
             maxphi = $1
           } else if (maxphi < $1) {
             maxphi = $1
           }

           if (mintheta == "none") {
             mintheta = $2
           } else if (mintheta > $2) {
             mintheta = $2
           }
           if (maxtheta == "none") {
             maxtheta = $2
           } else if (maxtheta < $2) {
             maxtheta = $2
           }


           if (closeglobe == 1) {
             if (vector_phi[i]==minphi) {
               vector_phi[i]=-180
             }
             if (vector_phi[i]==maxphi) {
               vector_phi[i]=180
             }
             if (vector_co_theta[i]==mintheta) {
               vector_co_theta[i]=-90
             }
             if (vector_co_theta[i]==maxtheta) {
               vector_co_theta[i]=90
             }
           }

           # Calculating the color index takes a long time for many vertices
           # and we are not currently using it... so comment out the following lines

           # for(i=1; i<= colorind; i++) {
           #   if (minz[i]<$3) {
           #     vertexcolor[vertexind]=i
           #   } else {
           #     break
           #   }
           # }

           phi=deg2rad($1)
           theta=deg2rad(90-$2)
           elev[vertexind]=$3
           r=(6371+zoffset+elev[vertexind]/1000*v_exag)/100

           # Calculate the vector for each vertex (center of Earth to vertex point)
           # vectorx[vertexind]=r*sin(theta)*cos(phi)
           # vectory[vertexind]=r*sin(theta)*sin(phi)
           # vectorz[vertexind]=r*cos(theta)
           vectorx[vertexind]=sin(theta)*cos(phi)
           vectory[vertexind]=sin(theta)*sin(phi)
           vectorz[vertexind]=cos(theta)

           phiarr[vertexind]=$1
           thetaarr[vertexind]=$2
           rarr[vertexind]=(6371+zoffset+elev[vertexind]/1000*v_exag)/100

           vertexind++
         }
         END {

           seacolor="0/105/148"
           # seacolor comes in as an R/G/B string
           split(seacolor, seac, "/")
           colorsea=sprintf("%d %d %d", seac[1], seac[2], seac[3])
           sealevel=6371/100
           bottomlevel=(6371+zoffset-boxdepth*v_exag_data)/100

           # This is for the topo mesh itself

           # Calculate the vertex x and y positions. They are ordered from
           # 0...width and 0...height.

           num_vertices=width*height
           for (i=0; i<=num_vertices; i++) {
             x_arr[i] = i % width
             y_arr[i] = int(i/width)
             vertex_num[x_arr[i],y_arr[i]]=i

            # Due to the grid being cell center registered, we need to adjust the
            # edges to close a global grid at the antimeridan and poles

             if (closeglobe==1) {
               if (phiarr[i]==minphi) {
                 # print "fixing phi=" phiarr[i] "at position", x_arr[i], y_arr[i] > "/dev/stderr"
                 phi=deg2rad(-180)
                 theta=deg2rad(90-thetaarr[i])
                 # vectorx[i]=rarr[i]*sin(theta)*cos(phi)
                 # vectory[i]=rarr[i]*sin(theta)*sin(phi)
                 # vectorz[i]=rarr[i]*cos(theta)
                 vectorx[i]=sin(theta)*cos(phi)
                 vectory[i]=sin(theta)*sin(phi)
                 vectorz[i]=cos(theta)
               }
               if (phiarr[i]==maxphi) {
                 # print "fixing phi=" phiarr[i] "at position", x_arr[i], y_arr[i] > "/dev/stderr"
                 phi=deg2rad(180)
                 theta=deg2rad(90-thetaarr[i])
                 # vectorx[i]=rarr[i]*sin(theta)*cos(phi)
                 # vectory[i]=rarr[i]*sin(theta)*sin(phi)
                 # vectorz[i]=rarr[i]*cos(theta)
                 vectorx[i]=sin(theta)*cos(phi)
                 vectory[i]=sin(theta)*sin(phi)
                 vectorz[i]=cos(theta)
               }
             }

           }

           # BEGIN topo mesh output
           print "o TopoMesh"

           for (i=1; i<=num_vertices; i++) {

             # The following line places the color index for each vertex... comment out for now
             # print "v", vectorx[i], vectory[i], vectorz[i], red[vertexcolor[i]], green[vertexcolor[i]], blue[vertexcolor[i]]
             # print "v", vectorx[i], vectory[i], vectorz[i]
             print "v", rarr[i]*vectorx[i], rarr[i]*vectory[i], rarr[i]*vectorz[i]
           }

           # Calculate the vertex normals

           for (i=1; i<=num_vertices; i++) {
             num_normals=0

             # Find the indices of the vertices surrounding each vertex
             # If we are on an edge, vertex_num for some of these will be wrong!

             tl = vertex_num[x_arr[i]-1,y_arr[i]-1]
             tc = vertex_num[x_arr[i],y_arr[i]-1]
             tr = vertex_num[x_arr[i]+1,y_arr[i]-1]
             cr = vertex_num[x_arr[i]+1,y_arr[i]]
             cl = vertex_num[x_arr[i]-1,y_arr[i]]
             bl = vertex_num[x_arr[i]-1,y_arr[i]+1]
             bc = vertex_num[x_arr[i],y_arr[i]+1]
             br = vertex_num[x_arr[i]+1,y_arr[i]+1]

             # if we are not along the lower or right edge

             if (x_arr[i] > 0 && y_arr[i] > 0 && x_arr[i] < width-1 && y_arr[i] < height-1) {
               # print width, height, x_arr[i], y_arr[i], cr, i, ":", rarr[cr]*vectorx[cr],rarr[cr]*vectory[cr],rarr[cr]*vectorz[cr], "cross", rarr[i]*vectorx[i],rarr[i]*vectory[i],rarr[i]*vectorz[i] > "/dev/stderr"

               # Note: we currently are only using one arbitrarily chosen normal direction for
               # each interior point, and the normal to the sphere for edge points.

               # This should be extended to be an average normal of surrounding faces

                 # Normal is (cr-i) x (bc-i)
                 # (cr - i)
                 v_subtract(rarr[cr]*vectorx[cr],rarr[cr]*vectory[cr],rarr[cr]*vectorz[cr],rarr[i]*vectorx[i],rarr[i]*vectory[i],rarr[i]*vectorz[i])
                 r_tmp_1=w_sub_1; r_tmp_2=w_sub_2; r_tmp_3=w_sub_3
                 # (br - i)
                 v_subtract(rarr[bc]*vectorx[bc],rarr[bc]*vectory[bc],rarr[bc]*vectorz[bc],rarr[i]*vectorx[i],rarr[i]*vectory[i],rarr[i]*vectorz[i])
                 # (cr - i) x (br - i)
                 v_cross(r_tmp_1,r_tmp_2,r_tmp_3,w_sub_1,w_sub_2,w_sub_3)
                 print "vn", w_cross_1, w_cross_2, w_cross_3

             } else {
                 # print "vector (" i "):", vectorx[i], vectory[i], vectorz[i] > "/dev/stderr"

                 # vectorlen is now just rarr[i] because vectorx... are unit vectors
                 # vectorlen=sqrt(vectorx[i]*vectorx[i]+vectory[i]*vectory[i]+vectorz[i]*vectorz[i])
                 # print "vn", -vectorx[i]/vectorlen, -vectory[i]/vectorlen, -vectorz[i]/vectorlen
                 print "vn", -vectorx[i]/rarr[i], -vectory[i]/rarr[i], -vectorz[i]/rarr[i]
             }

           }

           # Print out the texture coordinates
           # We have to use a UV mapping approach where switch X,Y and multiply
           # Y by -1 in order to rotate the texture 90 degrees; this is to match
           # the 90 degree rotation done to align the PLY data and OBJ mesh

          texturecount=0
           for (y_ind=0; y_ind<height; y_ind++) {
             for (x_ind=0; x_ind<width; x_ind++) {
               print "vt", width/(width-1)*(x_ind / width),  height/(height-1)*(-1 * y_ind / height)
               texturecount++
             }
           }
           # print "Output", num_vertices, "vertex/normal/texture points" > "/dev/stderr"
           # print "Width:", width, "  Height:", height > "/dev/stderr"

           #
           print "usemtl", mtlname

           # Output two faces per vertex, except for the y=height and y=width
           # vertices which define the lower and right edge.
           facecount=0
           for (y_ind=0; y_ind<height-1; y_ind++) {
             for (x_ind=0; x_ind<width-1; x_ind++) {
               tl = 1 + (width*y_ind)+x_ind
               tr = tl + 1
               bl = tl + width
               br = bl + 1
               # Clockwise order for faces
               print "f", tl "/" tl "/" tl, tr "/" tr "/" tr, bl "/" bl "/" bl
               print "f", tr "/" tr "/" tr, br "/" br "/" br, bl "/" bl "/" bl
               facecount+=2
             }
           }
           # print "Faces output:", facecount > "/dev/stderr"

           # END of topo mesh output

           if (makeocean==1) {
               # BEGIN ocean mesh output
               print "mtllib materials.mtl" > "./oceantop.obj"
               print "o OceanMesh" > "./oceantop.obj"
               print "usemtl OceanTop" > "./oceantop.obj"

               for (i=1; i<=num_vertices; i++) {

                 # The following line places the color index for each vertex... comment out for now
                 # print "v", vectorx[i], vectory[i], vectorz[i], red[vertexcolor[i]], green[vertexcolor[i]], blue[vertexcolor[i]]
                 # print "v", vectorx[i], vectory[i], vectorz[i]
                 print "v", sealevel*vectorx[i], sealevel*vectory[i],sealevel*vectorz[i], colorsea > "./oceantop.obj"
               }

               # calc_ecef_to_enu_matrix(phiarr[1], thetaarr[1])
               # multiply_ecef_matrix(0, 1, 0)
               # upnormal=sprintf("vn %f %f %f", w[1], w[2], w[3])

               # Calculate the vertex normals
               # This is not really needed for sea level and could be replaced by Earth surface normal

               for (i=1; i<=num_vertices; i++) {
                 print "vn", -vectorx[i], -vectory[i], -vectorz[i] > "./oceantop.obj"
                 #
                 #
                 # # num_normals=0
                 #
                 # # Find the indices of the vertices surrounding each vertex
                 # # If we are on an edge, vertex_num for some of these will be wrong!
                 #
                 # tl = vertex_num[x_arr[i]-1,y_arr[i]-1]
                 # tc = vertex_num[x_arr[i],y_arr[i]-1]
                 # tr = vertex_num[x_arr[i]+1,y_arr[i]-1]
                 # cr = vertex_num[x_arr[i]+1,y_arr[i]]
                 # cl = vertex_num[x_arr[i]-1,y_arr[i]]
                 # bl = vertex_num[x_arr[i]-1,y_arr[i]+1]
                 # bc = vertex_num[x_arr[i],y_arr[i]+1]
                 # br = vertex_num[x_arr[i]+1,y_arr[i]+1]
                 #
                 # # if we are not along the lower or right edge
                 #
                 # if (x_arr[i] > 0 && y_arr[i] > 0 && x_arr[i] < width-1 && y_arr[i] < height-1) {
                 #   # print width, height, x_arr[i], y_arr[i], cr, i, ":", sealevel*vectorx[cr],sealevel*vectory[cr],sealevel*vectorz[cr], "cross", sealevel*vectorx[i],sealevel*vectory[i],sealevel*vectorz[i] > "/dev/stderr"
                 #
                 #   # Note: we currently are only using one arbitrarily chosen normal direction for
                 #   # each interior point, and the normal to the sphere for edge points.
                 #
                 #   # This should be extended to be an average normal of surrounding faces
                 #
                 #     # Normal is (cr-i) x (bc-i)
                 #     # (cr - i)
                 #     v_subtract(sealevel*vectorx[cr],sealevel*vectory[cr],sealevel*vectorz[cr],sealevel*vectorx[i],sealevel*vectory[i],sealevel*vectorz[i])
                 #     r_tmp_1=w_sub_1; r_tmp_2=w_sub_2; r_tmp_3=w_sub_3
                 #     # (br - i)
                 #     v_subtract(sealevel*vectorx[bc],sealevel*vectory[bc],sealevel*vectorz[bc],sealevel*vectorx[i],sealevel*vectory[i],sealevel*vectorz[i])
                 #     # (cr - i) x (br - i)
                 #     v_cross(r_tmp_1,r_tmp_2,r_tmp_3,w_sub_1,w_sub_2,w_sub_3)
                 #     print "vn", w_cross_1, w_cross_2, w_cross_3 > "./oceantop.obj"
                 # } else {
                 #     # print "vector (" i "):", vectorx[i], vectory[i], vectorz[i] > "/dev/stderr"
                 #
                 #     # vectorlen is now just rarr[i] because vectorx... are unit vectors
                 #     # vectorlen=sqrt(vectorx[i]*vectorx[i]+vectory[i]*vectory[i]+vectorz[i]*vectorz[i])
                 #     # print "vn", -vectorx[i]/vectorlen, -vectory[i]/vectorlen, -vectorz[i]/vectorlen
                 #     print "vn", -vectorx[i]/sealevel, -vectory[i]/sealevel, -vectorz[i]/sealevel > "./oceantop.obj"
                 #
                 # }

               }

              #  # Print out the texture coordinates
              #  # We have to use a UV mapping approach where switch X,Y and multiply
              #  # Y by -1 in order to rotate the texture 90 degrees; this is to match
              #  # the 90 degree rotation done to align the PLY data and OBJ mesh
              #
              # texturecount=0
              #  for (y_ind=0; y_ind<height; y_ind++) {
              #    for (x_ind=0; x_ind<width; x_ind++) {
              #      print "vt", width/(width-1)*(x_ind / width),  height/(height-1)*(-1 * y_ind / height) > "./oceantop.obj"
              #      texturecount++
              #    }
              #  }
               # print "Output", num_vertices, "vertex/normal/texture points" > "/dev/stderr"
               # print "Width:", width, "  Height:", height > "/dev/stderr"

               #
               # print "usemtl", mtlname

               # Output two faces per vertex, except for the y=height and y=width
               # vertices which define the lower and right edge.
               facecount=0
               for (y_ind=0; y_ind<height-1; y_ind++) {
                 for (x_ind=0; x_ind<width-1; x_ind++) {
                   tl = 1 + (width*y_ind)+x_ind
                   tr = tl + 1
                   bl = tl + width
                   br = bl + 1
                   # Clockwise order for faces
                   print "f", tl "/" tl "/" tl, tr "/" tr "/" tr, bl "/" bl "/" bl > "./oceantop.obj"
                   print "f", tr "/" tr "/" tr, br "/" br "/" br, bl "/" bl "/" bl > "./oceantop.obj"
                   facecount+=2
                 }
               }
               # print "Faces output:", facecount > "/dev/stderr"

               # END of ocean top mesh output
          } # if (makeocean==1)



           # Output the corners and boundary of the DEM for the AOI box

           ind_ul=1
           ind_ur=width
           ind_ll=width*(height-1)+1
           ind_lr=num_vertices

           # Write the corners
           print "# Corners: UL, LL, LR, UR"  >> "./dem_corners.txt"

           print phiarr[ind_ul], thetaarr[ind_ul], rarr[ind_ul] >> "./dem_corners.txt"
           print phiarr[ind_ll], thetaarr[ind_ll], rarr[ind_ll] >> "./dem_corners.txt"
           print phiarr[ind_lr], thetaarr[ind_lr], rarr[ind_lr] >> "./dem_corners.txt"
           print phiarr[ind_ur], thetaarr[ind_ur], rarr[ind_ur] >> "./dem_corners.txt"

           # write the top row in normal order

           # For subsampling

           subsampleflag=0

           wstep=int(width/10)
           hstep=int(height/10)

           print "# Upper row, left to right"  >> "./dem_corners.txt"
           print phiarr[ind_ul], thetaarr[ind_ul], rarr[ind_ul] >> "./dem_corners.txt"
           for(i=ind_ul;i<=ind_ur;i++) {
             if (subsampleflag==1) {
               if (i%wstep==0) {
                 print phiarr[i], thetaarr[i], rarr[i] >> "./dem_corners.txt"
               }
             }
             else {
                print phiarr[i], thetaarr[i], rarr[i] >> "./dem_corners.txt"
             }
           }
           print phiarr[ind_ur], thetaarr[ind_ur], rarr[ind_ur] >> "./dem_corners.txt"

           print "# Right column, upper to lower"  >> "./dem_corners.txt"
           for (i=ind_ur;i<=ind_lr;i+=width) {
             if (subsampleflag==1) {
               if (i%hstep==0) {
                 print phiarr[i], thetaarr[i], rarr[i] >> "./dem_corners.txt"
               }
             }
             else {
                print phiarr[i], thetaarr[i], rarr[i] >> "./dem_corners.txt"
             }
           }
           print phiarr[ind_lr], thetaarr[ind_lr], rarr[ind_lr] >> "./dem_corners.txt"

           print "# Lower row, right to left"  >> "./dem_corners.txt"
           for (i=ind_lr;i>=ind_ll;i-=1) {
             if (subsampleflag==1) {
               if (i%wstep==0) {
                 print phiarr[i], thetaarr[i], rarr[i] >> "./dem_corners.txt"
               }
             }
             else {
                print phiarr[i], thetaarr[i], rarr[i] >> "./dem_corners.txt"
             }

           }
           print phiarr[ind_ll], thetaarr[ind_ll], rarr[ind_ll] >> "./dem_corners.txt"

           print "# Left column, lower to upper"  >> "./dem_corners.txt"
           for (i=ind_ll;i>=ind_ul;i-=width) {
             if (subsampleflag==1) {
               if (i%hstep==0) {
                 print phiarr[i], thetaarr[i], rarr[i] >> "./dem_corners.txt"
               }
             }
             else {
                print phiarr[i], thetaarr[i], rarr[i] >> "./dem_corners.txt"
             }
           }
           print phiarr[ind_ul], thetaarr[ind_ul], rarr[ind_ul] >> "./dem_corners.txt"


           # Optionally, write an OBJ file for the sides of the box

           if (makebox==1) {

             calc_ecef_to_enu_matrix(phiarr[1], thetaarr[1])
             multiply_ecef_matrix(-1, 0, 0)
             eastnormal=sprintf("vn %f %f %f", w[1], w[2], w[3])
             multiply_ecef_matrix(1, 0, 0)
             westnormal=sprintf("vn %f %f %f", w[1], w[2], w[3])
             multiply_ecef_matrix(0, -1, 0)
             northnormal=sprintf("vn %f %f %f", w[1], w[2], w[3])
             multiply_ecef_matrix(0, 1, 0)
             southnormal=sprintf("vn %f %f %f", w[1], w[2], w[3])

             # boxcolor comes in as an R/G/B string
             split(boxcolor, boxc, "/")
             colorrgb=sprintf("%d %d %d", boxc[1], boxc[2], boxc[3])


### Output north edge of the box


             print "mtllib materials.mtl" > "./sideboxnorth.obj"
             print "o SideBoxNorth" >> "./sideboxnorth.obj"
             print "usemtl SideBoxNorth" >> "./sideboxnorth.obj"

             cur_vertex=1

# --- new
            edge_max_ind=ind_ul
            for(i=ind_ul;i<=ind_ur;i++) {
              edge_max_ind=(rarr[i]>rarr[edge_max_ind])?i:edge_max_ind
            }
            edge_max=rarr[edge_max_ind]
            elev_max=elev[edge_max_ind]
# --- /new

             for(i=ind_ul;i<=ind_ur;i++) {
                northedgeind[cur_vertex]=cur_vertex
                cur_vertex++
                # print "v", vectorx[i], vectory[i], vectorz[i], colorrgb >> "./sideboxnorth.obj"
                print "v", rarr[i]*vectorx[i], rarr[i]*vectory[i], rarr[i]*vectorz[i], colorrgb >> "./sideboxnorth.obj"
                print northnormal >> "./sideboxnorth.obj"
# --- new
                print "vt", (width-(cur_vertex-1))/(width-1), 1+(rarr[i]-edge_max)/(edge_max-bottomlevel) >> "./sideboxnorth.obj"
                print phiarr[i], elev[i] > "./sideboxnorth_topo.txt"
# --- /new
             }
             half_vertex=cur_vertex-1
             for(i=ind_ur;i>=ind_ul;i--) {
                northedgeind[cur_vertex]=cur_vertex
                cur_vertex++
                print "v", bottomlevel*vectorx[i], bottomlevel*vectory[i], bottomlevel*vectorz[i], colorrgb >> "./sideboxnorth.obj"
                print northnormal >> "./sideboxnorth.obj"
# --- new
                print "vt", 1-(2*width-(cur_vertex-1))/(width-1), 0 >> "./sideboxnorth.obj"
# --- /new
             }
             for(i=1;i<half_vertex;i++) {
               j=cur_vertex-i
# --- new
               printf("f %d/%d/%d %d/%d/%d %d/%d/%d %d/%d/%d\n", northedgeind[i],  northedgeind[i], northedgeind[i], northedgeind[i+1],  northedgeind[i+1], northedgeind[i+1], northedgeind[j-1],  northedgeind[j-1], northedgeind[j-1], northedgeind[j], northedgeind[j], northedgeind[j]) >> "./sideboxnorth.obj"
# --- /new
               # Old # printf("f %d %d %d %d\n", northedgeind[i],  northedgeind[i+1],  northedgeind[j-1],  northedgeind[j]) >> "./sideboxnorth.obj"
             }

# --- new

            dist_lon_m=haversine_m(phiarr[ind_ul], thetaarr[ind_ul], phiarr[ind_ur], thetaarr[ind_ur])
        #    (thetaarr[ind_ur]-thetaarr[ind_lr])*111132
            # map_lat_in=10

            # print "north dist_lon_m:", dist_lon_m > "/dev/stderr"
            height_in=(elev_max + boxdepth*1000)/dist_lon_m*map_lon_in
# Note the -JX- which flips the X axis of the profile
            print "gmt psxy sideboxnorth_topo.txt -R" phiarr[ind_ul] "/" phiarr[ind_ur] "/" boxdepth*-1000 "/" elev_max " -JX-" map_lon_in "i/" height_in "i ", axescommand, " --MAP_FRAME_TYPE=inside --PS_PAGE_COLOR=" boxcolor " > sidenorth.ps" >> "./make_side.sh"
            print "gmt psconvert -Tg -A+m0i sidenorth.ps" >> "./make_side.sh"
            print "mv sidenorth.png 3d/Textures/SideboxNorth.png" >> "./make_side.sh"
# --- /new



#### Output the east side of the box

             print "mtllib materials.mtl" > "./sideboxeast.obj"
             print "o SideBoxEast" >> "./sideboxeast.obj"
             print "usemtl SideBoxEast" >> "./sideboxeast.obj"

             cur_vertex=1

# --- new
             edge_max_ind=ind_ur
             for(i=ind_ur;i<=ind_lr;i+=width) {
               edge_max_ind=(rarr[i]>rarr[edge_max_ind])?i:edge_max_ind
             }
             edge_max=rarr[edge_max_ind]
             elev_max=elev[edge_max_ind]
# --- /new
             for(i=ind_ur;i<=ind_lr;i+=width) {
                eastedgeind[cur_vertex]=cur_vertex
                cur_vertex++
                # print "v", vectorx[i], vectory[i], vectorz[i], colorrgb >> "./sideboxeast.obj"
                print "v", rarr[i]*vectorx[i], rarr[i]*vectory[i], rarr[i]*vectorz[i], colorrgb >> "./sideboxeast.obj"
                print eastnormal >> "./sideboxeast.obj"
# --- new
                print "vt", (height-(cur_vertex-1))/(height-1), 1+(rarr[i]-edge_max)/(edge_max-bottomlevel) >> "./sideboxeast.obj"
                print thetaarr[i], elev[i] > "./sideboxeast_topo.txt"
# --- /new

             }
             half_vertex=cur_vertex-1
             for(i=ind_lr;i>=ind_ur;i-=width) {
                eastedgeind[cur_vertex]=cur_vertex
                cur_vertex++
                print "v", bottomlevel*vectorx[i], bottomlevel*vectory[i], bottomlevel*vectorz[i], colorrgb >> "./sideboxeast.obj"
                # print "v", bottomlevel*vectorx[i], bottomlevel*vectory[i], bottomlevel*vectorz[i]  >> "./sideboxeast.obj"
                print eastnormal >> "./sideboxeast.obj"
# --- new
                print "vt", 1-(2*height-(cur_vertex-1))/(height-1), 0 >> "./sideboxeast.obj"
# --- /new
             }
             for(i=1;i<half_vertex;i++) {
               j=cur_vertex-i
# --- new
               printf("f %d/%d/%d %d/%d/%d %d/%d/%d %d/%d/%d\n", eastedgeind[i],  eastedgeind[i], eastedgeind[i], eastedgeind[i+1],  eastedgeind[i+1], eastedgeind[i+1], eastedgeind[j-1],  eastedgeind[j-1], eastedgeind[j-1], eastedgeind[j], eastedgeind[j], eastedgeind[j]) >> "./sideboxeast.obj"
# --- /new
             }

# --- new

             dist_lat_m=haversine_m(phiarr[ind_ur], thetaarr[ind_ur], phiarr[ind_lr], thetaarr[ind_lr])
             # print "east dist_lat_m:", dist_lat_m > "/dev/stderr"

             # dist_lat_m=(thetaarr[ind_ur]-thetaarr[ind_lr])*111132
             # map_lat_in=10

             height_in=(elev_max + boxdepth*1000)/dist_lat_m*map_lat_in

             print "gmt psxy sideboxeast_topo.txt -R" thetaarr[ind_lr] "/" thetaarr[ind_ur] "/" boxdepth*-1000 "/" elev_max " -JX" map_lat_in "i/" height_in "i ", axescommand, " --MAP_FRAME_TYPE=inside --PS_PAGE_COLOR=" boxcolor " > sideeast.ps" > "./make_side.sh"
             print "gmt psconvert -Tg -A+m0i sideeast.ps" >> "./make_side.sh"
             print "mv sideeast.png 3d/Textures/SideboxEast.png" >> "./make_side.sh"
# --- /new

# Output the south side of the box


             print "mtllib materials.mtl" > "./sideboxsouth.obj"
             print "o SideBoxSouth" >> "./sideboxsouth.obj"
             print "usemtl SideBoxSouth" >> "./sideboxsouth.obj"

             cur_vertex=1

# --- new
           edge_max_ind=ind_ul
           for(i=ind_lr;i>=ind_ll;i--) {
             edge_max_ind=(rarr[i]>rarr[edge_max_ind])?i:edge_max_ind
           }
           edge_max=rarr[edge_max_ind]
           elev_max=elev[edge_max_ind]
# --- /new


             for(i=ind_lr;i>=ind_ll;i-=1) {
                southedgeind[cur_vertex]=cur_vertex
                cur_vertex++
                # print "v", vectorx[i], vectory[i], vectorz[i], colorrgb >> "./sideboxsouth.obj"
                print "v", rarr[i]*vectorx[i], rarr[i]*vectory[i], rarr[i]*vectorz[i], colorrgb >> "./sideboxsouth.obj"
                print southnormal >> "./sideboxsouth.obj"
# --- new
                print "vt", (width-(cur_vertex-1))/(width-1), 1+(rarr[i]-edge_max)/(edge_max-bottomlevel) >> "./sideboxsouth.obj"
                print phiarr[i], elev[i] > "./sideboxsouth_topo.txt"
# --- /new
             }
             half_vertex=cur_vertex-1
             for(i=ind_ll;i<=ind_lr;i+=1) {
                southedgeind[cur_vertex]=cur_vertex
                cur_vertex++
                print "v", bottomlevel*vectorx[i], bottomlevel*vectory[i], bottomlevel*vectorz[i], colorrgb >> "./sideboxsouth.obj"
                print southnormal >> "./sideboxsouth.obj"
# --- new
                print "vt", 1-(2*width-(cur_vertex-1))/(width-1), 0 >> "./sideboxsouth.obj"
# --- /new
             }
             for(i=1;i<half_vertex;i++) {
               j=cur_vertex-i
# --- new
              printf("f %d/%d/%d %d/%d/%d %d/%d/%d %d/%d/%d\n", southedgeind[i],  southedgeind[i], southedgeind[i], southedgeind[i+1],  southedgeind[i+1], southedgeind[i+1], southedgeind[j-1],  southedgeind[j-1], southedgeind[j-1], southedgeind[j], southedgeind[j], southedgeind[j]) >> "./sideboxsouth.obj"
# --- /new

               # Old # printf("f %d %d %d %d\n", southedgeind[i],  southedgeind[i+1],  southedgeind[j-1],  southedgeind[j]) >> "./sideboxsouth.obj"
             }

# --- new

           dist_lon_m=haversine_m(phiarr[ind_lr], thetaarr[ind_lr], phiarr[ind_ll], thetaarr[ind_ll])
       #    (thetaarr[ind_ur]-thetaarr[ind_lr])*111132
           # map_lat_in=10

           # print "south dist_lon_m:", dist_lon_m > "/dev/stderr"
           height_in=(elev_max + boxdepth*1000)/dist_lon_m*map_lon_in
# Note the -JX- which flips the X axis of the profile
           print "gmt psxy sideboxsouth_topo.txt -R" phiarr[ind_ll] "/" phiarr[ind_lr] "/" boxdepth*-1000 "/" elev_max " -JX" map_lon_in "i/" height_in "i ", axescommand, " --MAP_FRAME_TYPE=inside --PS_PAGE_COLOR=" boxcolor " > sidesouth.ps" >> "./make_side.sh"
           print "gmt psconvert -Tg -A+m0i sidesouth.ps" >> "./make_side.sh"
           print "mv sidesouth.png 3d/Textures/SideboxSouth.png" >> "./make_side.sh"
# --- /new

# Output west side of box

             print "mtllib materials.mtl" > "./sideboxwest.obj"
             print "o SideBoxWest" >> "./sideboxwest.obj"
             print "usemtl SideBoxWest" >> "./sideboxwest.obj"

             cur_vertex=1

# --- new
            edge_max_ind=ind_ll
            for(i=ind_ll;i>=ind_ul;i-=width) {
              edge_max_ind=(rarr[i]>rarr[edge_max_ind])?i:edge_max_ind
            }
            edge_max=rarr[edge_max_ind]
            elev_max=elev[edge_max_ind]
# --- /new

             for(i=ind_ll;i>=ind_ul;i-=width) {
                westedgeind[cur_vertex]=cur_vertex
                cur_vertex++
                # print "v", vectorx[i], vectory[i], vectorz[i], colorrgb >> "./sideboxwest.obj"
                print "v", rarr[i]*vectorx[i], rarr[i]*vectory[i], rarr[i]*vectorz[i], colorrgb >> "./sideboxwest.obj"
                print westnormal >> "./sideboxwest.obj"
# --- new
               print "vt", (height-(cur_vertex-1))/(height-1), 1+(rarr[i]-edge_max)/(edge_max-bottomlevel) >> "./sideboxwest.obj"
               print thetaarr[i], elev[i] > "./sideboxwest_topo.txt"
# --- /new

             }
             half_vertex=cur_vertex-1
             for(i=ind_ul;i<=ind_ll;i+=width) {
                westedgeind[cur_vertex]=cur_vertex
                cur_vertex++
                print "v", bottomlevel*vectorx[i], bottomlevel*vectory[i], bottomlevel*vectorz[i], colorrgb >> "./sideboxwest.obj"
                print westnormal >> "./sideboxwest.obj"
# --- new
               print "vt", 1-(2*height-(cur_vertex-1))/(height-1), 0 >> "./sideboxwest.obj"
# --- /new
             }
             for(i=1;i<half_vertex;i++) {
               j=cur_vertex-i
# --- new
              printf("f %d/%d/%d %d/%d/%d %d/%d/%d %d/%d/%d\n", westedgeind[i],  westedgeind[i], westedgeind[i], westedgeind[i+1],  westedgeind[i+1], westedgeind[i+1], westedgeind[j-1],  westedgeind[j-1], westedgeind[j-1], westedgeind[j], westedgeind[j], westedgeind[j]) >> "./sideboxwest.obj"
# --- /new
               # Old # printf("f %d %d %d %d\n", westedgeind[i],  westedgeind[i+1],  westedgeind[j-1],  westedgeind[j]) >> "./sideboxwest.obj"
             }

# --- new

            dist_lat_m=haversine_m(phiarr[ind_ll], thetaarr[ind_ll], phiarr[ind_ul], thetaarr[ind_ul])
            # print "west dist_lat_m:", dist_lat_m > "/dev/stderr"

            # dist_lat_m=(thetaarr[ind_ur]-thetaarr[ind_lr])*111132
            # map_lat_in=10

            height_in=(elev_max + boxdepth*1000)/dist_lat_m*map_lat_in

            print "gmt psxy sideboxwest_topo.txt -R" thetaarr[ind_lr] "/" thetaarr[ind_ur] "/" boxdepth*-1000 "/" elev_max " -JX-" map_lat_in "i/" height_in "i ", axescommand, " --MAP_FRAME_TYPE=inside --PS_PAGE_COLOR=" boxcolor " > sidewest.ps" > "./make_side.sh"
            print "gmt psconvert -Tg -A+m0i sidewest.ps" >> "./make_side.sh"
            print "mv sidewest.png 3d/Textures/SideboxWest.png" >> "./make_side.sh"
# --- /new


           }




           # Optionally, write out an object for the ocean
           if (makeocean==1) {

             calc_ecef_to_enu_matrix(phiarr[1], thetaarr[1])
             multiply_ecef_matrix(-1, 0, 0)
             eastnormal=sprintf("vn %f %f %f", w[1], w[2], w[3])
             multiply_ecef_matrix(1, 0, 0)
             westnormal=sprintf("vn %f %f %f", w[1], w[2], w[3])
             multiply_ecef_matrix(0, -1, 0)
             northnormal=sprintf("vn %f %f %f", w[1], w[2], w[3])
             multiply_ecef_matrix(0, 1, 0)
             southnormal=sprintf("vn %f %f %f", w[1], w[2], w[3])

             print "mtllib materials.mtl" > "./oceannorth.obj"
             print "o OceanNorth" >> "./oceannorth.obj"
             print "usemtl Ocean" >> "./oceannorth.obj"

             cur_vertex=1

             for(i=ind_ul;i<=ind_ur;i++) {
                northedgeind[cur_vertex]=cur_vertex
                northedgeelev[cur_vertex]=elev[i]
                cur_vertex++
                print "v", rarr[i]*vectorx[i], rarr[i]*vectory[i], rarr[i]*vectorz[i], colorsea >> "./oceannorth.obj"
                print northnormal >> "./oceannorth.obj"
             }
             half_vertex=cur_vertex-1
             for(i=ind_ur;i>=ind_ul;i--) {
                northedgeind[cur_vertex]=cur_vertex
                cur_vertex++
                print "v", sealevel*vectorx[i], sealevel*vectory[i], sealevel*vectorz[i], colorsea >> "./oceannorth.obj"
                print northnormal >> "./oceannorth.obj"
             }
             for(i=1;i<half_vertex;i++) {
               j=cur_vertex-i

               # Only render the face if the elevation of either upper vertex is lower than or equal to sea level
               if (northedgeelev[i] <= 0 && northedgeelev[i+1] <= 0) {
                 printf("f %d %d %d %d\n", northedgeind[i],  northedgeind[i+1],  northedgeind[j-1],  northedgeind[j]) >> "./oceannorth.obj"
               }
             }


             print "mtllib materials.mtl" > "./oceaneast.obj"
             print "o OceanEast" >> "./oceaneast.obj"
             print "usemtl Ocean" >> "./oceaneast.obj"

             cur_vertex=1

             for(i=ind_ur;i<=ind_lr;i+=width) {
                eastedgeind[cur_vertex]=cur_vertex
                eastedgeelev[cur_vertex]=elev[i]

                cur_vertex++
                print "v", rarr[i]*vectorx[i], rarr[i]*vectory[i], rarr[i]*vectorz[i], colorsea >> "./oceaneast.obj"
                # print "v", vectorx[i], vectory[i], vectorz[i] "./oceaneast.obj"
                print eastnormal >> "./oceaneast.obj"
                # print "vt", cur_vertex/height, 0 >> "./oceaneast.obj"
             }
             half_vertex=cur_vertex-1
             for(i=ind_lr;i>=ind_ur;i-=width) {
                eastedgeind[cur_vertex]=cur_vertex
                cur_vertex++
                print "v", sealevel*vectorx[i], sealevel*vectory[i], sealevel*vectorz[i], colorsea >> "./oceaneast.obj"
                # print "v", sealevel*vectorx[i], sealevel*vectory[i], sealevel*vectorz[i]  >> "./oceaneast.obj"
                print eastnormal >> "./oceaneast.obj"
                # print "vt", 1-(cur_vertex-height)/height >> "./oceaneast.obj"
             }
             for(i=1;i<half_vertex;i++) {
               j=cur_vertex-i
               if (eastedgeelev[i] <= 0 && eastedgeelev[i+1] <= 0) {
                 printf("f %d %d %d %d\n", eastedgeind[i],  eastedgeind[i+1],  eastedgeind[j-1],  eastedgeind[j]) >> "./oceaneast.obj"
               }
             }

             print "mtllib materials.mtl" > "./oceansouth.obj"
             print "o OceanSouth" >> "./oceansouth.obj"
             print "usemtl Ocean" >> "./oceansouth.obj"

             cur_vertex=1

             for(i=ind_lr;i>=ind_ll;i-=1) {
                southedgeind[cur_vertex]=cur_vertex
                southedgeelev[cur_vertex]=elev[i]

                cur_vertex++
                print "v", rarr[i]*vectorx[i], rarr[i]*vectory[i], rarr[i]*vectorz[i], colorsea >> "./oceansouth.obj"
                print southnormal >> "./oceansouth.obj"
             }
             half_vertex=cur_vertex-1
             for(i=ind_ll;i<=ind_lr;i+=1) {
                southedgeind[cur_vertex]=cur_vertex
                cur_vertex++
                print "v", sealevel*vectorx[i], sealevel*vectory[i], sealevel*vectorz[i], colorsea >> "./oceansouth.obj"
                print southnormal >> "./oceansouth.obj"
             }
             for(i=1;i<half_vertex;i++) {
               j=cur_vertex-i
               if (southedgeelev[i] <= 0 && southedgeelev[i+1] <= 0) {
                 printf("f %d %d %d %d\n", southedgeind[i],  southedgeind[i+1],  southedgeind[j-1],  southedgeind[j]) >> "./oceansouth.obj"
               }
             }

             print "mtllib materials.mtl" > "./oceanwest.obj"
             print "o OceanWest" >> "./oceanwest.obj"
             print "usemtl Ocean" >> "./oceanwest.obj"

             cur_vertex=1

             for(i=ind_ll;i>=ind_ul;i-=width) {
                westedgeind[cur_vertex]=cur_vertex
                westedgeelev[cur_vertex]=elev[i]

                cur_vertex++
                print "v", rarr[i]*vectorx[i], rarr[i]*vectory[i], rarr[i]*vectorz[i], colorsea >> "./oceanwest.obj"
                print westnormal >> "./oceanwest.obj"
             }
             half_vertex=cur_vertex-1
             for(i=ind_ul;i<=ind_ll;i+=width) {
                westedgeind[cur_vertex]=cur_vertex
                cur_vertex++
                print "v", sealevel*vectorx[i], sealevel*vectory[i], sealevel*vectorz[i], colorsea >> "./oceanwest.obj"
                print westnormal >> "./oceanwest.obj"
             }
             for(i=1;i<half_vertex;i++) {
               j=cur_vertex-i
               if (westedgeelev[i] <= 0 && westedgeelev[i+1] <= 0) {
                 printf("f %d %d %d %d\n", westedgeind[i],  westedgeind[i+1],  westedgeind[j-1],  westedgeind[j]) >> "./oceanwest.obj"
               }
             }

           } # if (makeocean==1)

          }' ${F_CPTS}topo_fixed.cpt ${F_TOPO}dem_values.txt > ${F_3D}${PLY_MTLNAME}.obj

          # Generate the PNG files that textures the sides of the box, if the script to make them exists

          [[ -s ./make_side.sh ]] && mkdir -p 3d/Textures/ && source ./make_side.sh

if [[ -s ./OceanTop.obj ]]; then
cat <<-EOF >> ${F_3D}materials.mtl
newmtl OceanTop
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 0.5
illum 1
Ns 0.000000
EOF
# map_Ka Textures/water.jpg
# map_Kd Textures/water.jpg
# map_Ks Textures/water.jpg
mv ./OceanTop.obj ${F_3D}
# mkdir -p  ${F_3D}Textures/
# cp ${TECTOPLOTDIR}3d/water.jpg ${F_3D}Textures/
fi
if [[ -s ./oceannorth.obj ]]; then
cat <<-EOF >> ${F_3D}materials.mtl
newmtl Ocean
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 0.6
illum 1
Ns 0.000000
EOF
mv ./oceannorth.obj ${F_3D}
mv ./oceaneast.obj ${F_3D}
mv ./oceansouth.obj ${F_3D}
mv ./oceanwest.obj ${F_3D}
fi
if [[ -s ./sideboxwest.obj ]]; then
cat <<-EOF >> ${F_3D}materials.mtl
newmtl SideBoxWest
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 0.05
illum 1
Ns 0.000000
EOF

if [[ -s ${F_3D}Textures/SideboxWest.png ]]; then
  echo "map_Ka Textures/SideboxWest.png" >> ${F_3D}materials.mtl
  echo "map_Kd Textures/SideboxWest.png" >> ${F_3D}materials.mtl
  echo "map_Ks Textures/SideboxWest.png" >> ${F_3D}materials.mtl
fi

mv ./sideboxwest.obj ${F_3D}
fi
if [[ -s ./sideboxnorth.obj ]]; then
cat <<-EOF >> ${F_3D}materials.mtl
newmtl SideBoxNorth
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 0.05
illum 1
Ns 0.000000
EOF

if [[ -s ${F_3D}Textures/SideboxNorth.png ]]; then
  echo "map_Ka Textures/SideboxNorth.png" >> ${F_3D}materials.mtl
  echo "map_Kd Textures/SideboxNorth.png" >> ${F_3D}materials.mtl
  echo "map_Ks Textures/SideboxNorth.png" >> ${F_3D}materials.mtl
fi

mv ./sideboxnorth.obj ${F_3D}
fi
if [[ -s ./sideboxeast.obj ]]; then
cat <<-EOF >> ${F_3D}materials.mtl
newmtl SideBoxEast
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 0.05
illum 1
Ns 0.000000
EOF

if [[ -s ${F_3D}Textures/SideboxEast.png ]]; then
  echo "map_Ka Textures/SideboxEast.png" >> ${F_3D}materials.mtl
  echo "map_Kd Textures/SideboxEast.png" >> ${F_3D}materials.mtl
  echo "map_Ks Textures/SideboxEast.png" >> ${F_3D}materials.mtl
fi

mv ./sideboxeast.obj ${F_3D}
# mkdir -p ${F_3D}Textures/
# cp ${TECTOPLOTDIR}sidebox.png ${F_3D}Textures/
fi
if [[ -s ./sideboxsouth.obj ]]; then
cat <<-EOF >> ${F_3D}materials.mtl
newmtl SideBoxSouth
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 0.05
illum 1
Ns 0.000000
EOF

if [[ -s ${F_3D}Textures/SideboxSouth.png ]]; then
  echo "map_Ka Textures/SideboxSouth.png" >> ${F_3D}materials.mtl
  echo "map_Kd Textures/SideboxSouth.png" >> ${F_3D}materials.mtl
  echo "map_Ks Textures/SideboxSouth.png" >> ${F_3D}materials.mtl
fi

mv ./sideboxsouth.obj ${F_3D}
fi

          [[ -s ./dem_corners.txt ]] && mv ./dem_corners.txt ${F_3D}dem_corners.txt
          [[ -s ./eq_maxdepth.txt ]] && mv ./eq_maxdepth.txt ${F_3D}eq_maxdepth.txt

          # Make a box from the corners of the DEM to the earthquake max depth
          # Only if the maxdepth and corner coords exist AND not a global model

          # eq_maxdepth.txt has one line with one value
          # dem_corners.txt is in lon lat format in order UL,UR,LL,LR


          if [[ $plyboxdepthflag -eq 1 ]]; then
            sphere_rad=$(echo "(6371 - ${PLY_BOXDEPTH})/100" | bc -l)
          elif [[ -s ${F_3D}eq_maxdepth.txt ]]; then
            sphere_rad=$(head -n 1 ${F_3D}eq_maxdepth.txt | gawk 'function min(u,v) { return (u<v)?u:v} {print (6371-min($1,660))/100 }' )
          else
            sphere_rad=$(gawk 'BEGIN{print (6371-660)/100}' )
          fi

          # If we plotted earthquakes and a DEM, and are not making a globe, make a box
          if [[ -s ${F_3D}eq_maxdepth.txt ]]; then
            plymakeboxflag=1
          fi

          # Make the text
          if [[ $plymaketextflag -eq 1 && $closeglobeflag -ne 1 ]]; then
            echo "mtllib materials.mtl" > ${F_3D}${PLY_TEXTCODE}.obj
            echo "o Text1" >> ${F_3D}${PLY_TEXTCODE}.obj

            text_rad=$(echo "(6371 - ${PLY_TEXTDEPTH})/100" | bc -l)

            # Create the text as the smallest PNG file possible, on a white background
            echo "0 0 ${PLY_TEXTSTRING}" | gmt pstext -F+f12p,Courier,${PLY_TEXTFONTCOLOR} -R-1/1/-1/1 -JX2i --PS_PAGE_COLOR=${PLY_BACKGROUND_COLOR} > a.ps
            gmt psconvert a.ps -TG -A+m1i

            # Calculate the width vs height of the image

            # TEXT_DIM=$(gmt psconvert a.ps -Te -A+m0i -V 2> >(grep Width) | gawk  -F'[ []' '{print $10, $17}')
            # TEXT_WIDTH_IN=$(echo $PS_DIM | gawk  '{print $1/2.54}')
            # TEXT_HEIGHT_IN=$(echo $PS_DIM | gawk  '{print $2/2.54}')

            mkdir -p ${F_3D}Textures/
            mv a.png ${F_3D}/Textures/${PLY_TEXTCODE}.png

            gawk < ${F_3D}dem_corners.txt -v boxdepth=${text_rad} -v textcode=${PLY_TEXTCODE} '
              function getpi()       { return atan2(0,-1)             }
              function deg2rad(deg)  { return (getpi() / 180) * deg   }
              BEGIN {
                ptcount=0
              }
              ($1+0==$1) {
                if (ptcount++ < 4) {
                  phi=deg2rad($1)
                  theta=deg2rad(90-$2)
                  print "v", (boxdepth)*sin(theta)*cos(phi), (boxdepth)*sin(theta)*sin(phi), (boxdepth)*cos(theta)
                  print "vn", sin(theta)*cos(phi), sin(theta)*sin(phi), cos(theta)
                } else {
                  exit
                }
              }
              END {
                #  UL, LL, LR, UR
                print "vt 0 1"
                print "vt 0 0"
                print "vt 1 0"
                print "vt 1 1"
                print "usemtl", textcode
                print "f 1/1/1 2/2/2 3/3/3 4/4/4"
              }' >> ${F_3D}${PLY_TEXTCODE}.obj

cat <<-EOF >> ${F_3D}materials.mtl
newmtl ${PLY_TEXTCODE}
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000001 0.000001 0.000001
Tr 1.0
illum 1
Ns 0.000000
map_Ka Textures/${PLY_TEXTCODE}.png
map_Kd Textures/${PLY_TEXTCODE}.png
map_Ks Textures/${PLY_TEXTCODE}.png
EOF


          fi

          if [[ $plymakeboxflag -eq 1 && -s ${F_3D}dem_corners.txt && $closeglobeflag -ne 1 ]]; then
            echo "mtllib materials.mtl" > ${F_3D}box.obj
            echo "o Box1" >> ${F_3D}box.obj
            echo "usemtl BoxLine" >> ${F_3D}box.obj

            # The first four lines of dem_corners.txt are the corner points,
            # the remaining lines are the outline of the DEM

            gawk < ${F_3D}dem_corners.txt -v boxdepth=${sphere_rad} '
            @include "tectoplot_functions.awk"
            BEGIN {
              startlower="none"
              lowerboxnum=0
              noncomline=1
              boundarynum=1
              print "# Corner vertices"
            }

            {
              if ($1=="") {
                # Do nothing
              } else if (substr($0,0,1)=="#") {
                if (noncomline >= 4) {
                  boundary[boundarynum++]=noncomline
                }
              } else {
                if(noncomline <= 4) {
                  phi=deg2rad($1)
                  theta=deg2rad(90-$2)
                  print "v", $3*sin(theta)*cos(phi), $3*sin(theta)*sin(phi), $3*cos(theta)
                  print "v", (boxdepth)*sin(theta)*cos(phi), (boxdepth)*sin(theta)*sin(phi), (boxdepth)*cos(theta)
                }
                if (noncomline > 4) {
                  if (startlower == "none") {
                    print "l 1 2"
                    print "l 3 4"
                    print "l 5 6"
                    print "l 7 8"
                    print "# DEM boundary"
                    print "o BoxSeg1"
                    print "usemtl BoxLine"
                    startlower=0
                  }
                  phi=deg2rad($1)
                  theta=deg2rad(90-$2)
                  print "v", (boxdepth)*sin(theta)*cos(phi), (boxdepth)*sin(theta)*sin(phi), (boxdepth)*cos(theta)
                  lowerboxnum++
                }
                noncomline++

              }
            }
            END {
              thisboundary=2
              print "Printing vertices through number", lowerboxnum > "/dev/stderr"
              for(i=9;i<lowerboxnum+8;i++) {
                printf("l %d %d\n", i, i+1)
                # if (i == boundary[thisboundary]) {
                #   printf("\no BoxSeg%d\n ", thisboundary++)
                # }
              }
            }' >> ${F_3D}box.obj

cat <<-EOF >> ${F_3D}materials.mtl
newmtl BoxLine
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 1.0
illum 1
Ns 0.000000
EOF

          fi

cat <<-EOF >> ${F_3D}materials.mtl
newmtl ${PLY_MTLNAME}
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 1.0
illum 1
Ns 0.000000
map_Ka Textures/${PLY_TEXNAME}
map_Kd Textures/${PLY_TEXNAME}
map_Ks Textures/${PLY_TEXNAME}
map_d Textures/${PLY_TEXNAME}
EOF

    # This adds the seismicity point cloud to the end of an OBJ. Currently we
    # use a PLY file instead as Sketchfab plots that format with round points
    # if [[ -s tectoplot_vertex.ply ]]; then
    #   gawk < tectoplot_vertex.ply '{print "v", $0; print "p -1"; }' >> ${PLY_MTLNAME}.obj
    # fi

    # Export the texture as JPG

    if [[ $plymakealphaflag -eq 1 ]]; then
      # Produce a map.png with transparency for untouched areas
      echo "Converting map to PNG with alpha transparency"
      gmt psconvert map.ps -TG -A ${VERBOSE}
      mkdir -p ${F_3D}Textures/
      mv map.png ${F_3D}Textures/${PLY_TEXNAME}
      echo "map_d Textures/"${PLY_TEXNAME} >> ${F_3D}materials.mtl
      echo "d 0.5" >> ${F_3D}materials.mtl
    elif [[ $plymaptiffflag -eq 1 && -s ./map.tiff ]]; then
      echo "Converting map to PNG"
      mkdir -p ${F_3D}Textures/
      gdal_translate -q -of "PNG" map.tiff ${F_3D}Textures/${PLY_TEXNAME}
    elif [[ ! -s ${F_TOPO}colored_intensity.tif ]]; then
      mkdir -p ${F_3D}Textures/
      if [[ -s ${F_TOPO}colored_relief.tif ]]; then
        echo "Using colored_relief.tif as PNG"

        gdal_translate -q -of "PNG" ${F_TOPO}colored_relief.tif ${F_3D}Textures/${PLY_TEXNAME}
      fi
    else
      echo "Using colored_intensity.tif"
      mkdir -p ${F_3D}Textures/
      gdal_translate -q -of "PNG" ${F_TOPO}colored_intensity.tif ${F_3D}Textures/${PLY_TEXNAME}
    fi

    # We want to make an alpha overlay of the image that sets all near-black values to 0,
    # all colored values to 0, and sets gray values within a range of 0 to their value,
    # and sets everything else to 255.



fi



if [[ $makeplyflag -eq 1 && $makeplyslab2meshflag -eq 1 && $plydemonlyflag -eq 0 ]]; then

  # SLABDEPFILE="/Users/kylebradley/Dropbox/TectoplotData/SLAB2/Slab2Distribute_Mar2018/cam_slab2_dep_02.24.18.grd"
  [[ ! -s ${F_CPTS}seisdepth_fixed.cpt && -s ${F_CPTS}seisdepth.cpt ]] && replace_gmt_colornames_rgb ${F_CPTS}seisdepth.cpt > ${F_CPTS}seisdepth_fixed.cpt

  info_msg "[-makeply]: Making mesh surfaces of Slab2 interface"
        # Now convert the DEM to an OBJ format surface at the same scaling factor
        # Default format is scanline orientation of ASCII numbers: −ZTLa. Note that −Z only applies to 1-column output.

  for i in $(seq 1 $numslab2inregion); do

        gridfile=$(echo ${SLAB2_GRIDDIR}${slab2inregion[$i]}.grd | sed 's/clp/dep/')
        info_msg "Creating OBJ file for slab ${i} : ${gridfile}"

        if [[ -e $gridfile ]]; then

          if [[ $downsampleslabflag -eq 1 ]]; then
              gmt grdsample ${gridfile} -I0.1d -G${F_SLAB}slab_${i}_downsample.grd ${VERBOSE}
              gridfile="${F_SLAB}slab_${i}_downsample.grd"
          fi

          gmt grd2xyz ${gridfile} ${VERBOSE} > ${F_SLAB}slab_values_${i}.txt
          # gmt grdcut ${gridfile} -R${F_TOPO}dem.nc -G${F_SLAB}slabcut_${i}.grd
        else
          echo "Slab file $gridfile does not exist"
          continue
        fi

        # SLAB_DEP=${F_SLAB}slabcut_${i}.grd

        dem_orig_info=($(gmt grdinfo ${gridfile} -C -Vn))
        dem_numx=${dem_orig_info[9]}
        dem_numy=${dem_orig_info[10]}

        # # gmt grd2xyz ${SLAB_DEP} -C ${VERBOSE} > ${F_SLAB}slab_indices_${i}.txt
        # gmt grd2xyz ${SLAB_DEP} ${VERBOSE} > ${F_SLAB}slab_values_${i}.txt

        gawk -v width=${dem_numx} -v height=${dem_numy} -v minlon=${MINLON} -v maxlon=${MAXLON} -v minlat=${MINLAT} -v maxlat=${MAXLAT} '
        @include "tectoplot_functions.awk"
           BEGIN {
             # colorind=0
             vertexind=1
             # Set up the material file
             print "mtllib materials.mtl"
             minphi="none"
             maxphi="none"
             mintheta="none"
             maxtheta="none"
           }

           # Read the CPT file first

           (NR==FNR) {
             if ($1+0==$1) {
               # Slab2 depths are z getting more negative downward
               minz[NR]=$1
               split($2, arr, "/")
               red[NR]=arr[1]
               green[NR]=arr[2]
               blue[NR]=arr[3]
               colorind=NR
             }
           }

           # Read the vertices (Slab grid points) second
         (NR!=FNR) {

           # Calculating the color index takes a long time for many vertices
           # and we are not currently using it... so comment out the following lines

           for(i=1; i<= colorind; i++) {
             if (minz[i]<0-$3) {
               vertexcolor[vertexind]=i
             } else {
               break
             }
           }

           phi=deg2rad($1)
           theta=deg2rad(90-$2)

           if (tolower($3) == "nan") {
             $3=-6000
             cell_nan[vertexind]=1
           }

           if ($2 < minlat || $2 > maxlat || test_lon(minlon, maxlon, $1) == 0) {
             cell_nan[vertexind]=1
           }

           r=(6371+$3)/100

           # r = 6371/100 (Earth radius) for grid cells with values of NaN

           # Calculate the vector for each vertex (center of Earth to vertex point)
           vectorx[vertexind]=r*sin(theta)*cos(phi)
           vectory[vertexind]=r*sin(theta)*sin(phi)
           vectorz[vertexind]=r*cos(theta)
           phiarr[vertexind]=$1
           thetaarr[vertexind]=$2
           rarr[vertexind]=r
           vertexind++
         }
         END {

           # Calculate the vertex x and y positions. They are ordered from
           # 0...width and 0...height.

           num_vertices=width*height
           for (i=0; i<=num_vertices; i++) {
             x_arr[i] = i % width
             y_arr[i] = int(i/width)
             vertex_num[x_arr[i],y_arr[i]]=i

            # Due to the grid being cell center registered, we need to adjust the
            # edges to close a global grid at the antimeridan and poles

           }

           print "o SlabMesh"

           for (i=1; i<=num_vertices; i++) {
             # The following line places the color index for each vertex... comment out for now
             print "v", vectorx[i], vectory[i], vectorz[i], red[vertexcolor[i]], green[vertexcolor[i]], blue[vertexcolor[i]]
             # print "v", vectorx[i], vectory[i], vectorz[i], 255, 255, 255
           }

           # Calculate the vertex normals

           for (i=1; i<=num_vertices; i++) {
             num_normals=0

             # Find the indices of the vertices surrounding each vertex
             # If we are on an edge, vertex_num for some of these will be wrong!

             tl = vertex_num[x_arr[i]-1,y_arr[i]-1]
             tc = vertex_num[x_arr[i],y_arr[i]-1]
             tr = vertex_num[x_arr[i]+1,y_arr[i]-1]
             cr = vertex_num[x_arr[i]+1,y_arr[i]]
             cl = vertex_num[x_arr[i]-1,y_arr[i]]
             bl = vertex_num[x_arr[i]-1,y_arr[i]+1]
             bc = vertex_num[x_arr[i],y_arr[i]+1]
             br = vertex_num[x_arr[i]+1,y_arr[i]+1]

             # if we are not along the lower or right edge

             if (x_arr[i] > 0 && y_arr[i] > 0 && x_arr[i] < width-1 && y_arr[i] < height-1) {
               # print width, height, x_arr[i], y_arr[i], cr, i, ":", vectorx[cr],vectory[cr],vectorz[cr], "cross", vectorx[i],vectory[i],vectorz[i] > "/dev/stderr"

               # Note: we currently are only using one arbitrarily chosen normal direction for
               # each interior point, and the normal to the sphere for edge points.

               # This should be extended to be an average normal of surrounding faces

                 # Normal is (cr-i) x (bc-i)
                 # (cr - i)
                 v_subtract(vectorx[cr],vectory[cr],vectorz[cr],vectorx[i],vectory[i],vectorz[i])
                 r_tmp_1=w_sub_1; r_tmp_2=w_sub_2; r_tmp_3=w_sub_3
                 # (br - i)
                 v_subtract(vectorx[bc],vectory[bc],vectorz[bc],vectorx[i],vectory[i],vectorz[i])
                 # (cr - i) x (br - i)
                 v_cross(r_tmp_1,r_tmp_2,r_tmp_3,w_sub_1,w_sub_2,w_sub_3)
                 print "vn", w_cross_1, w_cross_2, w_cross_3

             } else {
                 # print "vector (" i "):", vectorx[i], vectory[i], vectorz[i] > "/dev/stderr"

                 vectorlen=sqrt(vectorx[i]*vectorx[i]+vectory[i]*vectory[i]+vectorz[i]*vectorz[i])
                 print "vn", -vectorx[i]/vectorlen, -vectory[i]/vectorlen, -vectorz[i]/vectorlen
             }

           }

           print "usemtl SlabColor"

           # Output two faces per vertex, except for the y=height and y=width
           # vertices which define the lower and right edge, and only if all
           # surrounding vertices are not NaN

           facecount=0
           for (y_ind=0; y_ind<height-1; y_ind++) {
             for (x_ind=0; x_ind<width-1; x_ind++) {
               tl = 1 + (width*y_ind)+x_ind
               tr = tl + 1
               bl = tl + width
               br = bl + 1

               if ((cell_nan[tl]+cell_nan[tr]+cell_nan[bl])==0) {
                 # Clockwise order for faces
                 print "f", tl "/" tl "/" tl, tr "/" tr "/" tr, bl "/" bl "/" bl
                 facecount+=1
               }
               if ((cell_nan[tr]+cell_nan[br]+cell_nan[bl])==0) {
                 print "f", tr "/" tr "/" tr, br "/" br "/" br, bl "/" bl "/" bl
                 facecount+=1
               }
             }
           }
           # print "Faces output:", facecount > "/dev/stderr"

         }' ${F_CPTS}seisdepth_fixed.cpt ${F_SLAB}slab_values_${i}.txt > ${F_3D}slab_${i}_presimplified.obj

         # Our approach leaves MANY unused vertices, so remove and update faces

         gawk < ${F_3D}slab_${i}_presimplified.obj '
         BEGIN {
           vertexind=1
           normalind=1
           textureind=1
           faceind=1
         }
         {
           if ($1=="v") {
             vertexdata[vertexind++]=$0
           } else if ($1=="vn") {
             normaldata[normalind++]=$0
           } else if ($1=="vt") {
             texturedata[textureind++]=$0
           } else if ($1=="f") {
             facedata[faceind]=$0
             i=1
             while($(i+1)!="") {
               split($(i+1), splitstr, "/")
               # Mark the vertex index as being seen
               # print "seeing vertex", splitstr[1]
               seenindex[splitstr[1]]=1
               faceindex[faceind][i]=splitstr[1]
               facecount[faceind]++
               i++
             }
             faceind++
           } else {
             print
           }
         }
         END {
           unseencount=0
           for (i=1; i<vertexind; i++) {
             if (seenindex[i]==0) {
               addme=1
             } else {
               addme=0
             }
             unseencount+=addme
             unseenbefore[i]=unseencount
             # print "Seen:", i, seenindex[i]
           }
           for (i=1; i<vertexind; i++) {
             if (seenindex[i]==1) {
               print vertexdata[i]
             }
           }
           for (i=1; i<normalind; i++) {
             if (seenindex[i]==1) {
               print normaldata[i]
             }
           }
           for (i=1; i<textureind; i++) {
             if (seenindex[i]==1) {
               print texturedata[i]
             }
           }

           for(i=1; i<faceind; i++) {
             # print facedata[i]
             printf("f ")
             for(j=1; j<= facecount[i]; j++) {
               vertbefore=faceindex[i][j]
               vertafter=vertbefore-unseenbefore[vertbefore]
               printf("%d/%d/%d ", vertafter, vertafter, vertafter)
             }
             printf("\n")
           }
         }
         ' > ${F_3D}slab_${i}.obj

         rm -f ${F_3D}slab_${i}_presimplified.obj
         touch ${F_3D}slabdone
   done

cat <<-EOF >> ${F_3D}materials.mtl
newmtl SlabColor
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 1.0
illum 1
Ns 0.000000
EOF

fi

# Make another fault surface from a depth grid, not Slab2.0

if [[ $makeplyflag -eq 1 && $makeplyfaultmeshflag -eq 1 && $plydemonlyflag -eq 0 ]]; then

  # SLABDEPFILE="/Users/kylebradley/Dropbox/TectoplotData/SLAB2/Slab2Distribute_Mar2018/cam_slab2_dep_02.24.18.grd"
  [[ ! -s ${F_CPTS}seisdepth_fixed.cpt && -s ${F_CPTS}seisdepth.cpt ]] && replace_gmt_colornames_rgb ${F_CPTS}seisdepth.cpt > ${F_CPTS}seisdepth_fixed.cpt

  info_msg "[-makeply]: Making mesh surfaces of custom fault grids"
        # Now convert the DEM to an OBJ format surface at the same scaling factor
        # Default format is scanline orientation of ASCII numbers: −ZTLa. Note that −Z only applies to 1-column output.

  for i in $(seq 1 $numgridfault); do

        gridfile=${gridfault[$i]}
        info_msg "Creating OBJ file for fault file ${i} : ${gridfile}"

        if [[ -e $gridfile ]]; then

          # if [[ $downsampleslabflag -eq 1 ]]; then
          #     gmt grdsample ${gridfile} -I0.1d -G${F_SLAB}slab_${i}_downsample.grd ${VERBOSE}
          #     gridfile="${F_SLAB}slab_${i}_downsample.grd"
          # fi

          gmt grd2xyz ${gridfile} ${VERBOSE} > ${F_SLAB}fault_values_${i}.txt
          # gmt grdcut ${gridfile} -R${F_TOPO}dem.nc -G${F_SLAB}slabcut_${i}.grd
        else
          echo "Fault file $gridfile does not exist"
          continue
        fi

        # SLAB_DEP=${F_SLAB}slabcut_${i}.grd

        dem_orig_info=($(gmt grdinfo ${gridfile} -C -Vn))
        dem_numx=${dem_orig_info[9]}
        dem_numy=${dem_orig_info[10]}

        # # gmt grd2xyz ${SLAB_DEP} -C ${VERBOSE} > ${F_SLAB}slab_indices_${i}.txt
        # gmt grd2xyz ${SLAB_DEP} ${VERBOSE} > ${F_SLAB}slab_values_${i}.txt

        gawk -v width=${dem_numx} -v height=${dem_numy} -v minlon=${MINLON} -v maxlon=${MAXLON} -v minlat=${MINLAT} -v maxlat=${MAXLAT} '
        @include "tectoplot_functions.awk"
           BEGIN {
             # colorind=0
             vertexind=1
             # Set up the material file
             print "mtllib materials.mtl"
             minphi="none"
             maxphi="none"
             mintheta="none"
             maxtheta="none"
           }

           # Read the CPT file first

           (NR==FNR) {
             if ($1+0==$1) {
               # Slab2 depths are z getting more negative downward
               minz[NR]=$1
               split($2, arr, "/")
               red[NR]=arr[1]
               green[NR]=arr[2]
               blue[NR]=arr[3]
               colorind=NR
             }
           }

           # Read the vertices (Fault grid points) second
         (NR!=FNR) {

           # Calculating the color index takes a long time for many vertices
           # This could be sped up significantly... somehow

           color_assigned=0
           for(i=1; i<= colorind; i++) {
             if (minz[i]<0-$3/1000) {
               vertexcolor[vertexind]=i
               color_assigned=1
             } else {
               break
             }
           }
           if (color_assigned==0) {
             vertexcolor[vertexind]=1
           }

           phi=deg2rad($1)
           theta=deg2rad(90-$2)

           if (tolower($3) == "nan") {
             $3=9999
             cell_nan[vertexind]=1
           }

           if ($2 < minlat || $2 > maxlat || test_lon(minlon, maxlon, $1) == 0) {
             cell_nan[vertexind]=1
           }

           # elevation of these data are in meters, negative downwards
           r=(6371+$3/1000)/100

           # r = 6371/100 (Earth radius) for grid cells with values of NaN

           # Calculate the vector for each vertex (center of Earth to vertex point)
           vectorx[vertexind]=r*sin(theta)*cos(phi)
           vectory[vertexind]=r*sin(theta)*sin(phi)
           vectorz[vertexind]=r*cos(theta)
           phiarr[vertexind]=$1
           thetaarr[vertexind]=$2
           rarr[vertexind]=r
           vertexind++
         }
         END {

           # Calculate the vertex x and y positions. They are ordered from
           # 0...width and 0...height.

           num_vertices=width*height
           for (i=0; i<=num_vertices; i++) {
             x_arr[i] = i % width
             y_arr[i] = int(i/width)
             vertex_num[x_arr[i],y_arr[i]]=i

            # Due to the grid being cell center registered, we need to adjust the
            # edges to close a global grid at the antimeridan and poles

           }

           print "o FaultMesh"

           for (i=1; i<=num_vertices; i++) {
             # The following line places the color index for each vertex... comment out for now
             print "v", vectorx[i], vectory[i], vectorz[i], red[vertexcolor[i]], green[vertexcolor[i]], blue[vertexcolor[i]]
             # print "v", vectorx[i], vectory[i], vectorz[i], 255, 255, 255
           }

           # Calculate the vertex normals

           for (i=1; i<=num_vertices; i++) {
             num_normals=0

             # Find the indices of the vertices surrounding each vertex
             # If we are on an edge, vertex_num for some of these will be wrong!

             tl = vertex_num[x_arr[i]-1,y_arr[i]-1]
             tc = vertex_num[x_arr[i],y_arr[i]-1]
             tr = vertex_num[x_arr[i]+1,y_arr[i]-1]
             cr = vertex_num[x_arr[i]+1,y_arr[i]]
             cl = vertex_num[x_arr[i]-1,y_arr[i]]
             bl = vertex_num[x_arr[i]-1,y_arr[i]+1]
             bc = vertex_num[x_arr[i],y_arr[i]+1]
             br = vertex_num[x_arr[i]+1,y_arr[i]+1]

             # if we are not along the lower or right edge

             if (x_arr[i] > 0 && y_arr[i] > 0 && x_arr[i] < width-1 && y_arr[i] < height-1) {
               # print width, height, x_arr[i], y_arr[i], cr, i, ":", vectorx[cr],vectory[cr],vectorz[cr], "cross", vectorx[i],vectory[i],vectorz[i] > "/dev/stderr"

               # Note: we currently are only using one arbitrarily chosen normal direction for
               # each interior point, and the normal to the sphere for edge points.

               # This should be extended to be an average normal of surrounding faces

                 # Normal is (cr-i) x (bc-i)
                 # (cr - i)
                 v_subtract(vectorx[cr],vectory[cr],vectorz[cr],vectorx[i],vectory[i],vectorz[i])
                 r_tmp_1=w_sub_1; r_tmp_2=w_sub_2; r_tmp_3=w_sub_3
                 # (br - i)
                 v_subtract(vectorx[bc],vectory[bc],vectorz[bc],vectorx[i],vectory[i],vectorz[i])
                 # (cr - i) x (br - i)
                 v_cross(r_tmp_1,r_tmp_2,r_tmp_3,w_sub_1,w_sub_2,w_sub_3)
                 print "vn", w_cross_1, w_cross_2, w_cross_3

             } else {
                 # print "vector (" i "):", vectorx[i], vectory[i], vectorz[i] > "/dev/stderr"

                 vectorlen=sqrt(vectorx[i]*vectorx[i]+vectory[i]*vectory[i]+vectorz[i]*vectorz[i])
                 print "vn", -vectorx[i]/vectorlen, -vectory[i]/vectorlen, -vectorz[i]/vectorlen
             }

           }

           print "usemtl FaultColor"

           # Output two faces per vertex, except for the y=height and y=width
           # vertices which define the lower and right edge, and only if all
           # surrounding vertices are not NaN

           facecount=0
           for (y_ind=0; y_ind<height-1; y_ind++) {
             for (x_ind=0; x_ind<width-1; x_ind++) {
               tl = 1 + (width*y_ind)+x_ind
               tr = tl + 1
               bl = tl + width
               br = bl + 1

               if ((cell_nan[tl]+cell_nan[tr]+cell_nan[bl])==0) {
                 # Clockwise order for faces
                 print "f", tl "/" tl "/" tl, tr "/" tr "/" tr, bl "/" bl "/" bl
                 facecount+=1
               }
               if ((cell_nan[tr]+cell_nan[br]+cell_nan[bl])==0) {
                 print "f", tr "/" tr "/" tr, br "/" br "/" br, bl "/" bl "/" bl
                 facecount+=1
               }
             }
           }
           # print "Faces output:", facecount > "/dev/stderr"

         }' ${F_CPTS}seisdepth_fixed.cpt ${F_SLAB}fault_values_${i}.txt > ${F_3D}fault_${i}_presimplified.obj

         # Our approach leaves MANY unused vertices, so remove and update faces

         gawk < ${F_3D}fault_${i}_presimplified.obj '
         BEGIN {
           vertexind=1
           normalind=1
           textureind=1
           faceind=1
         }
         {
           if ($1=="v") {
             vertexdata[vertexind++]=$0
           } else if ($1=="vn") {
             normaldata[normalind++]=$0
           } else if ($1=="vt") {
             texturedata[textureind++]=$0
           } else if ($1=="f") {
             facedata[faceind]=$0
             i=1
             while($(i+1)!="") {
               split($(i+1), splitstr, "/")
               # Mark the vertex index as being seen
               # print "seeing vertex", splitstr[1]
               seenindex[splitstr[1]]=1
               faceindex[faceind][i]=splitstr[1]
               facecount[faceind]++
               i++
             }
             faceind++
           } else {
             print
           }
         }
         END {
           unseencount=0
           for (i=1; i<vertexind; i++) {
             if (seenindex[i]==0) {
               addme=1
             } else {
               addme=0
             }
             unseencount+=addme
             unseenbefore[i]=unseencount
             # print "Seen:", i, seenindex[i]
           }
           for (i=1; i<vertexind; i++) {
             if (seenindex[i]==1) {
               print vertexdata[i]
             }
           }
           for (i=1; i<normalind; i++) {
             if (seenindex[i]==1) {
               print normaldata[i]
             }
           }
           for (i=1; i<textureind; i++) {
             if (seenindex[i]==1) {
               print texturedata[i]
             }
           }

           for(i=1; i<faceind; i++) {
             # print facedata[i]
             printf("f ")
             for(j=1; j<= facecount[i]; j++) {
               vertbefore=faceindex[i][j]
               vertafter=vertbefore-unseenbefore[vertbefore]
               printf("%d/%d/%d ", vertafter, vertafter, vertafter)
             }
             printf("\n")
           }
         }
         ' > ${F_3D}fault_${i}.obj

         touch ${F_3D}faultdone
   done

cat <<-EOF >> ${F_3D}materials.mtl
newmtl FaultColor
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 1.0
illum 1
Ns 0.000000
EOF

fi



if [[ $makeplyflag -eq 1 && -s ${F_VOLC}volcanoes.dat && $plydemonlyflag -eq 0 ]]; then
  # volcanoes.dat contains lon lat elevation

cat <<-EOF >> ${F_3D}materials.mtl
newmtl VolcanoesColor
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 1.0
illum 1
Ns 0.000000
EOF

  PLY_VOLCSCALE=$(echo "${PLY_SCALE} * ${PLY_VOLCSCALE}" | bc -l)

  gawk -v cmttype=${CMTTYPE} -v v_exag=${PLY_VEXAG} -v v_scale=${PLY_VOLCSCALE} '
  @include "tectoplot_functions.awk"

  BEGIN {
    havematrix=0
    itemind=0
    sphereind=1
    vertexind=0
    print "mtllib materials.mtl"
  }

    # First input file is a template volcano OBJ

    (NR==FNR && substr($1,0,1) != "#" && $1 != "") {
      itemind++
      full[itemind]=$0
      for(ind=1;$(ind)!="";ind++) {
        obj[itemind][ind]=$(ind)
      }
      len[itemind]=ind-1
    }

    # Second input file is volcano points in the format
    # lon lat elev(m)

    (NR!=FNR) {

      depth=(6371+$3/1000*v_exag)/100
      lon=$1
      lat=$2
      phi=deg2rad(lon)
      theta=deg2rad(90-lat)

      xoff=depth*sin(theta)*cos(phi)
      yoff=depth*sin(theta)*sin(phi)
      zoff=depth*cos(theta)

      calc_ecef_to_enu_matrix(lon, lat)

      usedmtl=0
      print "o Volcanoes_" sphereind++
      vertexind=0
      for (this_ind in len) {
        if (obj[this_ind][1] == "v" || obj[this_ind][1] == "vn") {

            # Reorient the volcano OBJ from geocentric to E/N/U coordinates
            multiply_ecef_matrix(obj[this_ind][2], obj[this_ind][3], obj[this_ind][4])

            if (obj[this_ind][1]=="v") {
              # Vertex color is pure red
              print "v", w[0]*v_scale+xoff, w[1]*v_scale+yoff, w[2]*v_scale+zoff, 255, 0, 0
              vertexind++
            }
            if (obj[this_ind][1]=="vn") {
              print "vn", w[0], w[1], w[2]
            }

        } else if (obj[this_ind][1]=="f") {
          if (usedmtl==0) {
            print "usemtl VolcanoesColor"
            usedmtl=1
          }
          # Face vertices have to be incremented to account for prior volcanoes
          printf("f ")
          for (k=2; k<=len[this_ind]; k++) {
            printf("%d/%d/%d ", obj[this_ind][k]+lastvertexind,obj[this_ind][k]+lastvertexind,obj[this_ind][k]+lastvertexind)
          }
          printf("\n")
        } else if (obj[this_ind][1]=="vt") {

          printf("vt ")
          for (k=2; k<=len[this_ind]; k++) {
            printf("%s ", obj[this_ind][k])
          }
          printf("\n")
        }
      }
      # print lastvertexind, vertexind > "/dev/stderr"
      lastvertexind+=vertexind
    }
  ' ${VOLCANO_OBJ} ${F_VOLC}volcanoes.dat > ${F_3D}volcanoes.obj


fi


### TEST ARROWS FOR GPS; requires DEM to exist to get site elevations

if [[ $makeplyflag -eq 1 && -s ${F_TOPO}dem.nc && -s ${F_GPS}gps.txt && $plydemonlyflag -eq 0 ]]; then
  # gps.xy contains lon lat ve vn

cat <<-EOF >> ${F_3D}materials.mtl
newmtl GPSColor
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 1.0
illum 1
Ns 0.000000
EOF

  gawk < ${F_GPS}gps.txt '{print $1, $2, $3, $4}' | gmt grdtrack -G${F_TOPO}dem.nc > ${F_GPS}gps.xyz

  # gps.xyz:
  # Lon lat ve vn Elev(m)

  PLY_GPSSCALE=$(echo "${PLY_SCALE} * ${PLY_GPSSCALE}" | bc -l)

  gawk -v cmttype=${CMTTYPE} -v gps_fat=${PLY_GPSFATSCALE} -v v_exag=${PLY_VEXAG} -v v_scale=${PLY_GPSSCALE} -v velocity_scale=${PLY_GPS_VELSCALE} '
  @include "tectoplot_functions.awk"

  BEGIN {
    havematrix=0
    itemind=0
    sphereind=1
    vertexind=0
    print "mtllib materials.mtl"
  }

    # First input file is a template GPS arrow OBJ

    (NR==FNR && substr($1,0,1) != "#" && $1 != "") {
      itemind++
      full[itemind]=$0
      for(ind=1;$(ind)!="";ind++) {
        obj[itemind][ind]=$(ind)
      }
      len[itemind]=ind-1
    }

    # Second input file is gps.xyz points in the format
    # lon lat ve vn elev(m)

    (NR!=FNR) {

      depth=(6371+$5/1000*v_exag)/100
      lon=$1
      lat=$2
      phi=deg2rad(lon)
      theta=deg2rad(90-lat)

      velocity=sqrt($3*$3+$4*$4)*velocity_scale
      angle=azimuth_from_en($3, $4)
      # print "angle is", angle > "/dev/stderr"

      xoff=depth*sin(theta)*cos(phi)
      yoff=depth*sin(theta)*sin(phi)
      zoff=depth*cos(theta)

      calc_ecef_to_enu_matrix(lon, lat)
      sdr_rotation_matrix(90+angle, 0, 0)

      usedmtl=0
      print "o GPS_" sphereind++
      vertexind=0
      for (this_ind in len) {
        if (obj[this_ind][1] == "v" || obj[this_ind][1] == "vn") {

            # Rescale the GPS velocity by shifting vertices with Y!=0 by scale factor

            if (obj[this_ind][3] != 0) {
              rescale1=obj[this_ind][2]*gps_fat
              rescale2=obj[this_ind][3]*gps_fat+velocity
              rescale3=obj[this_ind][4]*gps_fat
            } else {
              rescale1=obj[this_ind][2]*gps_fat
              rescale2=obj[this_ind][3]
              rescale3=obj[this_ind][4]*gps_fat
            }

            # Reorient the GPS arrow based on VE/VN

            multiply_rotation_matrix(rescale1, rescale2, rescale3)

            # Reorient the GPS OBJ from geocentric to E/N/U coordinates
            # multiply_ecef_matrix(rescale1, rescale2, rescale3)
            multiply_ecef_matrix(v[0], v[1], v[2])

            if (obj[this_ind][1]=="v") {
              # Vertex color is pure red
              print "v", w[0]*v_scale+xoff, w[1]*v_scale+yoff, w[2]*v_scale+zoff, 255, 0, 0
              vertexind++
            }
            if (obj[this_ind][1]=="vn") {
              print "vn", w[0], w[1], w[2]
            }

        } else if (obj[this_ind][1]=="f") {
          if (usedmtl==0) {
            print "usemtl GPSColor"
            usedmtl=1
          }
          # Face vertices have to be incremented to account for prior GPS arrows
          printf("f ")
          for (k=2; k<=len[this_ind]; k++) {
            printf("%d/%d/%d ", obj[this_ind][k]+lastvertexind,obj[this_ind][k]+lastvertexind,obj[this_ind][k]+lastvertexind)
          }
          printf("\n")
        } else if (obj[this_ind][1]=="vt") {

          printf("vt ")
          for (k=2; k<=len[this_ind]; k++) {
            printf("%s ", obj[this_ind][k])
          }
          printf("\n")
        }
      }
      # print lastvertexind, vertexind > "/dev/stderr"
      lastvertexind+=vertexind
    }
  ' ${ARROW_OBJ} ${F_GPS}gps.xyz > ${F_3D}gps.obj


fi

#### END TEST ARROW





if [[ $makeplyflag -eq 1 ]]; then
  # This creates a timeframe combining the ply seismicity and the OBJ mesh
  #0.5 model.obj@t=tx,ty,tz@r=rx,ry,rz@s=sx,sy,sz (translation, rotation, scaling)

  # Create a black sphere 660 km deep inside the Earth, or deeper than the deepest
  # earthquake, to stop the transparency problem (if it is a global Earth)


  if [[ $closeglobeflag -eq 1 ]]; then
    echo "Making a sphere with radius ${sphere_rad} to go under the earthquakes"
cat <<-EOF > ${F_3D}insidearth.txt
0 0 0 ${sphere_rad} 0 0 0
EOF
    ${REPLICATE_OBS} ${REPLICATE_SPHERE4} ${F_3D}insidearth.txt > ${F_3D}inside_earth.obj
  fi

      printf "1 " > ${F_3D}sketchfab.timeframe
      firstfileflag=""

      if [[ -s ${F_3D}tectoplot.ply ]]; then
        printf "tectoplot.ply" >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -s ${F_3D}inside_earth.obj ]]; then
          printf "%sinside_earth.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
          firstfileflag="+"
      fi
      if [[ -s ${F_3D}box.obj ]]; then
          printf "%sbox.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
          firstfileflag="+"
      fi
      if [[ -s ${F_3D}focal_mechanisms.obj ]]; then
          printf "%sfocal_mechanisms.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
          firstfileflag="+"
      fi
      if [[ -s ${F_3D}sideboxnorth.obj ]]; then
        printf "%ssideboxnorth.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -s ${F_3D}sideboxeast.obj ]]; then
        printf "%ssideboxeast.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -s ${F_3D}sideboxsouth.obj ]]; then
        printf "%ssideboxsouth.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -s ${F_3D}sideboxwest.obj ]]; then
        printf "%ssideboxwest.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -s ${F_3D}oceannorth.obj ]]; then
        printf "%soceannorth.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -s ${F_3D}OceanTop.obj ]]; then
        printf "%sOceanTop.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -s ${F_3D}oceaneast.obj ]]; then
        printf "%soceaneast.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -s ${F_3D}oceansouth.obj ]]; then
        printf "%soceansouth.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -s ${F_3D}oceanwest.obj ]]; then
        printf "%soceanwest.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -s ${F_3D}volcanoes.obj ]]; then
          printf "%svolcanoes.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
          firstfileflag="+"
      fi
      if [[ -s ${F_3D}${PLY_MTLNAME}.obj ]]; then
          printf "%s${PLY_MTLNAME}.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
          firstfileflag="+"
      else
        if [[ -s ${F_3D}tectoplot_surface.ply ]]; then
          printf "%stectoplot_surface.ply" $firstfileflag >> ${F_3D}sketchfab.timeframe
          firstfileflag="+"
        fi
      fi
      if [[ -s ${F_3D}${PLY_TEXTCODE}.obj ]]; then
        printf "%s${PLY_TEXTCODE}.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -s ${F_3D}gps.obj ]]; then
        printf "%sgps.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -s ${F_3D}floating_text.obj ]]; then
        printf "%sfloating_text.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      if [[ -e ${F_3D}slabdone ]]; then
        for slabf in ${F_3D}slab_*.obj; do
          printf "%s${slabf}@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
          firstfileflag="+"
        done
      fi
      if [[ -e ${F_3D}faultdone ]]; then
        for faultf in ${F_3D}fault_*.obj; do
          printf "%s${faultf}@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
          firstfileflag="+"
        done
      fi
      if [[ -s ${F_3D}eq_poly.obj ]]; then
        printf "%seq_poly.obj@r=-90,0,0" $firstfileflag >> ${F_3D}sketchfab.timeframe
        firstfileflag="+"
      fi
      printf "\n" >> ${F_3D}sketchfab.timeframe

#slab_material.mtl volcanoes.mtl focsphere.mtl sphere.mtl
      cd ${F_3D}

      if [[ $addobjflag -eq 1 ]]; then
        for objfile in ${ADDOBJFILE[@]}; do
          ADDOBJPATH=$(basename ${objfile})
          info_msg "Copying OBJ file ${objfile} to ${ADDOBJPATH}"
          cp ${objfile} ${ADDOBJPATH}
          gawk < sketchfab.timeframe -v addp=${ADDOBJPATH} '{
            print $0 "+" addp "@r=-90,0,0"
          }' > sketchfab.timeframe.2
          mv  sketchfab.timeframe.2  sketchfab.timeframe
          ALLADDOBJPATHS+=("${ADDOBJPATH}")
        done
      else
        ALLADDOBJPATHS=""
      fi
      if [[ $addmtlflag -eq 1 ]]; then
        for mtlfile in ${ADDOBJMTL[@]}; do
          info_msg "Adding material file ${mtlfile} to materials.mtl"
          cat ${mtlfile} >> materials.mtl
        done
      fi
      if [[ $addtexflag -eq 1 ]]; then
        for texfile in ${ADDOBJTEX[@]}; do
          ADDOBJTEXPATH=Textures/"$(basename ${texfile})"
          info_msg "Copying texture file ${texfile} to ${ADDOBJTEXPATH}"
          cp ${texfile} ${ADDOBJTEXPATH}
          ALLADDOBJTEXPATHS+=("${ADDOBJTEXPATH}")
        done
      else
        ADDOBJTEXPATH=""
      fi

      gawk < materials.mtl '
      BEGIN {
        counter=1
      }
      {
        if ($1=="Ka" && $2+0 > 0.99) {
          print "Ka", $3-counter*0.000001, $3-counter*0.000001, $3-counter*0.000001
        } else if ($1=="Kd" && $2+0 > 0.99) {
          print "Kd", $3-counter*0.000001, $3-counter*0.000001, $3-counter*0.000001
        } else if ($1=="Ks") {
          print "Ks 0.00000 0.00000 0.00000"
        } else {
          print
          counter--
        }
        counter++
      }
      ' > materials_fixed.mtl
      mv materials_fixed.mtl materials.mtl

      rm -f Textures/*.xml
      # Textures/sidebox.png

      zip tectoplot_sketchfab.zip ${ALLADDOBJPATHS[@]} ${ALLADDOBJTEXPATHS[@]} gps.obj floating_text.obj Textures/${PLY_TEXTCODE}.png ${PLY_TEXTCODE}.obj basetext.obj Textures/SideboxEast.png Textures/SideboxWest.png Textures/SideboxNorth.png Textures/SideboxSouth.png Textures/water.jpg OceanTop.obj ocean*.obj volcanoes.obj slab_*.obj fault_*.obj focal_mechanisms.obj sideboxnorth.obj sideboxwest.obj sideboxeast.obj sideboxsouth.obj Textures/focaltexture.jpg box.obj inside_earth.obj eq_poly.obj sketchfab.timeframe ${PLY_MTLNAME}.obj tectoplot.ply tectoplot_surface.ply materials.mtl Textures/${PLY_TEXNAME} Textures/alpha_* > /dev/null 2>&1
      cd ..
fi
