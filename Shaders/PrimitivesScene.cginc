#include "Assets/Ray-Marching/Shaders/inc/IntersectOperations.cginc"
#include "Assets/Ray-Marching/Shaders/inc/RayMathHelpers.cginc"
#include "Assets/Ray-Marching/Shaders/inc/SDFoperations.cginc"
#include "Assets/Tools/Playtime Painter/Shaders/quizcanners_cg.cginc"

// CUBES
uniform float4 RayMarchCube_0;
uniform float4 RayMarchCube_0_Size;
uniform float4 RayMarchCube_0_Mat;

uniform float4 RayMarchCube_1;
uniform float4 RayMarchCube_1_Size;
uniform float4 RayMarchCube_1_Mat;

uniform float4 RayMarchCube_2;
uniform float4 RayMarchCube_2_Size;
uniform float4 RayMarchCube_2_Mat;

uniform float4 RayMarchCube_3;
uniform float4 RayMarchCube_3_Size;
uniform float4 RayMarchCube_3_Mat;

uniform float4 RayMarchCube_4;
uniform float4 RayMarchCube_4_Size;
uniform float4 RayMarchCube_4_Rot;
uniform float4 RayMarchCube_4_Mat;

uniform float4 RayMarchCube_5;
uniform float4 RayMarchCube_5_Size;
uniform float4 RayMarchCube_5_Mat;

//Spheres
uniform float4 RayMarchSphere_0;
uniform float4 RayMarchSphere_0_Size;
uniform float4 RayMarchSphere_0_Mat;

uniform float4 RayMarchSphere_1;
uniform float4 RayMarchSphere_1_Size;
uniform float4 RayMarchSphere_1_Mat;

uniform float4 RayMarchLight_0;
uniform float4 RayMarchLight_0_Mat;
uniform float4 RayMarchLight_0_Size;

uniform float4 _RayMarchSkyColor;
uniform float4 _RayMarchLightColor;

// Scenes
float3 getSkyColor(float3 rd) {
	float3 col = Mix(unity_FogColor.rgb, _RayMarchSkyColor.rgb, 0.5 + 0.5*rd.y);
	float sun = saturate(dot(normalize(float3(-.8, 1.7, 2.6)), rd));
	col += _RayMarchLightColor.rgb * (smoothstep(0.99, 3, sun) * 100000 + pow(sun, 32));
	return col;
}

inline float SceneSdf(float3 position) {

	float s0 = SphereDistance(position, float4(RayMarchSphere_0.xyz, RayMarchSphere_0_Size.x));
	float s1 = SphereDistance(position, float4(RayMarchSphere_1.xyz, RayMarchSphere_1_Size.x));

	float c0 = CubeDistance(position, RayMarchCube_0, RayMarchCube_0_Size.xyz, _RayMarchSmoothness);
	float c1 = CubeDistance(position, RayMarchCube_1, RayMarchCube_1_Size.xyz, _RayMarchSmoothness);
	float c2 = CubeDistance(position, RayMarchCube_2, RayMarchCube_2_Size.xyz, _RayMarchSmoothness);
	float c3 = CubeDistance(position, RayMarchCube_3, RayMarchCube_3_Size.xyz, _RayMarchSmoothness);
	float c4 = CubeDistance(position, RayMarchCube_4, RayMarchCube_4_Size.xyz, _RayMarchSmoothness);
	float c5 = CubeDistance(position, RayMarchCube_5, RayMarchCube_5_Size.xyz, _RayMarchSmoothness);

	float plane = Plane(position);
	//c0 = abs(c0) - 1;


	float //dist = min(plane, s0);
		
     dist = min(s0, c0);

	//dist =	min(dist, s1);

	dist = min(dist, c1);
	dist = min(dist, c2);
	dist = min(dist, c3);
	dist = min(dist, c4);
	dist = min(dist, c5);

	

	dist = CubicSmin(dist, plane, _RayMarchSmoothness);

	dist = OpSmoothSubtraction(dist, s1, _RayMarchSmoothness);

	return dist;
}

float3 opU(float3 d, float iResult, float4 newMat, inout float4 currentMat, float type) {
	currentMat = d.y > iResult ? newMat : currentMat;

	return d.y > iResult ? float3(d.x, iResult, type) : d; // if closer make new result
}


