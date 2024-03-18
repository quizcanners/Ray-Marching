#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Sampler.cginc"
#include "Assets/Qc_Rendering/Shaders/inc/SDFoperations.cginc"
#include "Assets/Qc_Rendering/Shaders/Savage_VolumeSampling.cginc"

uniform float _MaxRayMarchDistance;
float _maxRayMarchSteps;
float _RayMarchSmoothness;
float _RayMarchShadowSoftness;

float SceneSdf_Dynamic(float3 position, float smoothness, float edges)
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

float SceneSdf_Exact(float3 position) 
{

	float smoothness = 1;
	float edges = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 0.5;

	//float s0 = SphereDistance(position, float4(RayMarchSphere_0.xyz, RayMarchSphere_0_Size.x));
	//float s1 = SphereDistance(position, float4(RayMarchSphere_1.xyz, RayMarchSphere_1_Size.x));

	float dist = 999999;//CubicSmin(s0, s1, edges);

	#define ADD(d) dist = CubicSmin(dist, d, edges)

	float boxDetection = 1 + _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 10;

	//RayMarchUnRot
	float toBound = CubeDistance_Inernal(position - RayMarchUnRot_BoundPos_All.xyz, RayMarchUnRot_BoundSize_All.xyz);

	UNITY_BRANCH
	if (toBound < boxDetection)
	{		
		for (int b = 0; b < ARRAY_BOX_COUNT; b++)
		{
			float4 pos = RayMarchUnRot_BoundPos[b];
			float4 size = RayMarchUnRot_BoundSize[b];

			//type < EMISSIVE + 1

			toBound = CubeDistance_Inernal(position - pos.xyz, size.xyz);

			UNITY_BRANCH
			if (toBound < boxDetection)
			{
				for (int i = pos.w; i < size.w; i++) 
				{
					float4 posNType = RayMarchUnRot[i];
					if (posNType.w>= EMISSIVE)
						continue;
					ADD(CubeDistance(position, posNType, RayMarchUnRot_Size[i].xyz, edges));
				}
					//TRACE_BOX_ROT(RayMarchCube[i], RayMarchCube_Rot[i], RayMarchCube_Size[i], RayMarchCube_Mat[i]);
			} else 
			{
				dist = min(dist, toBound + boxDetection * 1.1);
			}
		}
	} 
	else 
	{
		dist = min(dist, toBound + boxDetection*1.1);
	}

	// Cube Rotated
	toBound = CubeDistance_Inernal(position - RayMarchCube_BoundPos_All.xyz, RayMarchCube_BoundSize_All.xyz);
	
	UNITY_BRANCH
	if (toBound < boxDetection)
	{		
		for (int b = 0; b < ARRAY_BOX_COUNT; b++)
		{
			float4 pos = RayMarchCube_BoundPos[b];
			float4 size = RayMarchCube_BoundSize[b];

			toBound = CubeDistance_Inernal(position - pos.xyz, size.xyz);

			UNITY_BRANCH
			if (toBound < boxDetection)
			{
				for (int i = pos.w; i < size.w; i++) 
				{
					float4 posNType = RayMarchCube_Rot[i];

					if (posNType.w>= EMISSIVE)
						continue;

					ADD(CubeDistanceRot(position, posNType, RayMarchCube[i], RayMarchCube_Size[i].xyz, edges));
				}
					//TRACE_BOX_ROT(RayMarchCube[i], RayMarchCube_Rot[i], RayMarchCube_Size[i], RayMarchCube_Mat[i]);
			} else 
			{
				dist = min(dist, toBound + boxDetection * 1.1);
			}
		}
	} else 
	{
		dist = min(dist, toBound + boxDetection*1.1);
	}

	
	#if defined(RAYMARCH_DYNAMICS)
	ADD(SceneSdf_Dynamic(position, smoothness, edges));
	#endif
	


	return dist;
}


