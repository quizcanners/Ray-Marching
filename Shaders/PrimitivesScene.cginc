#include "Assets/Ray-Marching/Shaders/inc/IntersectOperations.cginc"
#include "Assets/Ray-Marching/Shaders/inc/RayMathHelpers.cginc"
#include "Assets/Ray-Marching/Shaders/inc/SDFoperations.cginc"
#include "Assets/The-Fire-Below/Common/Shaders/quizcanners_cg.cginc"

#include "UnityCG.cginc"
#include "UnityLightingCommon.cginc" 
#include "Lighting.cginc"
#include "AutoLight.cginc"


//static const float GAMMA_TO_LINEAR = 2.2;
//static const float LINEAR_TO_GAMMA = 1 / GAMMA_TO_LINEAR;

// CUBES

#define ARRAY_SIZE 10
#define ARRAY_BOX_COUNT 2
//1e10


uniform float4 RAY_FLOOR_Mat;

uniform float4 RayMarchCube[ARRAY_SIZE];
uniform float4 RayMarchCube_Size[ARRAY_SIZE];
uniform float4 RayMarchCube_Mat[ARRAY_SIZE];
uniform float4 RayMarchCube_Rot[ARRAY_SIZE];

uniform float4 RayMarchCube_BoundPos[ARRAY_SIZE];
uniform float4 RayMarchCube_BoundSize[ARRAY_SIZE];

// Dynamics

#define DYNAMIC_ARRAY_SIZE 6

uniform float4 DYNAMIC_PRIM[DYNAMIC_ARRAY_SIZE];
uniform float4 DYNAMIC_PRIM_Size[DYNAMIC_ARRAY_SIZE];
uniform float4 DYNAMIC_PRIM_Mat[DYNAMIC_ARRAY_SIZE];
uniform float4 DYNAMIC_PRIM_Rot[DYNAMIC_ARRAY_SIZE];

uniform float4 DYNAMIC_PRIM_BoundPos;
uniform float4 DYNAMIC_PRIM_BoundSize;

uniform int DYNAMIC_PRIM_COUNT;

// SUBTRACTIVE
uniform float4 RayMarchSubtractiveCube_0;
uniform float4 RayMarchSubtractiveCube_0_Size;
uniform float4 RayMarchSubtractiveCube_0_Mat;

uniform float4 RayMarchSubtractiveCube_1;
uniform float4 RayMarchSubtractiveCube_1_Size;
uniform float4 RayMarchSubtractiveCube_1_Mat;

uniform float4 RayMarchSubtractiveCube_2;
uniform float4 RayMarchSubtractiveCube_2_Size;
uniform float4 RayMarchSubtractiveCube_2_Mat;

//Spheres
uniform float4 RayMarchSphere_0;
uniform float4 RayMarchSphere_0_Size;
uniform float4 RayMarchSphere_0_Mat;

uniform float4 RayMarchSphere_1;
uniform float4 RayMarchSphere_1_Size;
uniform float4 RayMarchSphere_1_Mat;

// Ambient Light
uniform float4 RayMarchLight_0;
uniform float4 RayMarchLight_0_Mat;
uniform float4 RayMarchLight_0_Size;

uniform float4 _RayMarchSkyColor;
uniform float4 _RayMarthMinLight;



#define MAX_VOLUME_ALPHA 10500//1e10
#define MATCH_RAY_TRACED_SUN_COEFFICIENT 0.5
#define MATCH_RAY_TRACED_SKY_COEFFICIENT 0.5
#define MATCH_RAY_TRACED_SUN_LIGH_GLOSS 0.2


float getShadowAttenuation(float3 worldPos)
{
#if defined(SHADOWS_CUBE)
	{
		unityShadowCoord3 shadowCoord = worldPos - _LightPositionRange.xyz;
		float result = UnitySampleShadowmap(shadowCoord);
		return result;
	}
#elif defined(SHADOWS_SCREEN)
	{
#ifdef UNITY_NO_SCREENSPACE_SHADOWS
		unityShadowCoord4 shadowCoord = mul(unity_WorldToShadow[0], worldPos);
#else
		unityShadowCoord4 shadowCoord = ComputeScreenPos(mul(UNITY_MATRIX_VP, float4(worldPos, 1.0)));
#endif
		float result = unitySampleShadow(shadowCoord);
		return result;
	}
#elif defined(SHADOWS_DEPTH) && defined(SPOT)
	{
		unityShadowCoord4 shadowCoord = mul(unity_WorldToShadow[0], float4(worldPos, 1.0));
		float result = UnitySampleShadowmap(shadowCoord);
		return result;
	}
#else
	return 1.0;
#endif  
}

