#include "RayTrace.cginc"

float3 worldhit(in float3 ro, in float3 rd, in float2 dist, out float3 normal) {
	float3 tmp0; 
	float3 tmp1; 
	float3 d = float3(dist, 0.);

	d = opU(d, iPlane(ro, rd, d.xy, normal, float3(0, 1, 0), 0.), 1.);

	d = opU(d, iBox(ro - RayMarchCube_0.xyz, rd, d.xy, normal, RayMarchCube_0.w), 2);

	d = opU(d, iSphere(ro - RayMarchSphere_0.xyz, rd, d.xy, normal, RayMarchSphere_0.w), 3);

	d = opU(d, iCylinder(ro, rd, d.xy, normal, float3(2.1, .1, -2), float3(1.9, .5, -1.9), .08), 4.);
	d = opU(d, iCylinder(ro - float3(1, .100, -2), rd, d.xy, normal, float3(0, 0, 0), float3(0, .4, 0), .1), 5.);
	d = opU(d, iTorus(ro - float3(0, .250, 1), rd, d.xy, normal, float2(.2, .05)), 6.);
	d = opU(d, iCapsule(ro - float3(1, .000, -1), rd, d.xy, normal, float3(-.1, .1, -.1), float3(.2, .4, .2), .1), 7.);
	//d = opU(d, iCone(ro - float3(2, .200, 0), rd, d.xy, normal, float3(.1, 0, 0), float3(-.1, .3, .1), .15, .05), 8.);
	d = opU(d, iGoursat(ro - RayMarchCube_1.xyz, rd, d.xy, normal, RayMarchCube_1.w, RayMarchCube_1.w * 1.25), 10.);
	d = opU(d, iEllipsoid(ro - float3(-1, .300, 0), rd, d.xy, normal, float3(.2, .25, .05)), 11.);
	d = opU(d, iRoundedCone(ro - float3(2, .200, -1), rd, d.xy, normal, float3(.1, 0, 0), float3(-.1, .3, .1), 0.15, 0.05), 12.);
	d = opU(d, iRoundedCone(ro - float3(-1, .200, -2), rd, d.xy, normal, float3(0, .3, 0), float3(0, 0, 0), .1, .2), 13.);
	d = opU(d, iMesh(ro - float3(2, .090, 1), rd, d.xy, normal), 14.);
	d = opU(d, iSphere4(ro - RayMarchSphere_1.xyz, rd, d.xy, normal, RayMarchSphere_1.w), 15.);

	tmp1 = opU(d, iBox(rotateY(ro - GlassCube_0.rgb, 0.78539816339), rotateY(rd, 0.78539816339), d.xy, tmp0, GlassCube_0.w * float3(.1, .2, .1)), 16.);
	if (tmp1.y < d.y) {
		d = tmp1;
		normal = rotateY(tmp0, -0.78539816339);
	}

	return d;
}


float3 getSkyColor(float3 rd) {
	float3 col = Mix(_RayMarchReflectionColor.rgb, _RayMarchFogColor.rgb, 0.5 + 0.5*rd.y);
	float sun = saturate(dot(normalize(float3(-.8, 1.7, 2.6)), rd));
	col += _RayMarchLightColor.a * _RayMarchLightColor.rgb * (smoothstep(0.99, 3, sun)  * 100000 + pow(sun, 32));
	return col;
}

float3 render(in float3 ro, in float3 rd, inout float4 seed) {

	float3 albedo, normal;
	float3 col = 1;
	float roughness, type;

	for (int i = 0; i < PATH_LENGTH; ++i) {
		float3 res = worldhit(ro, rd, float2(.0001, 100), normal);
		if (res.z > 0.) {
			ro += rd * res.y;

			getMaterialProperties(ro, res.z, albedo, type, roughness);

			if (type < LAMBERTIAN + .5) { // Added/hacked a reflection term
				float F = FresnelSchlickRoughness(max(0., -dot(normal, rd)), .04, roughness);
				if (F > seed.b){
					rd = modifyDirectionWithRoughness(normal, reflect(rd, normal), roughness, seed);
				}
				else {
					col *= albedo;
					rd = cosWeightedRandomHemisphereDirection(normal, seed);
				}
			}
			else if (type < METAL + .5) {
				col *= albedo;
				rd = modifyDirectionWithRoughness(normal, reflect(rd, normal), roughness, seed);
			}
			else { // DIELECTRIC


				float3 normalOut;
				float3 refracted = 0;
				float ni_over_nt, cosine, reflectProb = 1.;
				float theDot = dot(rd, normal);
				if (theDot > 0.) {
					normalOut = -normal;
					ni_over_nt = 1.4;
					cosine = theDot;
					cosine = sqrt(max(0.001, 1. - (1.4*1.4) - (1.4*1.4)*cosine*cosine));
				}
				else {
					normalOut = normal;
					ni_over_nt = 1. / 1.4;
					cosine = -theDot;
				}

				float modRf = modifiedRefract(rd, normalOut, ni_over_nt, refracted);

				float r0 = (1. - ni_over_nt) / (1. + ni_over_nt);
				reflectProb = FresnelSchlickRoughness(cosine, r0*r0, roughness) * modRf + reflectProb * (1. - modRf);

				rd = seed.g	<= reflectProb ? reflect(rd, normal) : refracted;
				rd = modifyDirectionWithRoughness(-normalOut, rd, roughness, seed);
			}
		}
		else {



			col *= getSkyColor(rd);
			
			float fog = smoothstep(5, 100, length(ro - _WorldSpaceCameraPos.xyz));
			


			col.rgb = col.rgb * (1- fog) + fog * ((_RayMarchFogColor.rgb + _RayMarchReflectionColor.rgb)*0.5);

			return col;
		}
	}
	return 0;
}
