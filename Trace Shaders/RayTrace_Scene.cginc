#include "RayTrace.cginc"

#if RT_MOTION_TRACING
	#define PATH_LENGTH 4
#else
	#define PATH_LENGTH 12
#endif

float3 opU(float3 d, float iResult, float mat) {
	return d.y > iResult ? float3(d.x, iResult, mat) : d;
}

float3 worldhit(in float3 ro, in float3 rd, in float2 dist, out float3 normal) {

	float3 d = float3(dist, 0.);
	d = opU(d, iPlane(ro, rd, d.xy, normal, float3(0, 1, 0), 0.),																0.2);

	float3 m = sign(rd) / max(abs(rd), 1e-8);

	d = opU(d, iBox(ro - RayMarchCube_0.xyz, rd, d.xy, normal, RayMarchCube_0_Size.rgb, m), RayMarchCube_0_Size.w);
	d = opU(d, iBox(ro - RayMarchCube_1.xyz, rd, d.xy, normal, RayMarchCube_1_Size.rgb, m), RayMarchCube_1_Size.w);
	d = opU(d, iBox(ro - RayMarchCube_2.xyz, rd, d.xy, normal, RayMarchCube_2_Size.rgb, m), RayMarchCube_2_Size.w);
	d = opU(d, iBox(ro - RayMarchCube_3.xyz, rd, d.xy, normal, RayMarchCube_3_Size.rgb, m), RayMarchCube_3_Size.w);
	d = opU(d, iBox(ro - RayMarchCube_4.xyz, rd, d.xy, normal, RayMarchCube_4_Size.rgb, m), RayMarchCube_4_Size.w);

	/*float3 tmpNorm;
	float3 tmp1 = opU(d, iBox(rotateY(ro - RayMarchCube_4.xyz, RayMarchCube_4_Rot.y), rotateY(rd, RayMarchCube_4_Rot.y), d.xy, tmpNorm, RayMarchCube_4_Size.rgb, m), 16.);
	if (tmp1.y < d.y) {
		d = tmp1;
		normal = rotateY(tmpNorm, -RayMarchCube_4_Rot.y);
	}*/



	d = opU(d, iGoursat(ro - RayMarchCube_5.xyz, rd, d.xy, normal, RayMarchCube_5.w, RayMarchCube_5.w * 1.25),					RayMarchCube_5_Size.w);


	//d = opU(d, iTriangle(ro, rd, d.xy, normal, float3(5, 5, 5), float3 (0, 0, 0), float3(5,0,5)), 2.12);

	/*d = opU(d, iCylinder(ro - RayMarchCube_2.xyz, rd, d.xy, normal,	 float3(2.1, .1, -2), float3(1.9, .5, -1.9), .08),			4.);
	d = opU(d, iCylinder(ro - RayMarchCube_3.xyz, rd, d.xy, normal,	float3(0, 0, 0), float3(0, .4, 0), .1),						5.);
	d = opU(d, iTorus(ro - RayMarchCube_4.xyz, rd, d.xy, normal, float2(.2, .05)),												6.);
	d = opU(d, iCapsule(ro - RayMarchCube_5.xyz, rd, d.xy, normal, float3(-.1, .1, -.1), float3(.2, .4, .2), .1),				7.);
	
	d = opU(d, iEllipsoid(ro - float3(-1, .300, 0), rd, d.xy, normal,	float3(.2, .25, .05)),									11.);
	d = opU(d, iRoundedCone(ro - float3(2, .200, -1), rd, d.xy, normal,		float3(.1, 0, 0), float3(-.1, .3, .1), 0.15, 0.05), 12.);
	d = opU(d, iRoundedCone(ro - float3(-1, .200, -2), rd, d.xy, normal,	float3(0, .3, 0), float3(0, 0, 0), .1, .2),			13.);
	d = opU(d, iMesh(ro - float3(2, .090, 1), rd, d.xy, normal),																14.);*/

	d = opU(d, iSphere(ro - RayMarchSphere_0.xyz, rd, d.xy, normal,		RayMarchSphere_0.w),									RayMarchSphere_0_Size.w);
	d = opU(d, iSphere4(ro - RayMarchSphere_1.xyz, rd, d.xy, normal,	RayMarchSphere_1.w),									RayMarchSphere_1_Size.w);
	

	/*tmp1 = opU(d, iBox(rotateY(ro - GlassCube_0.rgb, 0.78539816339), rotateY(rd, 0.78539816339), d.xy, tmp0, GlassCube_0.w * float3(.1, .2, .1)), GlassCube_0_Size.w);
	if (tmp1.y < d.y) {
		d = tmp1;
		normal = rotateY(tmp0, -0.78539816339);
	}*/

	//d = opU(d, iCone(ro - float3(2, .200, 0), rd, d.xy, normal, float3(.1, 0, 0), float3(-.1, .3, .1), .15, .05), 8.);

	return d;
}

