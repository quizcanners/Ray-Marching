#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"

uniform float4 _qc_BloodColor;
uniform float _qc_RainVisibility;
uniform float _qc_Sun_Atten;

#define BLOOD_SPECULAR 0.9
#define RAYTRACE_AT 0.75

#define TRANSFER_TOP_DOWN(o) o.topdownUv = (o.worldPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;




inline float SampleContactAO_OffsetWorld(inout float3 pos, float3 normal)
{
	#if !qc_NO_VOLUME

		float outsideVolume;
		float4 scene = SampleSDF(pos , outsideVolume);

		float coef = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

		pos += normal * coef;

		//float sameNormal = smoothstep(-1, 1, dot(normal, scene.xyz));
		return lerp(smoothstep( -2 * coef, 2 * coef, (scene.a + dot(normal, scene.xyz)*2 * coef)),1, outsideVolume);
	#else 
		return 1;
	#endif
}

float3 SampleAmbientLight(float3 pos, out float ao)
{
		float outOfBounds;
		float3 baked = SampleVolume(_RayMarchingVolume, pos, outOfBounds).rgb;
						
		float valid = (1 - outOfBounds);

		baked =lerp(GetAmbientLight(), baked, valid);

		float3 reflectedTopDown = 0;
		ao = TopDownSample(pos, reflectedTopDown);
		baked += reflectedTopDown * 0.1; 
		baked *= ao;
		return baked;
}

float4 SampleTopDown_Ambient(float2 topdownUv, float3 normal, float3 worldPos)
{
	float2 offset = normal.xz * _RayTracing_TopDownBuffer_Position.w;

	topdownUv += offset * 0.2;

	TOP_DOWN_SAMPLE_LIGHT(topDown, topdownUv);
	TOP_DOWN_ALPHA(gotVolume, worldPos, topdownUv)

	topDown *= gotVolume;
	float ambientBlock = max(0.25f, 1 - topDown.a);

	return float4(topDown.rgb, ambientBlock);
}


float4 SampleTopDown_Specular(float2 topdownUv, float3 reflected, float3 worldPos, float3 rawNormal, float specular)
{
	float2 offset = reflected.xz * _RayTracing_TopDownBuffer_Position.w;

	topdownUv += offset * (0.1 + specular * specular * 4);

	float4 topDown = tex2D(_RayTracing_TopDownBuffer, topdownUv);

	TOP_DOWN_ALPHA(gotVolume, worldPos, topdownUv)


	topDown *= gotVolume;
	topDown.rgb *= smoothstep(1, 0, abs(rawNormal.y)); // vertical normal will often result in light leaing trough walls

	float ambientBlock = max(0.25f, 1 - topDown.a);

	return float4(topDown.rgb, ambientBlock);
}

float ApplyTopDownLightAndShadow(float2 topdownUv, float3 normal, float4 bumpMap, float3 worldPos, float gotVolume, float fresnel, inout float4 bake)
{
	float smoothness = bumpMap.b;

	float2 offset = normal.xz * _RayTracing_TopDownBuffer_Position.w;

	//float2 offUv = topdownUv - 0.5;
//	gotVolume = (1 - smoothstep(0.2, 0.25, length(offUv * offUv)));

	float4 topDown = tex2D(_RayTracing_TopDownBuffer, topdownUv + offset * 0.2
	); // *(0.2 + smoothness));
	float4 topDownRefl = tex2Dlod(_RayTracing_TopDownBuffer, float4(topdownUv + offset * (1 + 8 * smoothness)
		, 0, 0));

	TOP_DOWN_ALPHA(topDownVisible, worldPos, topdownUv)

	//float topDownVisible = gotVolume * (1 - fresnel * 0.5) * smoothstep(3, 0, abs(_RayTracing_TopDownBuffer_Position.y - worldPos.y));
	topDown *= topDownVisible;
	topDownRefl *= topDownVisible;
	float ambientBlock = max(0.25f, 1 - topDown.a);
	//shadow *= ambientBlock;

	float3 light = (topDown.rgb + topDownRefl.rgb) * bumpMap.a;

	float3 mix = light.gbr + light.brg;

	bake *= ambientBlock;
	bake.rgb += light + mix * 0.2f;

	return ambientBlock;
}

