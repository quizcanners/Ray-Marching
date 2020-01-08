#include "RayMarch.cginc"

uniform float4 RayMarchCube_0;
uniform float4 RayMarchCube_0_Size;
uniform float4 RayMarchCube_1;
uniform float4 RayMarchCube_1_Size;
uniform float4 RayMarchCube_1_Reps;
uniform float4 RayMarchSphere_0;
uniform float4 RayMarchSphere_0_Reps;
uniform float4 RayMarchSphere_1;
uniform float4 RayMarchSphere_1_Reps;

float _maxRayMarchSteps;
float _MaxRayMarchDistance;


float _RayMarchSmoothness;
float _RayMarchShadowSoftness;

inline float SceneSdf(float3 position) {


	//RayMarchSphere_0.w = RayMarchSphere_0.w * 1.0001; // 0.3 * 3; //)* 0.3;

	float s0 = SphereDistance(position, RayMarchSphere_0, RayMarchSphere_0_Reps);
	float s1 = SphereDistance(position, RayMarchSphere_1); //, RayMarchSphere_1_Reps);

	float c0 = CubeDistance(position, RayMarchCube_0, RayMarchCube_0_Size.xyz, _RayMarchSmoothness);
	float c1 = CubeDistance(position, RayMarchCube_1, RayMarchCube_1_Size.xyz, _RayMarchSmoothness);

	float grid = GridDistance(position, 200 + 50 * _SinTime.z, 5);


	float dist = CubicSmin(s0, grid, _RayMarchSmoothness);

	dist = CubicSmin(dist, grid, _RayMarchSmoothness);

	dist = CubicSmin(dist, c0, _RayMarchSmoothness * 2);

	dist = OpSmoothSubtraction(dist, s1, _RayMarchSmoothness);

	dist = CubicSmin(dist, c1, _RayMarchSmoothness * 2);

	return dist;
}

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

		if (dist*maxSteps < 0.0001)
			return 0.0;


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