float3 worldhit(in float3 ro, in float3 rd, in float2 dist, out float3 normal, inout float4 mat) {

	// d.z <= z causes to show sky   d.z is material

	float3 d = float3(dist, 0.);
	d = opU(d, iPlane(ro, rd, d.xy, normal, float3(0, 1, 0), 0.), float4(0.5,0.5,0.5,1), mat, 1);

	float3 m = sign(rd) / max(abs(rd), 1e-8);

	d = opU(d, iBox(ro - RayMarchCube_0.xyz, rd, d.xy, normal, RayMarchCube_0_Size.xyz, m), RayMarchCube_0_Mat, mat, RayMarchCube_0.w);
	d = opU(d, iBox(ro - RayMarchCube_1.xyz, rd, d.xy, normal, RayMarchCube_1_Size.xyz, m), RayMarchCube_1_Mat, mat, RayMarchCube_1.w);
	d = opU(d, iBox(ro - RayMarchCube_2.xyz, rd, d.xy, normal, RayMarchCube_2_Size.xyz, m), RayMarchCube_2_Mat, mat, RayMarchCube_2.w);
	d = opU(d, iBox(ro - RayMarchCube_3.xyz, rd, d.xy, normal, RayMarchCube_3_Size.xyz, m), RayMarchCube_3_Mat, mat, RayMarchCube_3.w);
	d = opU(d, iBox(ro - RayMarchCube_4.xyz, rd, d.xy, normal, RayMarchCube_4_Size.xyz, m), RayMarchCube_4_Mat, mat, RayMarchCube_4.w);
	d = opU(d, iBox(ro - RayMarchCube_5.xyz, rd, d.xy, normal, RayMarchCube_5_Size.xyz, m), RayMarchCube_4_Mat, mat, RayMarchCube_5.w);
	//d = opU(d, iGoursat(ro - RayMarchCube_5.xyz, rd, d.xy, normal, RayMarchCube_5_Size.x, RayMarchCube_5.w * 1.25), RayMarchCube_5_Mat, mat, RayMarchCube_5.w);

	/*float3 tmpNorm;
	float3 tmp1 = opU(d, iBox(rotateY(ro - RayMarchCube_4.xyz, RayMarchCube_4_Rot.y), rotateY(rd, RayMarchCube_4_Rot.y), d.xy, tmpNorm, RayMarchCube_4_Size.rgb, m), 16.);
	if (tmp1.y < d.y) {
		d = tmp1;
		normal = rotateY(tmpNorm, -RayMarchCube_4_Rot.y);
	}*/

	//d = opU(d, iTriangle(ro, rd, d.xy, normal, float3(5, 5, 5), float3 (0, 0, 0), float3(5,0,5)), 2.12);

	/*d = opU(d, iCylinder(ro - RayMarchCube_2.xyz, rd, d.xy, normal,	 float3(2.1, .1, -2), float3(1.9, .5, -1.9), .08),			4.);
	d = opU(d, iCylinder(ro - RayMarchCube_3.xyz, rd, d.xy, normal,	float3(0, 0, 0), float3(0, .4, 0), .1),						5.);
	d = opU(d, iTorus(ro - RayMarchCube_4.xyz, rd, d.xy, normal, float2(.2, .05)),												6.);
	d = opU(d, iCapsule(ro - RayMarchCube_5.xyz, rd, d.xy, normal, float3(-.1, .1, -.1), float3(.2, .4, .2), .1),				7.);

	d = opU(d, iEllipsoid(ro - float3(-1, .300, 0), rd, d.xy, normal,	float3(.2, .25, .05)),									11.);
	d = opU(d, iRoundedCone(ro - float3(2, .200, -1), rd, d.xy, normal,		float3(.1, 0, 0), float3(-.1, .3, .1), 0.15, 0.05), 12.);
	d = opU(d, iRoundedCone(ro - float3(-1, .200, -2), rd, d.xy, normal,	float3(0, .3, 0), float3(0, 0, 0), .1, .2),			13.);
	d = opU(d, iMesh(ro - float3(2, .090, 1), rd, d.xy, normal),																14.);*/

	d = opU(d, iSphere(ro - RayMarchSphere_0.xyz, rd, d.xy, normal, RayMarchSphere_0_Size.x), RayMarchSphere_0_Mat, mat, RayMarchSphere_0.w);
	d = opU(d, iSphere(ro - RayMarchSphere_1.xyz, rd, d.xy, normal, RayMarchSphere_1_Size.x), RayMarchSphere_1_Mat, mat, RayMarchSphere_1.w);
	//d = opU(d, iSphere4(ro - RayMarchSphere_1.xyz, rd, d.xy, normal, RayMarchSphere_1.w), RayMarchSphere_1_Size.w);


	/*tmp1 = opU(d, iBox(rotateY(ro - GlassCube_0.rgb, 0.78539816339), rotateY(rd, 0.78539816339), d.xy, tmp0, GlassCube_0.w * float3(.1, .2, .1)), GlassCube_0_Size.w);
	if (tmp1.y < d.y) {
		d = tmp1;
		normal = rotateY(tmp0, -0.78539816339);
	}*/

	//d = opU(d, iCone(ro - float3(2, .200, 0), rd, d.xy, normal, float3(.1, 0, 0), float3(-.1, .3, .1), .15, .05), 8.);

	return d;
}