float ApplyTopDownLightAndShadow(float2 topdownUv, float3 normal, float3 worldPos, float gotVolume, inout float4 bake)
{

	float4 bumpMap = float4(0.5, 0.5, 1, 0.2);
	float fresnel = 1;

	return ApplyTopDownLightAndShadow(topdownUv, normal, bumpMap, worldPos, gotVolume, fresnel, bake);
}

// Wetness

float GetRain(float3 worldPos, float3 normal, float3 rawNormal, float shadow)
{
#if _qc_IGNORE_SKY
	return 0;
#endif

	if (_qc_RainVisibility == 0)
	{
		return 0;
	}

	float vis = _qc_RainVisibility;

	float3 avgNormal = normalize(rawNormal + normal);

	vis*= shadow;
	/*
#	if !_DYNAMIC_OBJECT && !_SIMPLIFY_SHADER
	vis *= RaycastStaticPhisics(worldPos + avgNormal * 0.5, float3(0, 1, 0), float2(0.0001, MAX_DIST_EDGE)) ? 0 : 1;
#	endif*/

	vis *= (1 + smoothstep(0, 1, avgNormal.y))* 0.5;

	return vis;
}

float ApplyBlood(float4 mask, inout float water, inout float3 tex, inout float4 madsMap, float displacement)
{
	float bloodAmount = mask.r - displacement;
	
	const float SHOW_RED_AT = 0.01;
	//const float SHOW_BLOOD_AT = 0.4;

	float showRed = smoothstep(SHOW_RED_AT, SHOW_RED_AT + 0.1 + water, bloodAmount);

	water += showRed * mask.r;

	float3 bloodColor = _qc_BloodColor.rgb *(1 - 0.5 * smoothstep(0, 1, water));//(0.75 + showRed * 0.25);

	tex.rgb = lerp(tex.rgb, bloodColor, showRed);

	madsMap.r = lerp(madsMap.r, 0.98, showRed );

	return showRed;
}

const float SHOW_WET = 0.2;
const float WET_DARKENING = 0.5;

void ModifyColorByWetness(inout float3 col, float water, float smoothness)
{
#if _REFLECTIVITY_METAL
	return;
#endif
	float darken = 	WET_DARKENING;// * (1-smoothness);
	col *= (1-darken) + smoothstep(SHOW_WET + 0.01, SHOW_WET, water) * darken;
}

void ModifyColorByWetness(inout float3 col, float water, float smoothness, float4 dirtColor)
{
	col = lerp(col, dirtColor.rgb, smoothstep(0, 2, water) * dirtColor.a);

	ModifyColorByWetness(col, water, smoothness);
	//float darken = WET_DARKENING * (1-smoothness);

	//col *= (1-darken) + smoothstep(SHOW_WET + 0.01, SHOW_WET, water) * darken;
}

float4 GetRainNoise(float3 worldPos, float displacement, float up, float rain)
{
#if !_SIMPLIFY_SHADER && !_DYNAMIC_OBJECT

	if (_qc_RainVisibility == 0)
	{
		return 0.5;
	}

	worldPos.y *= 0.1;

	float4 noise = Noise3D(worldPos * 0.5 + worldPos.yzx * 0.1 + float3(0, _Time.x * 4 + (up - displacement) * 0.2, 0));
	noise = lerp(0.5, noise, (1 + rain) * 0.5);

	return noise;

#else
	return 0.5;
#endif

	
}