float SceneSdf(float3 position, float smoothness) 
{
	float edges = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 0.5 * smoothness;

	//float s0 = SphereDistance(position, float4(RayMarchSphere_0.xyz, RayMarchSphere_0_Size.x));
	//float s1 = SphereDistance(position, float4(RayMarchSphere_1.xyz, RayMarchSphere_1_Size.x));

	float dist = 999999;//CubicSmin(s0, s1, edges);

	#define ADD(d) dist = CubicSmin(dist, d, edges)

	float boxDetection = 1 + edges * 2;


	//RayMarchUnRot
	float toBound = CubeDistance_Inernal(position - RayMarchUnRot_BoundPos_All.xyz, RayMarchUnRot_BoundSize_All.xyz);

	UNITY_BRANCH
	if (toBound < boxDetection)
	{		
		for (int b = 0; b < ARRAY_BOX_COUNT; b++)
		{
			float4 pos = RayMarchUnRot_BoundPos[b];
			float4 size = RayMarchUnRot_BoundSize[b];


			if (pos.w == size.w)
				continue;

			//type < EMISSIVE + 1

			toBound = CubeDistance_Inernal(position - pos.xyz, size.xyz);

			UNITY_BRANCH
			if (toBound < boxDetection)
			{
				for (int i = pos.w; i < size.w; i++) 
				{
					float4 posNType = RayMarchUnRot[i];
					if (posNType.w>= EMISSIVE)
						continue;
						//wE ARE GETTING A BIG BLOCK AT THE BOTTOM
					ADD(CubeDistance(position, posNType, RayMarchUnRot_Size[i].xyz, edges));
				}
			} else 
			{
				ADD(toBound);
				//dist = min(dist, toBound + boxDetection * 1.1);
			}
		}
	} else 
	{
		ADD(toBound);
		//dist = min(dist, toBound);// + boxDetection*1.1);
	}

	// Cube Rotated
	toBound = CubeDistance_Inernal(position - RayMarchCube_BoundPos_All.xyz, RayMarchCube_BoundSize_All.xyz);
	
	UNITY_BRANCH
	if (toBound < boxDetection)
	{		
		for (int b = 0; b < ARRAY_BOX_COUNT; b++)
		{
			float4 pos = RayMarchCube_BoundPos[b];
			float4 size = RayMarchCube_BoundSize[b];

			if (pos.w == size.w)
				continue;

			toBound = CubeDistance_Inernal(position - pos.xyz, size.xyz);

			UNITY_BRANCH
			if (toBound < boxDetection)
			{
				for (int i = pos.w; i < size.w; i++) 
				{
					float4 posNType = RayMarchCube_Rot[i];

					if (posNType.w>= EMISSIVE)
						continue;

					ADD(CubeDistanceRot(position, posNType, RayMarchCube[i], RayMarchCube_Size[i].xyz, edges));
				}
					//TRACE_BOX_ROT(RayMarchCube[i], RayMarchCube_Rot[i], RayMarchCube_Size[i], RayMarchCube_Mat[i]);
			} else 
			{
				ADD(toBound);//dist = min(dist, toBound); // + boxDetection * 1.1);
			}
		}
	} else 
	{
		ADD(toBound);
		//dist = min(dist, toBound); // + boxDetection*1.1);
	}

	#if defined(RAYMARCH_DYNAMICS)
	ADD(SceneSdf_Dynamic(position, smoothness, edges));
	#endif

	/*
	float sub0 = CubeDistance(position, RayMarchSubtractiveCube_0, RayMarchSubtractiveCube_0_Size.xyz, edges);
	float sub1 = CubeDistance(position, RayMarchSubtractiveCube_1, RayMarchSubtractiveCube_1_Size.xyz, edges); 
	float sub2 = CubeDistance(position, RayMarchSubtractiveCube_2, RayMarchSubtractiveCube_2_Size.xyz, edges);
	*/

	/*
	#if !defined(IGNORE_FLOOR)
	float plane = Plane(position); 

	ADD(plane);
	#endif
	*/
	/*
	dist = OpSmoothSubtraction(dist, sub0, edges);
	dist = OpSmoothSubtraction(dist, sub1, edges);
	dist = OpSmoothSubtraction(dist, sub2, edges);
	*/

	return dist;
}

