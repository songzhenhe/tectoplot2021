rm -f sp.obj

gawk < hex.obj '
function max(x,y)      { return (x>y)?x:y               }
function min(x,y)      { return (x<y)?x:y               }
function getpi()       { return atan2(0,-1)             }
function abs(v)        { return v < 0 ? -v : v          }
function tan(x)        { return sin(x)/cos(x)           }
function atan(x)       { return atan2(x,1)              }
function asin(x)       { return atan2(x, sqrt(1-x*x))   }
function acos(x)       { return atan2(sqrt(1-x*x), x)   }
function rad2deg(rad)  { return (180 / getpi()) * rad   }
function deg2rad(deg)  { return (getpi() / 180) * deg   }
function hypot(x,y)    { return sqrt(x*x+y*y)           }
function d_atan2d(y,x) { return (x == 0.0 && y == 0.0) ? 0.0 : rad2deg(atan2(y,x)) }
function ddiff(u)      { return u > 180 ? 360 - u : u   }
function ceil(x)       { return int(x)+(x>int(x))       }
function sinsq(x)      { return sin(x)*sin(x)           }
function cossq(x)      { return cos(x)*cos(x)           }
BEGIN {
  r=1
}

{
  if ($1=="v" || $1=="vn") {
    vlen=sqrt($2*$2+$3*$3+$4*$4)
    print $1, $2/vlen, $3/vlen, $4/vlen
    # theta=-rad2deg(acos($4))+90
    # phi=rad2deg(atan2($2,$3))
    # thetarad=deg2rad(theta)
    # phirad=deg2rad(phi)
    # print "v", $2, $3, $4, "|", r*sin(thetarad)*cos(phirad), r*sin(thetarad)*sin(phirad), r*cos(thetarad) > "sp.obj"

  }
}
'



           # phi=deg2rad($1)
           # theta=deg2rad(90-$2)
           #
           # if (tolower($3) == "nan") {
           #   $3=-6000
           #   cell_nan[vertexind]=1
           # }
           #
           # if ($2 < minlat || $2 > maxlat || test_lon(minlon, maxlon, $1) == 0) {
           #   cell_nan[vertexind]=1
           # }
           #
           # r=(6371+$3)/100
           #
           # # r = 6371/100 (Earth radius) for grid cells with values of NaN
           #
           # # Calculate the vector for each vertex (center of Earth to vertex point)
           # vectorx[vertexind]=r*sin(theta)*cos(phi)
           # vectory[vertexind]=r*sin(theta)*sin(phi)
           # vectorz[vertexind]=r*cos(theta)
