#ifndef QC_SVG_TRC
#define QC_SVG_TRC

#include "Savage_Sampler.cginc"
#include "PrimitivesScene_Intersect.cginc"

#define RAYTRACE_AT 0.75

struct RaySamplerHit
{
	float3 Pos;
	float3 Normal;
	float4 Material;
};

float3 SampleRay_NoSun_MipSky(float3 pos, float3 ray, float smoothness, out RaySamplerHit hit)
{
	hit.Material = float4(SampleSkyBox(ray, smoothness), 0);
	float2 MIN_MAX = float2(0.0001, MAX_DIST_EDGE);

	pos = pos + ray * 0.1;
	//pos.y = abs(pos.y);

	float3 res = worldhit(pos , ray, MIN_MAX, hit.Normal, hit.Material);

	float type = res.z;

	float distance = res.y;

	hit.Pos = pos + ray * distance;

	float3 col;

	#if _qc_IGNORE_SKY
		UNITY_FLATTEN
	#else
		UNITY_BRANCH
	#endif
	if (type>0 && type < EMISSIVE)
	{
		//hit.Normal =  EstimateNormal(hit.Pos, length(distance) * 0.05);

	//float3 pos, float3 normal, out float outOfBounds
		float3 reflected = reflect(ray, hit.Normal);
		
		//float spec = hit.Material.a;

		float3 bake = SampleVolume_CubeMap(hit.Pos, hit.Normal) * SampleContactAO(hit.Pos, hit.Normal);

		col = (bake
		#if !_qc_IGNORE_SKY
			+ GetDirectional() * SampleRayShadowAndAttenuation(hit.Pos, hit.Normal)
		#endif

		) * hit.Material.rgb;

	} else 
	{
		col =  hit.Material.rgb;
	}
	
	//col = lerp(col, GetAmbientLight(), qc_KWS_FogAlpha * smoothstep(0, 32, distance));

	return col;
}

float3 SampleRay_NoSun(float3 pos, float3 ray, out RaySamplerHit hit) 
{
	return SampleRay_NoSun_MipSky(pos, ray, 1.0, hit);
}

float3 GetPointLight(float3 position, float3 normal, float ao)
{
	if (_qc_PointLight_Color.a==0)
	{
		return 0;
	}

	float3 lightDir = _qc_PointLight_Position.xyz - position;

	float distance = length(lightDir);

	lightDir = normalize(lightDir);

	float2 MIN_MAX = float2(0.0001, distance);

	bool isHit = RaycastStaticPhisics(position + normal * 0.01 , lightDir, MIN_MAX);

	if (isHit) 
		return 0;
	
	float distFade = 1/(distance + 1);
	float distFadeSquare =  distFade * distFade;
	float direct = smoothstep( -ao * distFadeSquare, 1.5 - ao * 0.5, saturate(dot(normal, lightDir)));
	direct = lerp(direct, 1, distFadeSquare);
	
	float3 col = _qc_PointLight_Color.rgb * direct * distFadeSquare;

	return col;
}

float3 GetPointLight(float3 position, float3 normal, float ao, float3 viewDir, float gloss, inout float3 lightSpecular)
{
	if (_qc_PointLight_Color.a==0)
	{
		return 0;
	}

	float3 lightDir = _qc_PointLight_Position.xyz - position;
	float distance = length(lightDir);
	lightDir = normalize(lightDir);

	float2 MIN_MAX = float2(0.0001, distance);

	bool isHit = Raycast(position + normal * 0.01 , lightDir, MIN_MAX);

	if (isHit) 
		return 0;
	
	float distFade = 1/(distance + 1);
	float distFadeSquare =  distFade * distFade;

	float direct = smoothstep( -ao * distFadeSquare, 1.5 - ao * 0.5, saturate(dot(normal, lightDir)));

	direct = lerp(direct, 1, distFadeSquare);
	
	float3 col = _qc_PointLight_Color.rgb * direct * distFadeSquare;

	float3 toCamera = normalize(_qc_PointLight_Position.xyz - _WorldSpaceCameraPos.xyz);
	 float3 reflectedRay = reflect(-viewDir,normal);
	float power = pow(gloss + 0.001,8) ;
    float specularTerm = pow(max(dot(lightDir,reflectedRay),0), power* 92) * power * distFade; 
	lightSpecular += specularTerm * _qc_PointLight_Color.rgb;

	return col;
}

float3 GetPointLight_Specualr(float3 position, float3 reflectedRay, float gloss)
{
	if (_qc_PointLight_Color.a==0)
	{
		return 0;
	}

	float3 lightDir = _qc_PointLight_Position.xyz - position;
	float distance = length(lightDir);
	lightDir = normalize(lightDir);

	float2 MIN_MAX = float2(0.0001, distance);

	bool isHit = Raycast(position, lightDir, MIN_MAX);

	if (isHit) 
		return 0;
	float distFade = 1/(distance + 1);
	float power = pow(gloss + 0.001,8) ;
    float specularTerm = pow(max(dot(lightDir,reflectedRay),0), power* 92) * power * distFade; 
	return specularTerm * _qc_PointLight_Color.rgb;

}