float ApplyWater(inout float water, float rain, inout float ao, float displacement, inout float4 madsMap, float4 noise)
{
	const float FLATTEN_AT = 0.9;
	const float WET_GAP = FLATTEN_AT - SHOW_WET;

	water += rain;
	water = max(0, water - displacement);
	float dynamicLevel = FLATTEN_AT + (2 * noise.b - 1) * 0.5 * WET_GAP;
	madsMap.ra = lerp(madsMap.ra, float2(0, 0.975), smoothstep(SHOW_WET, FLATTEN_AT, water));
	float flattenSurface = smoothstep(dynamicLevel - 0.01 - noise.r
	, dynamicLevel, water);
	madsMap.gb = lerp(madsMap.gb, float2(1, 1), flattenSurface);
	ao = lerp(ao, 1, flattenSurface);
	return flattenSurface;
}


// Lighting

void MixInSpecular(inout float3 ambCol, float3 reflectionColor, float3 tex, float metal, float reflectivity, float fresnel)
{
	reflectionColor *= lerp(0.5, tex, metal);
	ambCol= lerp(ambCol, reflectionColor, reflectivity);
}

void MixInSpecular_Plastic(inout float3 ambCol, float3 reflectionColor, float reflectivity)
{
	ambCol= lerp(ambCol, reflectionColor, reflectivity);
}

void MixInSpecular_Layer(inout float3 ambCol, float3 reflectionColor, float3 tex, float metal, float specular, float fresnel, float layer)
{
	ambCol *= (1 - metal * 0.9);

	reflectionColor *= lerp(0.5, tex, metal) * 2;

	float showReflection = lerp(specular, 0.05 + fresnel * 0.5, layer);

	ambCol= lerp(ambCol, reflectionColor, showReflection);
}

float AttenuationFromAo(float ao, float3 normal)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	return smoothstep(1 - ao, 1.5 - ao * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));
}

float GetFresnel_FixNormal(inout float3 normal, float3 rawNormal, float3 viewDir)
{
	float normDiff = dot(normal, viewDir);



//	normal = lerp(normal, perp, normError);

	return pow((1 - saturate(normDiff)), 4);// * (1-normError);
} 


float GetFresnel(float3 normal, float3 viewDir)
{
	return pow((1 - saturate(dot(normal, viewDir))), 4);
} 

float GetSpecular_Plastic(float madsA, float fresnel)
{
	float byFresnel =  pow(madsA,3);
	byFresnel += (1 - byFresnel) * fresnel; 
	return 0.025 + byFresnel * 0.95;
}

float GetSpecular_Metal(float madsA, float fresnel)
{
	return 0.025 + (0.75 + madsA * 0.25) * 0.95;
}

float GetSpecular_Layer(float madsA, float fresnel)
{
	return madsA * fresnel; //0.025 + (0.75 + madsA * 0.25) * 0.95;
}

float GetSpecular(float madsA, float fresnel, float metal)
{
	//float byFresnel =  pow(madsA,3);
	//byFresnel += (1 - byFresnel) * fresnel; 
	return 0.025 + lerp(madsA * (1 + (1-madsA)*fresnel), 0.75 + madsA * 0.25, metal) * 0.95;
}

float3 Savage_GetDirectional_Opaque(inout float shadow, float ao, float3 normal, float3 worldPos)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif


	
	float angle =dot(_WorldSpaceLightPos0.xyz, normal);


	/*angle = 1-max(0, angle);
	angle = pow(angle, 0.1+ao * _qc_Sun_Atten);
	float atten = 1-angle;*/

	
	float atten = _qc_Sun_Atten;
	float aoObscuring = smoothstep(1,0,atten) * ao * 0.95;
	angle = smoothstep(aoObscuring,1,angle);
	angle = 1-pow(1-angle,1 + (1-ao) * 2 * atten);
	float blowout = atten * 0.2;
	atten = (angle * (1-blowout) + blowout);


	return GetDirectional() * shadow * atten;
}


float3 GetVolumeSamplingPosition(float3 worldPos, float3 rawNormal)
{
	return worldPos;
	// + rawNormal.xyz * _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 0.5;
}