// Scenes
float3 getSkyColor(float3 rd) 
{
	float3 col = Mix(unity_FogColor.rgb, _RayMarchSkyColor.rgb, smoothstep(0,0.13, rd.y));// 0.5 + 0.5 * rd.y);

	// _qc_AMBIENT_SIMULATION will use incorrec values to speed up baking
	#if defined(_qc_AMBIENT_SIMULATION)
		
		float sun = saturate(dot(_WorldSpaceLightPos0.xyz, rd));
		col.rgb += _LightColor0.rgb * (smoothstep(0.995 - 0.01, 3, sun) * 1000000 + pow(sun, 8));
	//	col *= smoothstep(-0.025, 0, rd.y);
	#else

		float sun =  smoothstep(1,0, dot(_WorldSpaceLightPos0.xyz, rd));
		col.rgb += _LightColor0.rgb * (1 / (0.01 + sun*3000));// (smoothstep(0.995 - 0.01, 3, sun) * 1000000 + pow(sun, 8));

	//	float3 skyColor = lerp(unity_FogColor.rgb, mat.rgb, smoothstep(0,0.23, ray.y));

	#endif

	col *= smoothstep(-0.025, 0, rd.y);

	return col;
}


inline float SceneSdf_Dynamic(float3 position, float smoothness, float edges)
{
	float dist = 9999;

	for (int i = 0; i < DYNAMIC_PRIM_COUNT; i++) 
	{
		float cDst =
		//CubeDistanceRot(position, DYNAMIC_PRIM_Rot[i] ,DYNAMIC_PRIM[i], DYNAMIC_PRIM_Size[i].xyz, edges);
		CapsuleDistanceRot(position, DYNAMIC_PRIM_Rot[i] ,DYNAMIC_PRIM[i], DYNAMIC_PRIM_Size[i].xyz);
		
		dist = CubicSmin(dist, cDst, edges);
	}

	return dist;
}


inline float SceneSdf(float3 position, float smoothness) 
{
	float edges = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 0.5 * smoothness;

	float s0 = SphereDistance(position, float4(RayMarchSphere_0.xyz, RayMarchSphere_0_Size.x));
	float s1 = SphereDistance(position, float4(RayMarchSphere_1.xyz, RayMarchSphere_1_Size.x));

	float dist = CubicSmin(s0, s1, edges);

	#define ADD(d) dist = CubicSmin(dist, d, edges)

	for (int i = 0; i < ARRAY_SIZE; i++) 
	{
		ADD(CubeDistanceRot(position, RayMarchCube_Rot[i] ,RayMarchCube[i], RayMarchCube_Size[i].xyz, edges));
	}

	#if defined(RAYMARCH_DYNAMICS)
	ADD(SceneSdf_Dynamic(position, smoothness, edges));
	#endif

	float sub0 = CubeDistance(position, RayMarchSubtractiveCube_0, RayMarchSubtractiveCube_0_Size.xyz, edges);
	float sub1 = CubeDistance(position, RayMarchSubtractiveCube_1, RayMarchSubtractiveCube_1_Size.xyz, edges); 
	float sub2 = CubeDistance(position, RayMarchSubtractiveCube_2, RayMarchSubtractiveCube_2_Size.xyz, edges);

	#if !defined(IGNORE_FLOOR)
	float plane = Plane(position);

	ADD(plane);
	#endif

	dist = OpSmoothSubtraction(dist, sub0, edges);
	dist = OpSmoothSubtraction(dist, sub1, edges);
	dist = OpSmoothSubtraction(dist, sub2, edges);

	return dist;
}

inline float SceneSdf(float3 position)
{
	return SceneSdf(position, _RayMarchSmoothness);
}

float3 opU(float3 d, float iResult, float4 newMat, inout float4 currentMat, float type) 
{
	currentMat = d.y > iResult ? newMat : currentMat;
	return d.y > iResult ? float3(d.x, iResult, type) : d; // if closer make new result
}


#define TRACE_BOUNDS(pos, size) IsHitBox(ro - pos.xyz, rd, size.xyz, m)
#define TRACE_BOX(posNmat,rot, size,objmat) d = opU(d, iBox(ro - posNmat.xyz, rd, d.xy, normal, size.xyz, m), objmat, mat, posNmat.w)
#define TRACE_BOX_ROT(posNmat, rot, size,objmat) d = opU(d, iBoxRot(ro - posNmat.xyz, rd, rot, d.xy, normal, size.xyz), objmat, mat, posNmat.w)
#define TRACE_CAPSULE_ROT(posNmat, rot, size,objmat) d = opU(d, iCapsuleRot(ro - posNmat.xyz, rd, rot, d.xy, normal, size.y, size.x), objmat, mat, posNmat.w)