float4 GetRayTrace_AndAo(float3 worldPos, float3 reflectedRay, float smoothness)
{
	RaySamplerHit hit;
	float3 reflectedColor = SampleRay_NoSun_MipSky(worldPos, reflectedRay, smoothness, hit);

	float3 reflectedTopDown = 0;

	float ao = TopDownSample(hit.Pos, reflectedTopDown);
	
	reflectedColor *= ao;
	
	reflectedColor += reflectedTopDown * hit.Material.rgb;
	float hitSpecular = smoothstep(1, 0, hit.Material.a) * 0.9;

	reflectedColor.rgb += GetPointLight(hit.Pos, hit.Normal, ao, reflectedRay,hitSpecular, reflectedColor)  * hit.Material.rgb;

	return float4(reflectedColor, ao);
}

float3 GetBakedAndTracedReflection(float3 worldPos, float3 reflectedRay, float specular)
{
	//ModifySpecularByAO(specular, ao);

	float3 result = SampleVolume_CubeMap(worldPos, reflectedRay); // Adds unwanted Avarage ambient to reflection
	
	const float DE_REFLECT_AT = 1 / (1 - RAYTRACE_AT);

#if _SIMPLIFY_SHADER
	return result;
#endif

	//specular *= ao;


	if (specular > RAYTRACE_AT)
	{
		float rflectionTransition = (specular - RAYTRACE_AT) * DE_REFLECT_AT;
		float4 reflection = GetRayTrace_AndAo(worldPos, reflectedRay, specular);
		result = lerp(result, reflection.rgb, rflectionTransition) * lerp(1, reflection.a, rflectionTransition);
	}

	return result;
}

float3 GetBakedAndTracedReflection(float3 worldPos, float3 reflectedRay, float specular, float3 vertexPrecalculated)
{
	//ModifySpecularByAO(specular, ao);

	float3 result = SampleVolume_CubeMap(worldPos, reflectedRay).rgb;

	#if _PER_PIXEL_REFLECTIONS_MIXED || _PER_PIXEL_REFLECTIONS_INVERTEX
		result +=  vertexPrecalculated.rgb * pow(specular, 2);
	#endif

	const float DE_REFLECT_AT = 1 / (1 - RAYTRACE_AT);

#if _SIMPLIFY_SHADER || _PER_PIXEL_REFLECTIONS_OFF
	return result;
#endif

/*
#if !_PER_PIXEL_REFLECTIONS_ON && !_PER_PIXEL_REFLECTIONS_INVERTEX && !_PER_PIXEL_REFLECTIONS_MIXED

#endif
*/
	
	//specular *= ao;

	if (specular > RAYTRACE_AT)
	{
		float4 reflection = float4(0,0,0,1);

		#if _PER_PIXEL_REFLECTIONS_MIXED
			reflection = GetRayTrace_AndAo(worldPos, reflectedRay,specular);
			reflection.rgb = lerp(vertexPrecalculated, reflection.rgb, smoothstep(RAYTRACE_AT,RAYTRACE_AT + (1-RAYTRACE_AT)*0.5,specular));
		#elif _PER_PIXEL_REFLECTIONS_INVERTEX
			 reflection.rgb = vertexPrecalculated.rgb;
		#else
			 reflection = GetRayTrace_AndAo(worldPos, reflectedRay, specular);
		#endif
		//	return reflection;

		float rflectionTransition = (specular - RAYTRACE_AT) * DE_REFLECT_AT;
		//rflectionTransition += outOfBounds * rflectionTransition * (1- rflectionTransition);

		//return result;

		result = lerp(result, reflection.rgb, rflectionTransition) * lerp(1, reflection.a, rflectionTransition);
	} 

	return result;
}

float4 GetTraced_Mirror_Vert(float3 worldPos, float3 viewDir, float3 normal)
{
	float4 traced;
	traced.a = 1; // GetQcShadow(worldPos);

	#if _PER_PIXEL_REFLECTIONS_MIXED || _PER_PIXEL_REFLECTIONS_INVERTEX

		float3 volumeSamplePosition = worldPos + normal*0.01;

		float3 reflectedRay = reflect(-viewDir, normal);
		float3 bakeReflected = GetRayTrace_AndAo(volumeSamplePosition, reflectedRay, 1);

		float3 offsetRay = normalize(reflectedRay + normal*0.5);
		bakeReflected += GetRayTrace_AndAo(volumeSamplePosition, offsetRay, 1);

		traced.rgb = bakeReflected.rgb * 0.5;
	#else 
		traced.rgb = float3(1,0,1); // Should never be seen
	#endif

	return traced;

}

float4 GetTraced_Subsurface_Vertex(float3 worldPos, float3 viewDir, float3 normal)
{
	float4 traced;
	traced.a = GetQcShadow(worldPos);

	float3 volumeSamplePosition = worldPos + normal*0.01;

	traced.rgb = SampleVolume_CubeMap(worldPos, -normal);

	return traced;
}

#endif