float3 Savage_GetVolumeBake(float3 worldPos, float3 normal, float3 rawNormal, out float3 safePosition)
{
	safePosition = GetVolumeSamplingPosition(worldPos, rawNormal);//worldPos + rawNormal.xyz * _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 0.5;

#if _SIMPLIFY_SHADER
	return GetAvarageAmbient(normal);
#endif

	return SampleVolume_CubeMap(safePosition, normal).rgb;
}

float GetDirectionalSpecular(float3 normal, float3 viewDir, float gloss)
{
#if _SIMPLIFY_SHADER || _qc_IGNORE_SKY
	return 0;
#endif

	//if (_qc_SunVisibility == 0 || qc_KWS_FogAlpha > 0.9)
		//return 0;

	//viewDir.y = -viewDir.y;

	gloss *= 0.95;

	float roughness = pow(1 - gloss, 2);

	float3 lightDir = _WorldSpaceLightPos0.xyz;

	//lightDir.y = -lightDir.y;

	float3 halfDir = normalize(viewDir + lightDir);
	float NdotH = max(0.01, dot(normal, halfDir));
	float lh = dot(lightDir, halfDir);

	float specularTerm = roughness * roughness;

	float d = NdotH * NdotH * (specularTerm - 1.0) + 1.00001;
	float normalizationTerm = roughness * 4.0 + 2.0;

	specularTerm /= (d * d) * max(0.1, lh * lh) * normalizationTerm;
	return specularTerm * (1- qc_KWS_FogAlpha);// * (1 + pow(gloss, 8) * 64);
}

float4 GetRayTrace_AndAo(float3 worldPos, float3 reflectedRay, float smoothness)
{
	RaySamplerHit hit;
	float3 reflectedColor = SampleRay_NoSun_MipSky(worldPos, reflectedRay, smoothness, hit);

	float3 reflectedTopDown = 0;

	float ao = TopDownSample(hit.Pos, reflectedTopDown);
	reflectedColor += reflectedTopDown * hit.Material.rgb;
	float hitSpecular = smoothstep(1, 0, hit.Material.a) * 0.9;

	reflectedColor.rgb += GetPointLight(hit.Pos, hit.Normal, ao, reflectedRay,hitSpecular, reflectedColor)  * hit.Material.rgb;

	return float4(reflectedColor, ao);
}



float ApplySubSurface(inout float3 col, float4 subSkin, float3 volSamplePos, float3 viewDir, float specular, float rawFresnel, float shadow)
{
	//float4 skin = tex2D(_SkinMask, i.texcoord.xy);
	float subSurface = subSkin.a * (2 - rawFresnel) * 0.5;

	col *= 1 - subSurface;

	float3 forwardBake = SampleVolume_CubeMap(volSamplePos, -viewDir);

	#if !_qc_IGNORE_SKY
		float sun = 1 / (0.1 + 1000 * smoothstep(1, 0, dot(_WorldSpaceLightPos0.xyz, -viewDir)));
	#endif

	col.rgb += subSurface * subSkin.rgb * (forwardBake 

	#if !_qc_IGNORE_SKY
		+ GetDirectional() * (1 + sun) * shadow
	#endif

	);

	return subSurface;
}


void CheckParallax(inout float2 uv, inout float4 madsMap, sampler2D _SpecularMap, float3 tViewDir, float amount, inout float displacement)
{
#	if _PARALLAX

	uv += tViewDir.xy * (displacement - 0.5) * 1 * amount;

	madsMap = tex2D(_SpecularMap, uv);
	displacement = madsMap.b;
	uv += tViewDir.xy * (displacement - 0.5) * 0.5 * amount;

	madsMap = tex2D(_SpecularMap, uv);
	displacement = madsMap.b;

#	endif
}


float3 GetPointLight_Transpaent(float3 position, float3 viewDir)
{
	if (_qc_PointLight_Color.a==0)
	{
		return 0;
	}

	float3 lightDir = _qc_PointLight_Position.xyz - position;

	float distance = length(lightDir);

	lightDir = normalize(lightDir);

	float2 MIN_MAX = float2(0.0001, distance);

	bool isHit = Raycast(position , lightDir, MIN_MAX);

	if (isHit)
		return 0;
	
	float direct = smoothstep(0, 1, dot(-viewDir, lightDir));

	float distFade = 1/distance;
	float distSquare =  distFade * distFade;

	float3 col = _qc_PointLight_Color.rgb * (1 + direct) * 0.5 * distSquare;

	return col;

}