//float iCapsuleRot(in float3 ro, in float3 rd, in float4 q, in float2 distBound, inout float3 normal,
	//in float3 pa, in float3 pb, in float r) 


void WorldHit_Dynamic(float3 ro, in float3 rd, inout float3 d, inout float3 normal, inout float4 mat, in float3 m) 
{
	if (TRACE_BOUNDS(DYNAMIC_PRIM_BoundPos, DYNAMIC_PRIM_BoundSize))
	{
		for (int i=0; i< DYNAMIC_PRIM_COUNT; i++)
			TRACE_CAPSULE_ROT(DYNAMIC_PRIM[i], DYNAMIC_PRIM_Rot[i], DYNAMIC_PRIM_Size[i], DYNAMIC_PRIM_Mat[i]);
	}
}


float3 worldhit(float3 ro, in float3 rd, in float2 dist, out float3 normal, inout float4 mat) {

	ro += rd * 0.01;
	// d.z <= z causes to show sky   d.z is material
	float3 d = float3(dist, 0.);
	const float floorRoughness = 0.99;
	const float floorMaterial = 0.5;
	//const float3 FLOOR_COLOR = float3(0.01, 0.5, 0.01);

	#if !defined(IGNORE_FLOOR)

	d = opU(d, iPlane(ro, rd, d.xy, normal, float3(0, 1, 0), 0.), RAY_FLOOR_Mat, mat, floorMaterial);

	#endif

	float3 m = sign(rd) / max(abs(rd), 1e-8);



	if (TRACE_BOUNDS(RayMarchCube_BoundPos[0], RayMarchCube_BoundSize[0]))
	{
		for (int i=0; i< ARRAY_SIZE; i++)
			TRACE_BOX_ROT(RayMarchCube[i], RayMarchCube_Rot[i], RayMarchCube_Size[i], RayMarchCube_Mat[i]);
	}

	d = opU(d, iSphere(ro - RayMarchSphere_0.xyz, rd, d.xy, normal, RayMarchSphere_0_Size.x), RayMarchSphere_0_Mat, mat, RayMarchSphere_0.w);
	d = opU(d, iSphere(ro - RayMarchSphere_1.xyz, rd, d.xy, normal, RayMarchSphere_1_Size.x), RayMarchSphere_1_Mat, mat, RayMarchSphere_1.w);

	d = opU(d, iBox(ro - RayMarchSubtractiveCube_0.xyz, rd, d.xy, normal, RayMarchSubtractiveCube_0_Size.xyz, m), RayMarchSubtractiveCube_0_Mat, mat, RayMarchSubtractiveCube_0.w);
	d = opU(d, iBox(ro - RayMarchSubtractiveCube_1.xyz, rd, d.xy, normal, RayMarchSubtractiveCube_1_Size.xyz, m), RayMarchSubtractiveCube_1_Mat, mat, RayMarchSubtractiveCube_1.w);
	d = opU(d, iBox(ro - RayMarchSubtractiveCube_2.xyz, rd, d.xy, normal, RayMarchSubtractiveCube_2_Size.xyz, m), RayMarchSubtractiveCube_2_Mat, mat, RayMarchSubtractiveCube_2.w);

	#if defined(RENDER_DYNAMICS)

	WorldHit_Dynamic(ro, rd, d, normal, mat, m);

	#endif

	return d;
}


float worldhitSubtractive(float3 ro, in float3 rd, in float2 dist) 
{
	float3 d = float3(dist, 0.);

	float3 m = sign(rd) / max(abs(rd), 1e-8);

	float distance = iBoxTrigger(ro - RayMarchSubtractiveCube_0.xyz, rd, d.xy, RayMarchSubtractiveCube_0_Size.xyz, m);
	distance = min(distance, iBoxTrigger(ro - RayMarchSubtractiveCube_1.xyz, rd, d.xy, RayMarchSubtractiveCube_1_Size.xyz, m));
	distance = min(distance, iBoxTrigger(ro - RayMarchSubtractiveCube_2.xyz, rd, d.xy, RayMarchSubtractiveCube_2_Size.xyz, m));

	return distance;
}


// ****************** Intersections


#if RT_MOTION_TRACING
#define PATH_LENGTH 6
#else
#define PATH_LENGTH 8
#endif


