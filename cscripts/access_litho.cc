/*
 *  access_litho
 *  written by Michael Pasyanos
 *  December, 2012
 *
 *  program to access LITHO1.0 model at lat/lon pair or lat/lon/depth point
 */

#ifndef MODELLOC
#define MODELLOC "/Users/Pasyanos/Work/LITHO1.0"
#endif

#ifndef TEST
#define TEST 2
#endif

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string>
#include <cstring>

#include <fstream>
#include <iostream>
using namespace std;

#define MAXLAYERS 250

#define PI 3.14159265
#define R 6371.
#define DEGTORAD (PI/180.)

class earthLayers {
public:
        float depth;
        float pvel;
        float svel;
        float density;
        float qkappa;
        float qshear;
        float pvel2;
        float svel2;
        float eta;
        char layertype[20];
 };

class earthModel {
public:
        int numlayers;
        int num_ic_layers;
        int num_oc_layers;
        earthLayers layers[MAXLAYERS];
};

int main(int argc, char* argv[])
{
		FILE *fp;
		int i;

		float latitude, glatitude, longitude;
        float latitude0, longitude0, depth0;
        float lat0, lon0;
        float lat1, lon1;

        float dlat, dlon, a, dist;

        float minlat1, minlon1, mindist1;
        int minnode1;

        float minlat2, minlon2, mindist2;
        int minnode2;

        float minlat3, minlon3, mindist3;
        int minnode3;

		int level, n1, node, mode; /* profile mode=0; point mode=1 */
		int debug = 0;
		int stack_flag = 0; /* only the lithosphere */

/* assumes you want level 7, unless you specify other */
		level = 7;
/* default is profile mode */
		mode = 0;

		if(argc==1){
            fprintf(stderr,"ERROR: No arguments\n");
            fprintf(stderr,"type \"access_litho -h\" for help\n");
			exit(-1);
		}

    	for (i = 1; i < argc; i++)
    	{
        	char const *option =  argv[i];
        	if (option[0] == '-')
        	{
            	switch (option[1])
            	{
                	case 'd':
                		depth0 = atof(argv[i+1]);
                		i = i + 1;
                		mode = 1;
                    	break;
                	case 'e':
                    	stack_flag = 1; /* whole stack */
                    	break;
                	case 'h':
        				fprintf(stderr,"access_litho -p lat lon [ -d depth] [-l level] [-e] [-h]\n");
        				fprintf(stderr,"  -h help \n");
        				fprintf(stderr,"  -p lat lon (runs in profile mode)\n");
        				fprintf(stderr,"  -d depth (runs in point mode)\n");
        				fprintf(stderr,"  -l level \n");
        				exit(-1);
                	case 'l':
						level = atoi(argv[i+1]);
            			fprintf(stderr,"level = %d\n", level);
						i = i + 1;
						break;
                	case 'p':
                		latitude0 = atof(argv[i+1]);
                		longitude0 = atof(argv[i+2]);
                		i = i + 2;
                    	break;
                	default:
                    	printf("ERROR: flag not recognised %s\n", option);
            			fprintf(stderr,"type \"access_litho -h\" for help\n");
                    	exit(-1);
            	}
        	}
        	else
        	{
            	fprintf(stderr,"ERROR: Invalid argument\n");
            	fprintf(stderr,"argv[%d] = %s\n", i, argv[i]);
            	fprintf(stderr,"type \"access_litho -h\" for help\n");
            	exit(-1);
        	}
        }

        if(debug) fprintf(stdout,"%f %f\n", latitude0, longitude0);

		if(level >= 1) n1 = 12;
		if(level >= 2) n1 = 4*n1 - 6;
		if(level >= 3) n1 = 4*n1 - 6;
		if(level >= 4) n1 = 4*n1 - 6;
		if(level >= 5) n1 = 4*n1 - 6;
		if(level >= 6) n1 = 4*n1 - 6;
		if(level >= 7) n1 = 4*n1 - 6;
		if(debug) fprintf(stdout,"level = %d, n1 = %d\n", level, n1);

		mindist1 = 1.0e5;
		mindist2 = 2.0e5;
		mindist3 = 3.0e5;

		char tessfile[200];
		sprintf(tessfile,"%s/Icosahedron_Level7_LatLon_mod.txt", MODELLOC);
        if( (fp = fopen(tessfile,"r")) == 0){
                fprintf(stdout,"ERROR: Could not open file %s\n", tessfile);
                exit (1);
        }

		/*  this is our target point.  convert to radians */
		lat0 = latitude0*DEGTORAD;
		lon0 = longitude0*DEGTORAD;

		node = 0;
		while(fscanf(fp,"%f %f %f", &latitude, &glatitude, &longitude) != EOF){

		/* read in a point and convert it to radians to compare */

			++node;
			/* fprintf(stdout,"%d %f %f %f\n", node, latitude, glatitude, longitude);  */

			lat1=latitude*DEGTORAD;
			lon1=longitude*DEGTORAD;

			/* calculate the delta lat and lon from the target point */
			dlat=lat0-lat1;
			dlon=lon0-lon1;
			a = sin(dlat/2)*sin(dlat/2) + cos(lat1)*cos(lat0)*sin(dlon/2)*sin(dlon/2);
			dist = R * 2*atan2(sqrt(a),sqrt(1-a));
			if(debug && dist < 200.) fprintf(stderr,"node = %d, dist = %f\n", node, dist);

			if(dist < mindist1 && node <= n1){
				mindist3 = mindist2;
				minlat3 = minlat2;
				minlon3 = minlon2;
				minnode3 = minnode2;

				mindist2 = mindist1;
				minlat2 = minlat1;
				minlon2 = minlon1;
				minnode2 = minnode1;

				mindist1 = dist;
				minlat1 = lat1;
				minlon1 = lon1;
				minnode1 = node;

			}
			else if(dist < mindist2 && node <= n1){
				mindist3 = mindist2;
				minlat3 = minlat2;
				minlon3 = minlon2;
				minnode3 = minnode2;

				mindist2 = dist;
				minlat2 = lat1;
				minlon2 = lon1;
				minnode2 = node;
			}
			else if(dist < mindist3 && node <= n1){
				mindist3 = dist;
				minlat3 = lat1;
				minlon3 = lon1;
				minnode3 = node;
			}

		}

		fclose(fp);

		minlat1 /= DEGTORAD;
		minlon1 /= DEGTORAD;

		minlat2 /= DEGTORAD;
		minlon2 /= DEGTORAD;

		minlat3 /= DEGTORAD;
		minlon3 /= DEGTORAD;

		if(debug){
			fprintf(stdout,"MINDIST LAT LON NODE\n");
			fprintf(stdout,"%f %f %f %d\n", mindist1, minlat1, minlon1, minnode1);
			fprintf(stdout,"%f %f %f %d\n", mindist2, minlat2, minlon2, minnode2);
			fprintf(stdout,"%f %f %f %d\n", mindist3, minlat3, minlon3, minnode3);
		}

		/* for tests, set these */
		//minnode1 = 301;
		//minnode2 = 1172;
		//minnode3 = 1176;

		/* get weights of Barycentric coordinate system */

		double lambda1, lambda2, lambda3;

		lambda1 = ((minlon2-minlon3)*(latitude0-minlat3) + (minlat3-minlat2)*(longitude0-minlon3))/((minlon2-minlon3)*(minlat1-minlat3) + (minlat3-minlat2)*(minlon1-minlon3));
		lambda2 = ((minlon3-minlon1)*(latitude0-minlat3) + (minlat1-minlat3)*(longitude0-minlon3))/((minlon2-minlon3)*(minlat1-minlat3) + (minlat3-minlat2)*(minlon1-minlon3));
		lambda3 = 1 - lambda1 - lambda2;

		if(debug) fprintf(stdout,"\n%f %f %f\n", lambda1, lambda2, lambda3);

		FILE *fp1, *fp2, *fp3;
		int nlayers1, nlayers2, nlayers3;
		char modelfile[200];
		earthModel model1, model2, model3;

		sprintf(modelfile,"%s/node%d.model", MODELLOC, minnode1);
        if( (fp1 = fopen(modelfile,"r")) == 0){
                fprintf(stdout,"ERROR: Could not open file %s\n", modelfile);
                exit (1);
        }
		fscanf(fp1,"%*s %*s %d", &nlayers1);
		model1.numlayers = nlayers1;
//        model1.num_ic_layers = 25;
//        model1.num_oc_layers = 71;
		if(debug) fprintf(stdout,"nlayers1 = %d\n", nlayers1);

		sprintf(modelfile,"%s/node%d.model", MODELLOC, minnode2);
        if( (fp2 = fopen(modelfile,"r")) == 0){
                fprintf(stdout,"ERROR: Could not open file %s\n", modelfile);
                exit (1);
        }
		fscanf(fp2,"%*s %*s %d", &nlayers2);
		model2.numlayers = nlayers2;
//        model2.num_ic_layers = 25;
//        model2.num_oc_layers = 71;
		if(debug) fprintf(stdout,"nlayers2 = %d\n", nlayers2);

		sprintf(modelfile,"%s/node%d.model", MODELLOC, minnode3);
        if( (fp3 = fopen(modelfile,"r")) == 0){
                fprintf(stdout,"ERROR: Could not open file %s\n", modelfile);
                exit (1);
        }
		fscanf(fp3,"%*s %*s %d", &nlayers3);
		model3.numlayers = nlayers3;
//        model3.num_ic_layers = 25;
//        model3.num_oc_layers = 71;
		if(debug) fprintf(stdout,"nlayers3 = %d\n", nlayers3);

		i = 0;
		while(fscanf(fp1,"%f %f %f %f %f %f %f %f %f %s", &model1.layers[i].depth, &model1.layers[i].density,
				&model1.layers[i].pvel, &model1.layers[i].svel, &model1.layers[i].qkappa, &model1.layers[i].qshear,
				&model1.layers[i].pvel2, &model1.layers[i].svel2, &model1.layers[i].eta, model1.layers[i].layertype) != EOF){
            ++i;
		}
		i = 0;
		while(fscanf(fp2,"%f %f %f %f %f %f %f %f %f %s", &model2.layers[i].depth, &model2.layers[i].density,
				&model2.layers[i].pvel, &model2.layers[i].svel, &model2.layers[i].qkappa, &model2.layers[i].qshear,
				&model2.layers[i].pvel2, &model2.layers[i].svel2, &model2.layers[i].eta, model2.layers[i].layertype) != EOF){
        	++i;
		}
		i = 0;
		while(fscanf(fp3,"%f %f %f %f %f %f %f %f %f %s", &model3.layers[i].depth, &model3.layers[i].density,
				&model3.layers[i].pvel, &model3.layers[i].svel, &model3.layers[i].qkappa, &model3.layers[i].qshear,
				&model3.layers[i].pvel2, &model3.layers[i].svel2, &model3.layers[i].eta, model3.layers[i].layertype) != EOF){
            ++i;
		}

		fclose(fp1);
		fclose(fp2);
		fclose(fp3);

/* use weights in interpolating all values */

/* lets try and find a specific layer */

		char **layertype;
 		layertype = (char **) calloc(MAXLAYERS, sizeof(char *));
    	for(i=0; i<MAXLAYERS; ++i){
    		layertype[i] = (char *)calloc(20, sizeof(char));
    	}

    	int k=0;

    	char string[20];
    	for(i=0; i<=24; ++i){
    		sprintf(string,"IC%d", i);
    		strcpy(layertype[++k], string);
    	}
    	for(i=0; i<=45; ++i){
    		sprintf(string,"OC%d", i);
    		strcpy(layertype[++k], string);
    	}
    	for(i=0; i<=71; ++i){
    		sprintf(string,"M%d", i);
    		strcpy(layertype[++k], string);
    	}

    	strcpy(layertype[++k],"A-BOTTOM");
    	strcpy(layertype[++k],"A-TOP");

    	strcpy(layertype[++k],"ASTHENO-BOTTOM");
    	strcpy(layertype[++k],"ASTHENO-TOP");

    	strcpy(layertype[++k],"LID-BOTTOM");
    	strcpy(layertype[++k],"LID-TOP");

    	strcpy(layertype[++k],"CRUST3-BOTTOM");
    	strcpy(layertype[++k],"CRUST3-TOP");
    	strcpy(layertype[++k],"CRUST2-BOTTOM");
    	strcpy(layertype[++k],"CRUST2-TOP");
    	strcpy(layertype[++k],"CRUST1-BOTTOM");
    	strcpy(layertype[++k],"CRUST1-TOP");

    	strcpy(layertype[++k],"SEDS3-BOTTOM");
    	strcpy(layertype[++k],"SEDS3-TOP");
    	strcpy(layertype[++k],"SEDS2-BOTTOM");
    	strcpy(layertype[++k],"SEDS2-TOP");
    	strcpy(layertype[++k],"SEDS1-BOTTOM");
    	strcpy(layertype[++k],"SEDS1-TOP");

    	strcpy(layertype[++k],"ICE-BOTTOM");
    	strcpy(layertype[++k],"ICE-TOP");

    	strcpy(layertype[++k],"WATER-BOTTOM");
    	strcpy(layertype[++k],"WATER-TOP");

      	float sum, depth, den, pvel, svel, qkappa, qshear, pvel2, svel2, eta;
      	float tmp_depth, tmp_den, tmp_pvel, tmp_svel, tmp_qkappa, tmp_qshear, tmp_pvel2, tmp_svel2, tmp_eta;
		float tmp1_depth, tmp1_den, tmp1_pvel, tmp1_svel, tmp1_qkappa, tmp1_qshear, tmp1_pvel2, tmp1_svel2, tmp1_eta;
		float tmp2_depth, tmp2_den, tmp2_pvel, tmp2_svel, tmp2_qkappa, tmp2_qshear, tmp2_pvel2, tmp2_svel2, tmp2_eta;
		float tmp3_depth, tmp3_den, tmp3_pvel, tmp3_svel, tmp3_qkappa, tmp3_qshear, tmp3_pvel2, tmp3_svel2, tmp3_eta;
		int tmp1_layer, tmp2_layer, tmp3_layer;
		int tmp1_flag, tmp2_flag, tmp3_flag;

		int j;

		for(j=0; j<=k; ++j){
			tmp1_flag = 0;
			tmp2_flag = 0;
			tmp3_flag = 0;
/* if layer does not exist, use depth from previous layer */
/* use tmp_flag to make sure you don't use the parameter values */

			for(i=0; i<model1.numlayers; ++i){
				if(strcmp(model1.layers[i].layertype,layertype[j])==0){
					tmp1_depth = model1.layers[i].depth;
					tmp1_den = model1.layers[i].density;
					tmp1_pvel = model1.layers[i].pvel;
					tmp1_svel = model1.layers[i].svel;
					tmp1_qkappa = model1.layers[i].qkappa;
					tmp1_qshear = model1.layers[i].qshear;
					tmp1_pvel2 = model1.layers[i].pvel2;
					tmp1_svel2 = model1.layers[i].svel2;
					tmp1_eta = model1.layers[i].eta;

					tmp1_flag = 1;
					tmp1_layer = i;
				}
			}
			for(i=0; i<model2.numlayers; ++i){
				if(strcmp(model2.layers[i].layertype,layertype[j])==0){
					tmp2_depth = model2.layers[i].depth;
					tmp2_den = model2.layers[i].density;
					tmp2_pvel = model2.layers[i].pvel;
					tmp2_svel = model2.layers[i].svel;
					tmp2_qkappa = model2.layers[i].qkappa;
					tmp2_qshear = model2.layers[i].qshear;
					tmp2_pvel2 = model2.layers[i].pvel2;
					tmp2_svel2 = model2.layers[i].svel2;
					tmp2_eta = model2.layers[i].eta;

					tmp2_flag = 1;
					tmp2_layer = i;
				}
			}
			for(i=0; i<model3.numlayers; ++i){
				if(strcmp(model3.layers[i].layertype,layertype[j])==0){
					tmp3_depth = model3.layers[i].depth;
					tmp3_den = model3.layers[i].density;
					tmp3_pvel = model3.layers[i].pvel;
					tmp3_svel = model3.layers[i].svel;
					tmp3_qkappa = model3.layers[i].qkappa;
					tmp3_qshear = model3.layers[i].qshear;
					tmp3_pvel2 = model3.layers[i].pvel2;
					tmp3_svel2 = model3.layers[i].svel2;
					tmp3_eta = model3.layers[i].eta;

					tmp3_flag = 1;
					tmp3_layer = i;
				}
			}

			sum = (lambda1 * tmp1_flag + lambda2 * tmp2_flag + lambda3 * tmp3_flag);

			depth = (lambda1 * tmp1_depth + lambda2 * tmp2_depth + lambda3 * tmp3_depth);
			den = (lambda1 * tmp1_flag * tmp1_den + lambda2 * tmp2_flag * tmp2_den + lambda3 * tmp3_flag * tmp3_den) / sum;
			pvel = (lambda1 * tmp1_flag * tmp1_pvel + lambda2 * tmp2_flag * tmp2_pvel + lambda3 * tmp3_flag * tmp3_pvel) / sum;
			svel = (lambda1 * tmp1_flag * tmp1_svel + lambda2 * tmp2_flag * tmp2_svel + lambda3 * tmp3_flag * tmp3_svel) / sum;
			qkappa = (lambda1 * tmp1_flag * tmp1_qkappa + lambda2 * tmp2_flag * tmp2_qkappa + lambda3 * tmp3_flag * tmp3_qkappa) / sum;
			qshear = (lambda1 * tmp1_flag * tmp1_qshear + lambda2 * tmp2_flag * tmp2_qshear + lambda3 * tmp3_flag * tmp3_qshear) / sum;
			pvel2 = (lambda1 * tmp1_flag * tmp1_pvel2 + lambda2 * tmp2_flag * tmp2_pvel2 + lambda3 * tmp3_flag * tmp3_pvel2) / sum;
			svel2 = (lambda1 * tmp1_flag * tmp1_svel2 + lambda2 * tmp2_flag * tmp2_svel2 + lambda3 * tmp3_flag * tmp3_svel2) / sum;
			eta = (lambda1 * tmp1_flag * tmp1_eta + lambda2 * tmp2_flag * tmp2_eta + lambda3 * tmp3_flag * tmp3_eta) / sum;

			if((strcmp(layertype[j],"IC0")==0) && ((tmp1_flag==0) || (tmp2_flag==0) || (tmp3_flag==0)) ) {
				/* throw an error if there is no IC0 layer, it means that one of the nodes is missing */
				if(tmp1_flag==0) fprintf(stderr,"ERROR: Missing node = %d\n", minnode1);
				if(tmp2_flag==0) fprintf(stderr,"ERROR: Missing node = %d\n", minnode2);
				if(tmp3_flag==0) fprintf(stderr,"ERROR: Missing node = %d\n", minnode3);
				return -1;
			}

			/* profile mode */
			/* only print a layer if it actually exists */
			if(mode == 0 && sum > 0.0){
				if(stack_flag == 1 || j >= (k-18) ){
					fprintf(stdout,"%7.0f. %8.2f %8.2f %8.2f %7.2f %7.2f %8.2f %8.2f %7.5f %s\n",
						depth, den, pvel, svel, qkappa, qshear, pvel2, svel2, eta, layertype[j]);
					}
			}

			/* point mode */
/*			if(mode==1 && sum > 0.0 && (depth/1000. <= depth0) && (tmp_depth/1000. >= depth0) ){  */
			if(mode==1 && sum > 0.0 && (depth/1000. <= depth0) && (tmp_depth/1000. > depth0) ){
				if(debug){
					fprintf(stdout,"%7.0f. %8.2f %8.2f %8.2f %7.2f %7.2f %8.2f %8.2f %7.5f %s\n",
						tmp_depth, tmp_den, tmp_pvel, tmp_svel, tmp_qkappa, tmp_qshear, tmp_pvel2, tmp_svel2, tmp_eta, layertype[j-1]);
					fprintf(stdout,"%7.0f. %8.2f %8.2f %8.2f %7.2f %7.2f %8.2f %8.2f %7.5f %s\n",
						depth, den, pvel, svel, qkappa, qshear, pvel2, svel2, eta, layertype[j]);
				}
				/* interpolate to get the results */
				tmp_den = tmp_den + (den-tmp_den)*(depth0*1000.-tmp_depth)/(depth-tmp_depth);
				tmp_pvel = tmp_pvel + (pvel-tmp_pvel)*(depth0*1000.-tmp_depth)/(depth-tmp_depth);
				tmp_svel = tmp_svel + (svel-tmp_svel)*(depth0*1000.-tmp_depth)/(depth-tmp_depth);
				tmp_qkappa = tmp_qkappa + (qkappa-tmp_qkappa)*(depth0*1000.-tmp_depth)/(depth-tmp_depth);
				tmp_qshear = tmp_qshear + (qshear-tmp_qshear)*(depth0*1000.-tmp_depth)/(depth-tmp_depth);
				tmp_pvel2 = tmp_pvel2 + (pvel2-tmp_pvel2)*(depth0*1000.-tmp_depth)/(depth-tmp_depth);
				tmp_svel2 = tmp_svel2 + (svel2-tmp_svel2)*(depth0*1000.-tmp_depth)/(depth-tmp_depth);
				tmp_eta = tmp_eta + (eta-tmp_eta)*(depth0*1000.-tmp_depth)/(depth-tmp_depth);

				fprintf(stdout,"%7.0f. %8.2f %8.2f %8.2f %7.2f %7.2f %8.2f %8.2f %7.5f %s %s\n",
					depth0*1000., tmp_den, tmp_pvel, tmp_svel, tmp_qkappa, tmp_qshear, tmp_pvel2, tmp_svel2, tmp_eta, layertype[j-1], layertype[j]);
			}
			/* for point mode, save previous layer before moving on */
			if(mode==1 && sum > 0.0){
				tmp_depth = depth;
				tmp_den = den;
				tmp_pvel = pvel;
				tmp_svel = svel;
				tmp_qkappa = qkappa;
				tmp_qshear = qshear;
				tmp_pvel2 = pvel2;
				tmp_svel2 = svel2;
				tmp_eta = eta;
			}

		}

		return 0;
}