// ****************** Intersections


#if RT_MOTION_TRACING
#define PATH_LENGTH 4
#else
#define PATH_LENGTH 9
#endif


#define LAMBERTIAN 0.
#define METAL 1.
#define DIELECTRIC 2.
#define EMISSIVE 3.
/*
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
*/

float4 render(in float3 ro, in float3 rd, in float4 seed) {

	float3 albedo, normal;
	float3 col = 1;
	float roughness, type;

	float isFirst = 1;
	float distance = MAX_DIST_EDGE;

	for (int i = 0; i < PATH_LENGTH; ++i) {

		float4 mat = 0;

		float3 res = worldhit(ro, rd, float2(.0001, MAX_DIST_EDGE), normal, mat);
		roughness = mat.a;
		albedo = mat.rgb;
		type = res.z;
		// res.x =
		// res.y = dist
		// res.z = material

		if (res.z > 0.) {
			ro += rd * res.y;

			//getMaterialProperties(ro, res.z, albedo, type, roughness);

#if RT_DENOISING
			distance = isFirst > 0.5 ?
				res.y +
				dot(rd, normal)
				: distance;
			isFirst = 0;
#endif


			if (type < 2.5) { 

				float F = FresnelSchlickRoughness(max(0., -dot(normal, rd)), .04, roughness);
				if (F > seed.b) {
					// Reflect part
					col *= albedo;
					rd = modifyDirectionWithRoughness(normal, reflect(rd, normal), roughness, seed); 
				}
				else {
					// Diffuse part
					col *= albedo;
					rd = cosWeightedRandomHemisphereDirection(normal, seed);
				}
			}
			/*else 
			if (type < METAL + .5) {
			
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

				rd = (seed.b) <=
					reflectProb
					?
					reflect(rd, normal)
					:
					refracted
					;
				rd = modifyDirectionWithRoughness(-normalOut, rd, roughness, seed);
			}
#endif */
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

// ****************** SDF


inline float Softshadow(float3 start, float3 direction, float mint, float maxt, float k, float maxSteps)
{
	float res = 1.0;
	float ph = 1e20;


	for (float distance = mint; distance < maxt; )
	{
		float dist = SceneSdf(start + direction * distance);

		float dsq = dist * dist;

		float y = dsq / (2 * ph);
		float d = sqrt(dsq - y * y);
		res = min(res, k*d / max(0.0000001, distance - y));
		ph = dist;
		distance += dist;

		maxSteps--;

		if (dist*maxSteps < 0.001)
			return 0;

	}
	return res;
}

inline float Reflection(float3 start, float3 direction, float mint, float k, out float totalDist, out float3 pos, float maxSteps)
{

	float closest = mint;
	totalDist = mint;
	pos = start;
	float h = 999;
	
	for (int i = 0; i < maxSteps; i += 1)
	{
		pos = start + direction * totalDist;

		h = SceneSdf(pos);

		closest = min(h / totalDist, closest);

		if (h < 0.01)
			return 0.0;

		totalDist += h;
	}

	return  closest / mint;
}

inline float3 EstimateNormal(float3 pos) {

	float EPSILON = 0.01f;

	return normalize(float3(
		SceneSdf(float3(pos.x + EPSILON, pos.y, pos.z)) - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z)),
		SceneSdf(float3(pos.x, pos.y + EPSILON, pos.z)) - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z)),
		SceneSdf(float3(pos.x, pos.y, pos.z + EPSILON)) - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON))
		));
}