#define LAMBERTIAN 0.
#define METAL 1.
#define DIELECTRIC 2.
#define GLASS 3.
#define EMISSIVE 4.
#define SUBTRACTIVE 5.

float3 modifyDirectionWithRoughnessFast(in float3 normal, in float3 refl, in float roughness, in float4 seed) {

	float2 r = seed.wx;//hash2(seed);

	float nyBig = step(.5, refl.y);

	float3  uu = normalize(cross(refl, float3(nyBig, 1. - nyBig, 0.)));
	float3  vv = cross(uu, refl);

	float a = roughness * roughness;

	float rz = sqrt(abs((1.0 - seed.y) / clamp(1. + (a - 1.) * seed.y, .00001, 1.)));
	float ra = sqrt(abs(1. - rz * rz));
	float preCmp = 6.28318530718 * seed.x;
	float rx = ra * cos(preCmp);
	float ry = ra * sin(preCmp);
	float3 rr = float3(rx * uu + ry * vv + rz * refl);

	return normalize(rr + (seed.xyz - 0.5) * 0.1);
}

float4 render(in float3 ro, in float3 rd, in float4 seed) 
{
	const float MIN_DIST = 0.0001;

	float3 albedo, normal;
	float3 col = 1;
	float roughness, type;

	float isFirst = 1;
	float distance = MAX_DIST_EDGE;

	for (int i = 0; i < PATH_LENGTH; ++i) 
	{
		float4 mat = 0;

		float3 res = worldhit(ro, rd, float2(MIN_DIST, MAX_DIST_EDGE), normal, mat);
		roughness = mat.a;
		albedo = mat.rgb;
		type = res.z;
		// res.x =
		// res.y = dist
		// res.z = material

		if (res.z > 0.) 
		{
			ro += rd * res.y;

			
#if RT_DENOISING
			distance = isFirst > 0.5 ?
				res.y +
				dot(rd, normal)
				: distance;
			isFirst = 0;
#endif

			if (type < LAMBERTIAN + 0.5) 
			{ 
					col *= albedo;
					rd = cosWeightedRandomHemisphereDirection(normal, seed);
			}
			else
			if (type < METAL + 0.5) { // MEtal
				col *= albedo;
				rd = modifyDirectionWithRoughness(normal, reflect(rd, normal), roughness, seed);
			}
//#if RT_USE_DIELECTRIC
			else if (type < GLASS + 0.5) //DIELECTRIC + GLASS
			{ 
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
				reflectProb = 
					lerp(reflectProb, FresnelSchlickRoughness(cosine, r0 * r0, roughness), modRf);

				rd = (seed.b) <= reflectProb ? reflect(rd, normal) : refracted;
				rd = modifyDirectionWithRoughnessFast(-normalOut, rd, roughness, seed);
			}
			else if (type < EMISSIVE + 1) // EMISSIVE
			{
				return float4(col * albedo * 4, distance);
			} else // Subtractive
			{
				ro += 0.001 * rd;
				float dist = worldhitSubtractive(ro, rd, float2(MIN_DIST, MAX_DIST_EDGE));
				if (dist < MAX_DIST)
				{
					ro += (dist + 0.001) * rd;
				}
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


inline float Softshadow(float3 start, float3 direction, float mint, float k, float maxSteps)
{
	float res = 1.0;
	float ph = 1e20;

	float distance = mint;

	for (int i = 0; i < maxSteps; i++)
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

inline float Softshadow2(float3 start, float3 direction, float mint, float maxt, float k, int maxSteps)
{
	float t = mint;
	float res = 1.0;
	for (int i = 0; i < maxSteps; i++)
	{
		float h = SceneSdf(start + t * direction);
		res = min(res, h / (k * t));
		t += clamp(h, 0.005, 0.50);
		if (res<-1.0 || t>maxt) break;
	}
	res = max(res, -1.0); // clamp to [-1,1]

	return 0.25 * (1.0 + res) * (1.0 + res) * (2.0 - res); // smoothstep
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

inline float4 NormalAndDistance(float3 pos) {

	float EPSILON = 0.01f;

	float center = SceneSdf(float3(pos.x, pos.y, pos.z));

	float3 normal = normalize(float3(
		center - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z)),
		center - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z)),
		center - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON))
		));

	return float4(normal, max(0,center));
}

inline float3 EstimateNormal(float3 pos, float smoothness) {

	float EPSILON = 0.01f;

	float center = SceneSdf(float3(pos.x, pos.y, pos.z), smoothness);

	return normalize(float3(
		center - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON), smoothness)
		));
}
inline float3 EstimateNormal(float3 pos) 
{
	return EstimateNormal(pos, _RayMarchSmoothness);
}