float3 getSkyColor(float3 rd) {
	float3 col = Mix(unity_FogColor.rgb, _RayMarchSkyColor.rgb, 0.5 + 0.5*rd.y);
	float sun = saturate(dot(normalize(float3(-.8, 1.7, 2.6)), rd));
	col += _RayMarchLightColor.a * _RayMarchLightColor.rgb * (smoothstep(0.99, 3, sun)  * 100000 + pow(sun, 32));
	return col;
}

float3 Pallete(in float t, in float3 a, in float3 b, in float3 c, in float3 d) {
	return a + b * cos(6.28318530718*(c*t + d));
}

float checkerBoard(float2 p) {
	return abs((floor(p.x) + floor(p.y)) % 2);
}

#define LAMBERTIAN 0.
#define METAL 1.
#define DIELECTRIC 2.
#define EMISSIVE 3.


float gpuIndepentHash(float p) {
	p = (p * 0.1031) % 1;
	p *= p + 19.19;
	p *= p + p;
	return p % 1;
}

void getMaterialProperties(in float3 pos, in float mat, out float3 albedo, out float type, out float roughness) {

#if RT_USE_CHECKERBOARD
	if (mat < 1.5) {
		albedo = 0.25 + 0.25*checkerBoard(pos.xz * 5.0);
		roughness = 0.75 * albedo.x - 0.15;
		type = METAL;
	}
	else
#endif

	{
		albedo = Pallete(mat*0.59996323 + 0.5, 0.5, 0.5, 1, float3(0, 0.1, 0.2));
		type = floor(gpuIndepentHash(mat) * 4.);
		roughness = (1. - type * .475) * gpuIndepentHash(mat);
	}
}

float4 render(in float3 ro, in float3 rd, in float4 seed) {

	float3 albedo, normal;
	float3 col = 1;
	float roughness, type;

	float isFirst = 1;
	float distance = MAX_DIST_EDGE;

	for (int i = 0; i < PATH_LENGTH; ++i) {
		float3 res = worldhit(ro, rd, float2(.0001, MAX_DIST_EDGE), normal);

		// res.x =
		// res.y = dist
		// res.z = material

		if (res.z > 0.) {
			ro += rd * res.y;

			getMaterialProperties(ro, res.z, albedo, type, roughness);

#if RT_DENOISING
			distance = isFirst > 0.5 ? 
				res.y +
				dot(rd, normal)
				: distance;
			isFirst = 0;
#endif


			if (type < .5) { // Added/hacked a reflection term  0 - 0.5
							
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
#if RT_USE_DIELECTRIC
				else if (type < DIELECTRIC + .5) { // DIELECTRIC? glass

				

				float3 normalOut;
				float3 refracted = 0;
				float ni_over_nt, cosine, reflectProb = 1.;
				float theDot = dot(rd, normal);

				if (theDot > 0.) {
					normalOut = -normal;
					ni_over_nt = 1.4;
					cosine = theDot;
					cosine = sqrt(max(0.001, 1. - (1.4*1.4) - (1.4*1.4)*cosine*cosine));

					//r0 = (1. - 1.4) / (1. + 1.4);
				}
				else {
					normalOut = normal;
					ni_over_nt = 1. / 1.4;
					cosine = -theDot;

					//r0 = (1. - 1. / 1.4) / (1. + 1. / 1.4);
				}

				float modRf = modifiedRefract(rd, normalOut, ni_over_nt, refracted);

				float r0 = (1. - ni_over_nt) / (1. + ni_over_nt);
				reflectProb = FresnelSchlickRoughness(cosine, r0*r0, roughness) * modRf + reflectProb * (1. - modRf);

				rd = (seed.b)	<= 
					reflectProb 
					? 
					reflect(rd, normal) 
					: 
					refracted
					;
				rd = modifyDirectionWithRoughness(-normalOut, rd, roughness, seed);
			}
#endif
			else
			{
				return float4(col * albedo * 4, distance);
			}

		}
		else {

			float3 skyCol = getSkyColor(rd);
			
			//float fog = smoothstep(5, 100, length(ro - _WorldSpaceCameraPos.xyz));
			
			//col.rgb = col.rgb * (1- fog) + fog * ((_RayMarchSkyColor.rgb + unity_FogColor.rgb)*0.5);*/

			return float4(col * skyCol, distance);
		}
	}
	return 0;
}