inline float4 renderSdf(in float3 ro, in float3 rd, in float4 seed) {

	float dist = 0;

	float totalDistance = 0;

	float max_steps =
#if RT_MOTION_TRACING
		50;
#else
		_maxRayMarchSteps;
#endif

	for (int i = 0; i < max_steps; i++) {

		dist = SceneSdf(ro);

		ro += dist * rd;

		totalDistance += dist;

		if (dist < 0.01) {
			i = 999;
		}
	}

	float3 normal = EstimateNormal(ro);

	/*float4 bake = SampleVolume(_RayMarchingVolume
		, ro,
		_RayMarchingVolumeVOLUME_POSITION_N_SIZE,
		_RayMarchingVolumeVOLUME_H_SLICES);*/

	float deDott = max(0, dot(-rd, normal));

	float dott = 1 - deDott;

	float3 lightSource = RayMarchLight_0.xyz;

	float3 toCenterVec = lightSource - ro;

	float toCenter = length(toCenterVec);

	float3 lightDir = normalize(toCenterVec);

	float lightRange = RayMarchLight_0_Size.x + 1;
	float deLightRange = 1 / lightRange;

	float lightBrightness = max(0, lightRange - toCenter) * deLightRange;

	float deFog = saturate(1 - totalDistance / _MaxRayMarchDistance);
	deFog *= deFog;

	float precision = 1 + deFog * deFog * max_steps;

	float shadow = 0;

	if (lightRange > toCenter)
		shadow = Softshadow(ro, lightDir, 5, toCenter, _RayMarchShadowSoftness, precision);

	//return float4(normal,1);

	//return shadow;

	float toview = dot(normal, rd);

	float fresnel = smoothstep(0, 1, 1 + toview);



	float3 reflected = -normalize(rd - 2 * (toview)*normal 
#if !RT_MOTION_TRACING
		+ (seed - 0.5) * 0.7 * pow(1- fresnel, 2)
#endif
	); // Returns world normal

	//return float4(reflected, 1);

	float reflectedDistance;

	float3 reflectionPos;

	// Reflection MARCHING
	float reflectedSky = Reflection(ro, -reflected, 0.1, 1,
		reflectedDistance, reflectionPos, precision);

	//reflectedSky = reflectedSky * deDott + 0.5 * dott;

	float lightRelected = pow(max(0, dot(-reflected, lightDir)), 1 //+ bake.a * 128
	);


	float3 reflectedNormal = EstimateNormal(reflectionPos);

	float reflectedDott = max(0, dot(reflected, reflectedNormal));

	//	return reflectedDott;

	/*float4 bakeReflected = SampleVolume(_qcPp_DestBuffer
		, reflectionPos,
		_RayMarchingVolumeVOLUME_POSITION_N_SIZE,
		_RayMarchingVolumeVOLUME_H_SLICES);*/

	float3 toCenterVecRefl = lightSource - reflectionPos;

	float toCenterRefl = length(toCenterVecRefl);

	float3 lightDirRef = normalize(toCenterVecRefl);

	float lightAttenRef = max(0, dot(lightDirRef, reflectedNormal));

	float reflectedShadow = 0;

	precision = 1 + precision * max(0, 1 - reflectedDistance / _MaxRayMarchDistance) * 0.5f;

	if (lightRange > toCenterRefl)
		reflectedShadow = Softshadow(reflectionPos, lightDirRef, 2,
			toCenterRefl, _RayMarchShadowSoftness, precision);

	float lightAtten = max(0, dot(lightDir, normal));

	float4 col = 1;

	float lightBrightnessReflected = max(0, lightRange - toCenterRefl) *deLightRange;

	shadow *= lightAtten;

	col.rgb = RayMarchLight_0_Mat.rgb * shadow * lightBrightness;

	float reflectedFog = max(0, 1 - reflectedDistance / _MaxRayMarchDistance);

	float reflAmount = pow(deFog * reflectedFog, 1);

	reflectedFog *= reflAmount;

	reflectedSky = reflectedSky * (reflAmount)+(1 - reflAmount);

	lightBrightnessReflected *= reflAmount;

	float3 reflCol = (RayMarchLight_0_Mat.rgb * reflectedShadow * lightAttenRef *
		lightBrightnessReflected //* bakeReflected.rgb
		);

	//return shadow;

	//float3 getSkyColor(reflectedNormal);

	//return col;

	

	col.rgb = col.rgb * (1 - fresnel) + fresnel * (1 + dott) *  
		(reflCol * (1 - reflectedSky) +
		_RayMarchSkyColor.rgb * reflectedSky + 
		lightRelected * shadow
		);// *unity_FogColor.rgb;// *bake.a;


	col.rgb = col.rgb * deFog + _RayMarchSkyColor.rgb *(1 - deFog);
	
	return 	max(0, col);

}