inline float4 SdfNormalAndDistance(float3 pos, float smoothness) {

	float EPSILON = 0.01f;

	float center = SceneSdf(float3(pos.x, pos.y, pos.z), smoothness);

	return float4(normalize(float3(
		center - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON), smoothness)
		)), center);
}

inline float4 SdfNormalAndDistance(float3 pos)
{
	//_RayMarchSmoothness
	return SdfNormalAndDistance(pos, _RayMarchSmoothness);
}

inline float4 renderSdfProgression(in float3 ro, in float3 rd, float pixelScale)
{
	float totalDistance = 0;
	float dist = 0;

	for (int i = 0; i < 100; i++) {

		dist = SceneSdf(ro);

		float rng = pixelScale * totalDistance;

		if (dist < rng || dist > 9999)
		{
			i = 999;
		}
		else 
		{
			//dist -= rng;

			ro += dist * rd ;
			totalDistance += dist;
		}
	}

	return float4(EstimateNormal(ro), totalDistance);
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

		if (dist < 0.01) 
		{
			i = 999;
		}
	}

	float3 normal = EstimateNormal(ro);

	float deDott = max(0, dot(-rd, normal));

	float dott = 1 - deDott;

	float3 lightSource = RayMarchLight_0.xyz;

	float3 toCenterVec = lightSource - ro;

	float toCenter = length(toCenterVec);

	float3 lightDir = normalize(toCenterVec);

	float lightRange = RayMarchLight_0_Size.x + 1;
	float deLightRange = 1 / lightRange;

	float lightBrightness = lightRange / (1 + toCenter); // max(0, lightRange - toCenter) * deLightRange;

	float deFog = saturate(1 - totalDistance / _MaxRayMarchDistance);
	deFog *= deFog;

	float precision = 1 + deFog * deFog * max_steps;

	float shadow = Softshadow(ro, lightDir, 5, _RayMarchShadowSoftness, precision);

	float toview = dot(normal, rd);

	float fresnel = smoothstep(-1, 1, 1 + toview);

	float3 reflected = -normalize(rd - 2 * (toview)*normal 
#if !RT_MOTION_TRACING
		+ (seed - 0.5) * 0.3 * pow(1 - fresnel, 2)
#endif
	); 

	float reflectedDistance;

	float3 reflectionPos;

	float reflectedSky = Reflection(ro, -reflected, 0.1, 1,	reflectedDistance, reflectionPos, precision);


	float lightRelected = smoothstep(0, 1 , dot(-reflected, lightDir));

	float3 reflectedNormal = EstimateNormal(reflectionPos);

	float reflectedDott = max(0, dot(reflected, reflectedNormal));

	float3 toCenterVecRefl = lightSource - reflectionPos;

	float toCenterRefl = length(toCenterVecRefl);

	float3 lightDirRef = normalize(toCenterVecRefl);

	float lightAttenRef = max(0, dot(lightDirRef, reflectedNormal));

	float reflectedShadow = 0;

	precision = 1 + precision * max(0, 1 - reflectedDistance / _MaxRayMarchDistance) * 0.5f;

	if (lightRange > toCenterRefl)
		reflectedShadow = Softshadow(reflectionPos, lightDirRef, 2,
			_RayMarchShadowSoftness, precision);

	float4 col = 1;

	float lightBrightnessReflected = max(0, lightRange - toCenterRefl) *deLightRange;


	col.rgb = RayMarchLight_0_Mat.rgb * shadow * lightBrightness;

	float reflectedFog = max(0, 1 - reflectedDistance / _MaxRayMarchDistance);

	float reflAmount = pow(deFog * reflectedFog, 1);

	reflectedFog *= reflAmount;

	reflectedSky = reflectedSky * (reflAmount)+(1 - reflAmount);

	lightBrightnessReflected *= reflAmount;

	float3 reflCol = (RayMarchLight_0_Mat.rgb * reflectedShadow * lightAttenRef * (lightBrightnessReflected + 1));

	
	float3 fresnelReflection = //(1 + dott * 0.5)
		//*
		(reflCol * (1 - reflectedSky) +
			_RayMarchSkyColor.rgb * reflectedSky +
			lightRelected * shadow
			);


	col.rgb = lerp(col.rgb, fresnelReflection, fresnel);


	col.rgb = lerp(_RayMarchSkyColor.rgb, col.rgb, deFog);
	
	return 	max(0, col);

}