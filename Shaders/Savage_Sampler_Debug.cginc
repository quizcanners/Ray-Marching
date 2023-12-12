#include "Assets/Ray-Marching/Shaders/Savage_Sampler.cginc"

struct MaterialParameters
{
	float shadow;
	float ao;
	float fresnel;
	float3 tex;
	float smoothsness;
	float reflectivity;
	float metal;
	float4 traced;
	float water;
	float4 microdetail;
	float3 metalColor;
};





inline void ReflectionByAo(inout float3 reflection, float ao, float fresnel)
{
	reflection *= lerp(ao, 1, fresnel);//pow(ao, 1 + fresnel*3);
}

float3 GetReflection_ByMaterialType(MaterialParameters input, float3 normal, float3 rawNormal, float3 viewDir,  float3 worldPos) 
{
	float3 lightColor = Savage_GetDirectional_Opaque(input.shadow, input.ao, normal, worldPos);

	float3 reflectedRay = reflect(-viewDir, normal);


	float normError = smoothstep(0.2, 0.01, dot(reflectedRay, rawNormal));
	float3 reflFix = reflect(-viewDir,rawNormal);
	float3 perp = normalize(lerp(-viewDir,reflFix, 0.55));
	reflectedRay = lerp(reflectedRay, perp, normError);

	float3 reflectionColor = 0;
	float3 volumeSamplePosition;


	TOP_DOWN_SETUP_UV(topdownUv, worldPos);

#if _qc_USE_RAIN
	float waterLayer = 0.25 + input.fresnel * 0.5 * smoothstep(0.25, 0.4, input.water);
#endif

	float specular;
	float4 topDownAmbientSpec;


#if _REFLECTIVITY_METAL 

	// REFLECTION
	specular = GetSpecular_Metal(input.smoothsness, input.fresnel);

	//1 _ Top Down Proximity
	topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, worldPos, rawNormal, specular);
	input.ao *= topDownAmbientSpec.a;
	reflectionColor += topDownAmbientSpec.rgb;

	//2 _ Traced Variants
	#if _PER_PIXEL_REFLECTIONS_INVERTEX
		reflectionColor += input.traced.rgb;
		ReflectionByAo(reflectionColor, input.ao, input.fresnel);
	#elif _PER_PIXEL_REFLECTIONS_OFF && !_qc_USE_RAIN
		reflectionColor += Savage_GetVolumeBake(worldPos, reflectedRay, rawNormal, volumeSamplePosition);
		ReflectionByAo(reflectionColor, input.ao, input.fresnel);
	#else

		float4 refAndAo = GetRayTrace_AndAo(GetVolumeSamplingPosition(worldPos, rawNormal), reflectedRay, specular);
		input.ao *= refAndAo.a;

		reflectionColor.rgb += GetPointLight_Specualr(worldPos, reflectedRay, specular);
		ReflectionByAo(reflectionColor, input.ao, input.fresnel);

		reflectionColor += refAndAo.rgb;
	#endif

	
	//reflectionColor *= input.ao;

	#if !_qc_IGNORE_SKY
		reflectionColor += GetDirectionalSpecular(normal, viewDir, specular) * lightColor;
	#endif
	

	#if _qc_USE_RAIN
		return lerp(input.metalColor.rgb * reflectionColor, reflectionColor, waterLayer);
	#endif


	return input.metalColor.rgb * reflectionColor;
#endif
	
	// ********************* Has Diffuse
	float3 bake;
	
	bake = Savage_GetVolumeBake(worldPos, normal.xyz, rawNormal, volumeSamplePosition);
	float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, worldPos);
	input.ao *= topDownAmbient.a;
	bake += topDownAmbient.rgb;

#if _REFLECTIVITY_OFF && !_qc_USE_RAIN
		float3 pointLight = GetPointLight(volumeSamplePosition, normal, input.ao);
		float3 diffuseColor = pointLight + lightColor + bake * input.ao;
		return input.tex.rgb * diffuseColor;