float SceneSdf(float3 position)
{
	return SceneSdf(position, _RayMarchSmoothness);
}



float Softshadow(float3 start, float3 direction, float mint, float k, float maxSteps)
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

float Softshadow2(float3 start, float3 direction, float mint, float maxt, float k, int maxSteps)
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

float Reflection(float3 start, float3 direction, float mint, float k, out float totalDist, out float3 pos, float maxSteps)
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

float4 NormalAndDistance_Exact(float3 pos) {

	float EPSILON = 0.01f;

	float center = SceneSdf_Exact(pos);

	float3 normal = normalize(float3(
		center - SceneSdf_Exact(float3(pos.x - EPSILON, pos.y, pos.z)),
		center - SceneSdf_Exact(float3(pos.x, pos.y - EPSILON, pos.z)),
		center - SceneSdf_Exact(float3(pos.x, pos.y, pos.z - EPSILON))
		));

	return float4(normal, center);
}

float4 NormalAndDistance(float3 pos, float smoothness) {

	float EPSILON = 0.01f;

	float center = SceneSdf(pos, smoothness);

	float3 normal = normalize(float3(
		center - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON), smoothness)
		));

	return float4(normal, center);
}

float4 NormalAndDistance(float3 pos) {

	float EPSILON = 0.01f;

	float center = SceneSdf(pos);

	float3 normal = normalize(float3(
		center - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z)),
		center - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z)),
		center - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON))
		));

	return float4(normal, center);
}

float3 EstimateNormal(float3 pos, float smoothness) {

	float EPSILON = 0.01f;

	float center = SceneSdf(pos, smoothness);

	return normalize(float3(
		center - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON), smoothness)
		));
}

float3 EstimateNormal(float3 pos) 
{
	return EstimateNormal(pos, _RayMarchSmoothness);
}

float4 SdfNormalAndDistance(float3 pos, float smoothness) {

	float EPSILON = 0.01f;

	float center = SceneSdf(float3(pos.x, pos.y, pos.z), smoothness);

	return float4(normalize(float3(
		center - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON), smoothness)
		)), center);
}

float4 SdfNormalAndDistance(float3 pos)
{
	//_RayMarchSmoothness
	return SdfNormalAndDistance(pos, _RayMarchSmoothness);
}

float4 renderSdfProgression(in float3 ro, in float3 rd, float pixelScale)
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

float4 renderSdf(in float3 ro, in float3 rd, in float4 seed) {

	float dist = 0;

//	rd = normalize(rd);

	float totalDistance = 0;

	float max_steps =
#if RT_MOTION_TRACING
		50;
#else
		_maxRayMarchSteps;
#endif

	float stepsFractionUsed = 1;

	float3 randomOffset = 0;
	float spermingAmount = 0;

	for (int i = 0; i < max_steps; i++) {

		dist = SceneSdf(ro); // + randomOffset * spermingAmount) * (1 + (seed.x-0.5) * 0.1);

		ro += dist * rd;

		totalDistance += dist;

		randomOffset = float3(seed[i%4], seed[(i+1)%4], seed[(i+2)%4]) - 0.5;

		spermingAmount = (spermingAmount + 0.01) / (1+dist*dist*100);

		if (abs(dist) < 0.01) 
		{
			stepsFractionUsed = i/max_steps;
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


	float3 skyCol = getSkyColor(lerp( -rd, -reflected, saturate(reflectedSky)), 1);

	//return float4(skyCol,1);
	
	float3 fresnelReflection = //(1 + dott * 0.5)
		//*
		(reflCol * (1 - reflectedSky) +
			skyCol * reflectedSky +
			lightRelected * shadow
			);


	col.rgb = lerp(col.rgb, fresnelReflection, fresnel);


	col.rgb = lerp(skyCol, col.rgb, deFog);
	
	col.rgb = lerp(col.rgb, float3(0,1,0), stepsFractionUsed);

	return 	max(0, col);

}