float3 GetBakedAndTracedReflection(float3 worldPos, float3 reflectedRay, float specular, float ao)
{

	float3 result = SampleVolume_CubeMap(worldPos, reflectedRay); // Adds unwanted Avarage ambient to reflection
	result *= ao;

	const float DE_REFLECT_AT = 1 / (1 - RAYTRACE_AT);

#if _SIMPLIFY_SHADER
	return result;
#endif

	if (specular > RAYTRACE_AT)
	{
		float rflectionTransition = (specular - RAYTRACE_AT) * DE_REFLECT_AT;
		float4 reflection = GetRayTrace_AndAo(worldPos, reflectedRay, specular);
		result = lerp(result, reflection.rgb, rflectionTransition) * lerp(1, reflection.a, rflectionTransition);
	}

	return result;
}


float3 GetBakedAndTracedReflection(float3 worldPos, float3 reflectedRay, float specular, float3 vertexPrecalculated, float ao)
{
	float3 result = SampleVolume_CubeMap(worldPos, reflectedRay).rgb * ao;

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

float GetQcShadow(float3 worldPos)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	if (_qc_SunVisibility<0.01)
			return 0;

	return SampleRayShadow(worldPos); // * SampleSkyShadow(worldPos);
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

float4 GetTraced_Glassy_Vertex(float3 worldPos, float3 viewDir, float3 normal)
{
	float4 traced;
	traced.a = GetQcShadow(worldPos);

	float3 volumeSamplePosition = worldPos + normal*0.01;
	float fresnel = GetFresnel(normal, viewDir); // Will flip normal if backfacing 

	float ao = 1;

	float3 reflectedRay = reflect(-viewDir, normal);
	float3 bakeReflected = GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, BLOOD_SPECULAR, ao);//SampleReflection(i.worldPos, viewDir, normal, shadow, hit);
	
	float3 refractedRay =  refract(-viewDir, normal, 0.75);//normalize(-viewDir - normal * 0.2);
	float3 bakeStraight = GetBakedAndTracedReflection(volumeSamplePosition, refractedRay, BLOOD_SPECULAR, ao);

	float showStright = (1 - fresnel);

	traced.rgb = lerp(bakeReflected.rgb, bakeStraight.rgb, showStright * showStright);

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


float3 GetTranslucent_Sun(float3 refractedRay)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	if (_qc_SunVisibility == 0)
		return 0;

	float translucentSun =  smoothstep(0.8,1, dot(_WorldSpaceLightPos0.xyz, refractedRay));
	return translucentSun * 4 * GetDirectional(); 
}

float4 GetTraced_AlphaBlitted_Vertex(float3 worldPos, float3 viewDir)
{
	float4 traced;
	traced.a = GetQcShadow(worldPos);
	traced.rgb = SampleVolume_CubeMap(worldPos, viewDir);

	#if _PER_PIXEL_REFLECTIONS_MIXED || _PER_PIXEL_REFLECTIONS_INVERTEX
		float ao = 1;
		float3 bakeStraight = GetBakedAndTracedReflection(worldPos, -viewDir, BLOOD_SPECULAR, ao);
		traced.rgb = (traced.rgb + bakeStraight.rgb) * 0.5;
	#endif

	return traced;
}



/*

#define GET_AMBIENT_OCCLUSION(ao)\
float ao =1; \
#if _AO_SEPARATE\
#	if _AMBIENT_IN_UV2\
ao = tex2D(_OcclusionMap, i.texcoord1.xy).r;\
#	else\
ao = tex2D(_OcclusionMap, uv).r;\
#endif \
#elif _AO_MADS\
ao = madsMap.g;\
#else\
ao = 1;\
#endif\*/

