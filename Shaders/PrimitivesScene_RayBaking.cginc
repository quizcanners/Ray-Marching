#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Intersect.cginc"
#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_PostEffectBake.cginc"

//#include "Assets/Qc_Rendering/Shaders/Savage_VolumeSampling.cginc"

// ****************** Intersections

#if RT_MOTION_TRACING
	#define PATH_LENGTH 3
#elif _qc_IGNORE_SKY
	#define PATH_LENGTH 7
#else
	#define PATH_LENGTH 5
#endif

float3 modifyDirectionWithRoughnessFast(in float3 normal, in float3 refl, in float roughness, in float4 seed) {

	return lerp(normalize(normal + seed.wzx), refl, step(seed.y, roughness));

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
	const float MIN_DIST = 0.000001;

	float3 albedo, normal;
	float3 col = 1;
	float3 gatherLight = 0;
	float roughness, type;

	bool isFirst = true;
	float distance = MAX_DIST_EDGE;
	float4 mat = 0;

	float FADE_RAY_AT = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 4;
	float rayHitDist = FADE_RAY_AT;

#if !RT_DENOISING && !RT_TO_CUBEMAP
	for (int i = 0; i < PATH_LENGTH; ++i)
	{
#endif
		
		float3 res = worldhit(ro, rd, float2(MIN_DIST, MAX_DIST_EDGE), normal, mat);
		roughness = mat.a;
		albedo = mat.rgb;
		type = res.z;
		// res.x =
		// res.y = dist
		// res.z = material

		rayHitDist = res.y;

		/*
#if RT_DENOISING

		distance = isFirst ?
			rayHitDist +
			dot(rd, normal)
			: distance;
		isFirst = false;
#endif*/

		if (res.z <= 0.)
		{
			#if _qc_IGNORE_SKY
				return float4(0,0,0, distance);
			#endif

			float3 skyCol = getSkyColor(rd);
			return float4(col * skyCol * _qc_AmbientColor.rgb, distance);
		}

		ro += rd * res.y;

		//float3 postColor;
		//float postAo;
		//SamplePostEffects(ro - rd*0.01, normal, postColor, postAo, seed);
		//gatherLight += postColor * col * albedo;
		//col *= postAo;

		col *= smoothstep(0, FADE_RAY_AT, rayHitDist);

#if RT_TO_CUBEMAP && _qc_IGNORE_SKY
	
	//UNITY_FLATTEN
	if (type < EMISSIVE + 1 &&  type >= EMISSIVE ) 
	{	
		return float4(col * albedo * 4 + gatherLight, distance);
	} else 
	{

		#if !qc_NO_VOLUME
			float outOfBounds1;
			float volCellSize = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;
			col *= SampleVolume(_RayMarchingVolume, ro + normal * min(distance * 0.5, volCellSize), outOfBounds1).rgb * (1 - outOfBounds1);
		#else 
			col = 0;
		#endif

		return float4(col * albedo + gatherLight, distance);
	}

#endif

			/*
#define LAMBERTIAN 0.
#define METAL 1.
#define DIELECTRIC 2.


#define GLASS 3.
#define EMISSIVE 4.
#define SUBTRACTIVE 5.*/



UNITY_BRANCH
if (type < DIELECTRIC + 0.5)
{
			UNITY_BRANCH
			if (type < LAMBERTIAN + 0.5) 
			{ 
				col *= albedo;
				rd = cosWeightedRandomHemisphereDirection(normal, seed);

				#if !_qc_IGNORE_SKY
				if (_qc_SunVisibility > 0)
				{
					float attenuation = smoothstep(0, 1, dot(qc_SunBackDirection.xyz, normal));

					if (attenuation > (seed.x) && !Raycast(ro + normal*0.001, qc_SunBackDirection.xyz + (seed.zyx-0.5)*0.3, float2(0.0001, MAX_DIST_EDGE)))
					{
						col.rgb *= GetDirectional() * attenuation;
						return float4(col + gatherLight, distance);
					}
				}
				#endif
			}
			else
			if (type < METAL + 0.5) 
			{ 
				col *= albedo;
				rd = modifyDirectionWithRoughness(normal, reflect(rd, normal), roughness, seed);
			} else  //if (type < DIELECTRIC + 0.5)
			{
			
					ro += rd * 0.25;// +(seed.zyx - 0.5) * 0.1;
					normal = -normal;
					
					rd = cosWeightedRandomHemisphereDirection(normal, seed);

					#if !_qc_IGNORE_SKY
					if (_qc_SunVisibility > 0) 
					{
						if (!Raycast(ro + normal * 0.001, qc_SunBackDirection.xyz + (seed.zyx - 0.5) * 0.3, float2(0.0001, MAX_DIST_EDGE)))
						{
							float toSUn = smoothstep(0, -1, dot(qc_SunBackDirection.xyz, normal));
						
							col *= albedo;
							col.rgb *= GetDirectional() * (1 + toSUn * 16);
							return float4(col + gatherLight, distance);
						}
					}
					#endif
			}
} 
else  
{
//#if RT_USE_DIELECTRIC

			UNITY_BRANCH
			if (type < GLASS + 0.5) //DIELECTRIC + GLASS
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
				return float4(col * albedo * 4 + gatherLight, distance);
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
		

#if !RT_DENOISING && !RT_TO_CUBEMAP
	}
#endif

	float3 light = 0; 
	
	#if !qc_NO_VOLUME
		float outOfBounds;
		light += SampleVolume(_RayMarchingVolume, ro + normal *  min(distance * 0.5, _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w), outOfBounds).rgb * (1 - outOfBounds);
		//light *= smoothstep(0, FADE_RAY_AT, rayHitDist);

	#endif

	#if !_qc_IGNORE_SKY
		if (_qc_SunVisibility>0) 
		{
			float shadow = SampleRayShadowAndAttenuation(ro, normal);
			light += GetDirectional() * shadow;
		}
	#endif
	
	col.rgb *= light;

	return float4(col + gatherLight, distance);

}