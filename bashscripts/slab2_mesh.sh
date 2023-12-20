#!/bin/bash

# Plan: make an OBJ with all of the grid vertices and then cull any faces that
# reference a NaN vertex.

if [[ $makeplyflag -eq 1 && $makeplyslab2meshflag -eq 1 ]]; then

  SLABDEPFILE=" ~/Dropbox/TectoplotData/SLAB2/Slab2Distribute_Mar2018/cam_slab2_dep_02.24.18.grd"

  info_msg "[-makeply]: Making mesh surfaces of Slab2 interface"
        # Now convert the DEM to an OBJ format surface at the same scaling factor
        # Default format is scanline orientation of ASCII numbers: −ZTLa. Note that −Z only applies to 1-column output.

        gmt grdcut ${SLABDEPFILE} -R${F_TOPO}dem.nc -G ${F_SLAB}slabcut_n.grd
        SLAB_DEP=${F_SLAB}slabcut_n.grd

        dem_orig_info=($(gmt grdinfo ${SLAB_DEP} -C -Vn))
        dem_numx=${dem_orig_info[9]}
        dem_numy=${dem_orig_info[10]}

        dem_minlon=${dem_orig_info[1]}
        dem_maxlon=${dem_orig_info[2]}

        gmt grd2xyz ${SLAB_DEP} -C ${VERBOSE} > ${F_SLAB}slab_indices.txt
        gmt grd2xyz ${SLAB_DEP} ${VERBOSE} > ${F_SLAB}slab_values.txt

        gawk -v width=${dem_numx} -v height=${dem_numy} '
        @include "tectoplot_functions.awk"
           BEGIN {
             # colorind=0
             vertexind=1
             # Set up the material file
             print "mtllib slab_material.mtl"
             minphi="none"
             maxphi="none"
             mintheta="none"
             maxtheta="none"
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

           # Read the vertices (Slab grid points) second
         (NR!=FNR) {
           # if (minphi == "none") {
           #   minphi = $1
           # } else if (minphi > $1) {
           #   minphi = $1
           # }
           # if (maxphi == "none") {
           #   maxphi = $1
           # } else if (maxphi < $1) {
           #   maxphi = $1
           # }
           #
           # if (mintheta == "none") {
           #   mintheta = $2
           # } else if (mintheta > $2) {
           #   mintheta = $2
           # }
           # if (maxtheta == "none") {
           #   maxtheta = $2
           # } else if (maxtheta < $2) {
           #   maxtheta = $2
           # }

           #
           # if (closeglobe == 1) {
           #   if (vector_phi[i]==minphi) {
           #     vector_phi[i]=-180
           #   }
           #   if (vector_phi[i]==maxphi) {
           #     vector_phi[i]=180
           #   }
           #   if (vector_co_theta[i]==mintheta) {
           #     vector_co_theta[i]=-90
           #   }
           #   if (vector_co_theta[i]==maxtheta) {
           #     vector_co_theta[i]=90
           #   }
           # }

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

           if (tolower($3) == "nan") {
             $3=-6000
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

             # if (closeglobe==1) {
             #   if (phiarr[i]==minphi) {
             #     # print "fixing phi=" phiarr[i] "at position", x_arr[i], y_arr[i] > "/dev/stderr"
             #     phi=deg2rad(-180)
             #     theta=deg2rad(90-thetaarr[i])
             #     vectorx[i]=rarr[i]*sin(theta)*cos(phi)
             #     vectory[i]=rarr[i]*sin(theta)*sin(phi)
             #     vectorz[i]=rarr[i]*cos(theta)
             #   }
             #   if (phiarr[i]==maxphi) {
             #     # print "fixing phi=" phiarr[i] "at position", x_arr[i], y_arr[i] > "/dev/stderr"
             #     phi=deg2rad(180)
             #     theta=deg2rad(90-thetaarr[i])
             #     vectorx[i]=rarr[i]*sin(theta)*cos(phi)
             #     vectory[i]=rarr[i]*sin(theta)*sin(phi)
             #     vectorz[i]=rarr[i]*cos(theta)
             #   }
             # }

           }

           print "o SlabMesh"

           for (i=1; i<=num_vertices; i++) {
             # The following line places the color index for each vertex... comment out for now
             # print "v", vectorx[i], vectory[i], vectorz[i], red[vertexcolor[i]], green[vertexcolor[i]], blue[vertexcolor[i]]
             print "v", vectorx[i], vectory[i], vectorz[i], 255, 255, 255
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
           # surrounding vertices are not NaN cells
           
           facecount=0
           for (y_ind=0; y_ind<height-1; y_ind++) {
             for (x_ind=0; x_ind<width-1; x_ind++) {
               tl = 1 + (width*y_ind)+x_ind
               tr = tl + 1
               bl = tl + width
               br = bl + 1

               if ((cell_nan[tl]+cell_nan[tr]+cell_nan[bl]+cell_nan[br])==0) {
                 # Clockwise order for faces
                 print "f", tl "/" tl "/" tl, tr "/" tr "/" tr, bl "/" bl "/" bl
                 print "f", tr "/" tr "/" tr, br "/" br "/" br, bl "/" bl "/" bl
                 facecount+=2
               }
             }
           }
           # print "Faces output:", facecount > "/dev/stderr"

         }' ${F_CPTS}seisdepth.cpt ${F_SLAB}slab_values.txt > ${F_3D}slab.obj
fi

cat <<-EOF > ${F_3D}slab_material.mtl
newmtl SlabColor
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
Tr 0.6000000
illum 1
Ns 0.000000
EOF

    # This adds the seismicity point cloud to the end of the OBJ
    # if [[ -s tectoplot_vertex.ply ]]; then
    #   gawk < tectoplot_vertex.ply '{print "v", $0; print "p -1"; }' >> dem.obj
    # fi

    # Export the texture as JPG in case TIF doesn't work...

    if [[ ! -s ${F_TOPO}colored_intensity.tif ]]; then
      if [[ -s ${F_TOPO}colored_relief.tif ]]; then
        gdal_translate -q -of "JPEG" ${F_TOPO}colored_relief.tif ${F_3D}colored_intensity.jpg
      fi
    else
      gdal_translate -q -of "JPEG" ${F_TOPO}colored_intensity.tif ${F_3D}colored_intensity.jpg
    fi
fi