#elif _REFLECTIVITY_LAYER || _REFLECTIVITY_PAINTED_METAL
		float3 pointLight = GetPointLight(volumeSamplePosition, normal, input.ao, viewDir, input.smoothsness, reflectionColor);
		float3 diffuseColor = pointLight + lightColor + bake * input.ao;

		// ********************* Reflection
		
		specular = GetSpecular_Layer(input.smoothsness, input.fresnel);

		#if _REFLECTIVITY_PAINTED_METAL
			specular = lerp(specular, GetSpecular_Metal(input.smoothsness, input.fresnel), input.metal);
		#endif

		topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, worldPos, rawNormal, specular);

		input.ao *= topDownAmbientSpec.a;
		reflectionColor += topDownAmbientSpec.rgb;

		#if _PER_PIXEL_REFLECTIONS_INVERTEX
			reflectionColor += input.traced.rgb;
		#elif _PER_PIXEL_REFLECTIONS_OFF
			reflectionColor += Savage_GetVolumeBake(worldPos, reflectedRay, rawNormal, volumeSamplePosition);
		#else
			float4 refAndAo = GetRayTrace_AndAo(GetVolumeSamplingPosition(worldPos, rawNormal), reflectedRay, specular);
			reflectionColor += refAndAo.rgb;
			input.ao *= refAndAo.a;
		#endif

		ReflectionByAo(reflectionColor, input.ao, input.fresnel);
		//reflectionColor *= input.ao;
		reflectionColor += GetDirectionalSpecular(normal, viewDir, specular) * lightColor;

		float3 col = lerp(input.tex.rgb * diffuseColor, reflectionColor, input.fresnel * input.reflectivity);

		#if _REFLECTIVITY_PAINTED_METAL
			float3 byMetal = input.metalColor.rgb * reflectionColor;
			col = lerp(col, byMetal, input.metal);
		#endif


		#if _MICRODETAIL_LAYER || _MICRODETAIL_ON
			col = lerp(col,diffuseColor * input.microdetail.rgb, input.microdetail.a);	
		#endif

		return col;

#elif _REFLECTIVITY_PLASTIC || _REFLECTIVITY_MIXED_METAL || _qc_USE_RAIN
					
		specular = GetSpecular_Plastic(input.smoothsness, input.fresnel * input.reflectivity);

		#if _REFLECTIVITY_MIXED_METAL
			//input.metal = step(0.5, input.metal);
			specular = lerp(specular, 0.85 + input.reflectivity * 0.15, input.metal);
		#endif

		#if _MICRODETAIL_ON
			//input.microdetail.a *= (1-input.fresnel );

			input.tex.rgb = lerp(input.tex.rgb, input.microdetail.rgb, input.microdetail.a);
			float changeProperties = 1 - (pow(1-input.microdetail.a, 3)); //smoothstep(0, 0.5, input.microdetail.a);
			specular = lerp(specular, 0, changeProperties); 
			input.reflectivity = lerp(input.reflectivity, 0, changeProperties);
		#endif

		float3 pointLight = GetPointLight(volumeSamplePosition, normal, input.ao, viewDir, specular, reflectionColor);
		float3 diffuseColor = pointLight + lightColor + bake * input.ao;
		float3 col = input.tex.rgb * diffuseColor;

		// ********************* Reflection

		topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, worldPos, rawNormal, specular);
		input.ao *= topDownAmbientSpec.a;
		reflectionColor += topDownAmbientSpec.rgb;
	

		#if !_qc_IGNORE_SKY
			reflectionColor += GetDirectionalSpecular(normal, viewDir, specular) * lightColor;
		#endif

		ReflectionByAo(reflectionColor, input.ao, input.fresnel);

		reflectionColor += GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular, input.traced, input.ao);



		float reflectivity = specular + (1-specular) * input.reflectivity * input.fresnel;

		//input.reflectivity * 0.5

		#if _REFLECTIVITY_MIXED_METAL
			reflectionColor *= lerp(1, input.metalColor.rgb, input.metal);
			reflectivity = lerp(reflectivity, 0.9, input.metal);
		#endif
				
		#if _qc_USE_RAIN
			float3 byWater = lerp(input.tex.rgb * diffuseColor, reflectionColor, waterLayer);
			MixInSpecular_Plastic(col, reflectionColor, reflectivity);
			col = lerp(col, byWater, smoothstep(0.25, 0.4, waterLayer));
		#else 
			MixInSpecular_Plastic(col, reflectionColor, reflectivity);
		#endif

		#if _MICRODETAIL_LAYER 
			col = lerp(col,diffuseColor * input.microdetail.rgb, input.microdetail.a);	
		#endif

		return col;

#else 

// Fallback reflectivity
float3 pointLight = GetPointLight(volumeSamplePosition, normal, input.ao);
float3 diffuseColor = pointLight + lightColor + bake * input.ao;
return input.tex.rgb * diffuseColor;

#endif

return 0;
}


float3 GetBeveledNormal_AndSeam(float4 seam, float4 edge,float3 viewDir, float3 junkNorm, float3 sharpNorm, float3 edge0, float3 edge1, float3 edge2, out float hideSeam)
	{
		float dott = saturate(dot(viewDir,sharpNorm)); 

		float3 fWid = fwidth(edge.rgb);
		//float3 fWidNorm = fwidth(junkNorm.rgb);

		float width = saturate(length(fWid) //* dott 
		* 4);
		edge = smoothstep(1 - width, 1, edge);
		seam = smoothstep(1 - width* dott, 1, seam);

		float junk = saturate(edge.x * edge.y + edge.y * edge.z + edge.z * edge.x);
		float border = saturate(edge.r + edge.g + edge.b- junk);

		border = pow(border,3);

		float3 edgeN = edge0 * edge.r + edge1 * edge.g + edge2 * edge.b;

		edgeN = lerp(edgeN, junkNorm, junk);

		hideSeam = smoothstep(0, 1, (seam.r + seam.g + seam.b + seam.a)* border);

		hideSeam *= border;

		return normalize(lerp(sharpNorm, edgeN, border));
	}

float GetTranslucentTracedShadow(float3 pos, float3 refractedRay, float depth)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	if (_qc_SunVisibility == 0)
		return 0;

	refractedRay *= depth;

	 return
						(SampleRayShadow(pos + refractedRay *  0.3)
						+ SampleRayShadow(pos + refractedRay * 0.6)
						+ SampleRayShadow(pos + refractedRay * 0.9)) * 0.333;
}

float3 WindShakeWorldPos(float3 worldPos, float topDownShadow)
{
	float outOfBounds;
	float sdfWorld = SampleSDF(worldPos, outOfBounds).a;
	//float useSdf = smoothstep(0, -0.05 * coef, sdfWorld.w);

	//float offGround = smoothstep(0.25,1, worldPos.y);

	//float offset = smoothstep(0.25, -0.25, sdfWorld.w);
	//worldPos.xyz += offset * sdfWorld.xyz * offGround;

	float distance = lerp(smoothstep(0,5,sdfWorld),1, outOfBounds);

	float3 gyrPos = worldPos * 0.2f;
	//gyrPos.y *= 0.1;
	gyrPos.y += _Time.x * 20;
	float gyr = abs(sdGyroid(gyrPos, 1));
	//float power = smoothstep(0,3, distance);

	float3 shake = float3(sin(gyrPos.x + _Time.z), gyr, sin(gyrPos.z + _Time.z));// *gyr;
				
	float len = dot(shake, shake);

	shake.y = gyr * 0.1;

	worldPos.xyz += shake * len * 0.02 * distance; // *(gyr - 0.5);
	return worldPos;
}


float ApplyWater(inout float water, float rain, inout float ao, float displacement, inout float4 madsMap, inout float3 tnormal, float3 worldPos, float up)
{
	float4 noise = GetRainNoise(worldPos,  displacement,  up,  rain);
	float flattenSurface = ApplyWater(water, rain,  ao, displacement,  madsMap, noise);

#if !_SIMPLIFY_SHADER

	float2 off = noise.rg - 0.5;
	off *= 0.05;

	#if _qc_USE_RAIN
		float droplet = smoothstep(0.4, 6, noise.g) * rain;
		off += float2(sin(droplet * 20), cos(droplet * 20.123)) * droplet * 20;
	#else
		float scale = 1.423;
		worldPos.y += _Time.y + flattenSurface;
		worldPos *= scale;
		float surfaceSide = dot (sin(worldPos), cos (worldPos.yzx)) * 0.005 * up ;
		off = float2(off.x + surfaceSide, off.y - surfaceSide);
	#endif

	tnormal = lerp(tnormal, float3(off.x, off.y, 1), flattenSurface);
#else

	tnormal = lerp(tnormal, float3(0,0,1), flattenSurface);
#endif

	return flattenSurface;
}