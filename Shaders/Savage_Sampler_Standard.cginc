#include "AutoLight.cginc"
#include "Savage_Sampler_Tracing.cginc"
#include "Savage_Sampler_Standard_NoTracingPart.cginc"

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
	reflection *= ao * ao; // lerp(ao, 1, fresnel);//pow(ao, 1 + fresnel*3);
}

float3 GetReflection_ByMaterialType(MaterialParameters input, float3 normal, float3 rawNormal, float3 viewDir,  float3 worldPos) 
{
	float3 lightColor = Savage_GetDirectional_Opaque(input.shadow, input.ao, normal, worldPos);

	float3 reflectedRay = reflect(-viewDir, normal);

	//ModifySpecularByAO(input.smoothsness, input.ao);


	float normError = sharpstep(0.2, 0.01, dot(reflectedRay, rawNormal));
	float3 reflFix = reflect(-viewDir,rawNormal);
	float3 perp = normalize(lerp(-viewDir,reflFix, 0.55));
	reflectedRay = lerp(reflectedRay, perp, normError);

	
	float diffuseAO = input.ao; //1-pow(1 - input.ao,3);

	float3 reflectionColor = 0;
	float3 volumeSamplePosition;


	TOP_DOWN_SETUP_UV(topdownUv, worldPos);

#if _qc_USE_RAIN
	float waterLayer = 0.25 + input.fresnel * 0.5 * sharpstep(0.25, 0.4, input.water);
#endif

	float specular;
	float4 topDownAmbientSpec;


#if _REFLECTIVITY_METAL 

	// REFLECTION
	specular = GetSpecular_Metal(input.smoothsness, input.fresnel);

	//1 _ Top Down Proximity
	topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, worldPos, rawNormal, specular);
	reflectionColor += topDownAmbientSpec.rgb * input.ao;
	input.ao *= topDownAmbientSpec.a;
	

	//2 _ Traced Variants
	#if _PER_PIXEL_REFLECTIONS_INVERTEX
		reflectionColor += input.traced.rgb;
	#elif _PER_PIXEL_REFLECTIONS_OFF && !_qc_USE_RAIN
		reflectionColor += Savage_GetVolumeBake(worldPos, reflectedRay, rawNormal, volumeSamplePosition);
	#else

		float4 refl =// GetBakedAndTracedReflection(GetVolumeSamplingPosition(worldPos, rawNormal), reflectedRay, specular); //
		GetRayTrace_AndAo(GetVolumeSamplingPosition(worldPos, rawNormal), reflectedRay, specular);
		input.ao *= refl.a;

		reflectionColor.rgb += GetPointLight_Specualr(worldPos, reflectedRay, specular);
		

		reflectionColor += refl.rgb; // * input.ao;
	#endif

	
	//reflectionColor *= input.ao;

	#if !_qc_IGNORE_SKY
		reflectionColor += GetDirectionalSpecular(normal, viewDir, specular) * lightColor;
	#endif
	

	#if _qc_USE_RAIN
		return lerp(input.metalColor.rgb * reflectionColor, reflectionColor, waterLayer);
	#endif

	ReflectionByAo(reflectionColor, input.ao, input.fresnel);

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
		float3 diffuseColor = pointLight + max(lightColor, bake * diffuseAO);
		return input.tex.rgb * diffuseColor;
#elif _REFLECTIVITY_LAYER || _REFLECTIVITY_PAINTED_METAL
		float3 pointLight = GetPointLight(volumeSamplePosition, normal, input.ao, viewDir, input.smoothsness, reflectionColor);
		float3 diffuseColor = pointLight + max(lightColor, bake * diffuseAO);

		// ********************* Reflection
		
		specular = GetSpecular_Layer(input.smoothsness, input.fresnel);

		#if _REFLECTIVITY_PAINTED_METAL
			specular = lerp(specular, GetSpecular_Metal(input.smoothsness, input.fresnel), input.metal);
		#endif

		topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, worldPos, rawNormal, specular);

		reflectionColor += topDownAmbientSpec.rgb * input.ao;
		input.ao *= topDownAmbientSpec.a;
		

		#if _PER_PIXEL_REFLECTIONS_INVERTEX
			reflectionColor += input.traced.rgb;
		#elif _PER_PIXEL_REFLECTIONS_OFF
			reflectionColor += Savage_GetVolumeBake(worldPos, reflectedRay, rawNormal, volumeSamplePosition) * input.ao;
		#else

			#if _REFLECTIVITY_PAINTED_METAL
				if (input.metal > 0.5)
				{
					float4 refAndAo = GetRayTrace_AndAo(GetVolumeSamplingPosition(worldPos, rawNormal), reflectedRay, specular);
					reflectionColor += refAndAo.rgb;
					input.ao *= refAndAo.a;
				} else 
			#endif
			{
				float3 refAndAo = GetBakedAndTracedReflection(GetVolumeSamplingPosition(worldPos, rawNormal), reflectedRay, specular);
				reflectionColor += refAndAo.rgb;
			}
		
		#endif

	
		//reflectionColor *= input.ao;
		reflectionColor += GetDirectionalSpecular(normal, viewDir, specular) * lightColor;

		ReflectionByAo(reflectionColor, input.ao, input.fresnel);

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
			float changeProperties = 1 - (pow(1-input.microdetail.a, 3)); //sharpstep(0, 0.5, input.microdetail.a);
			specular = lerp(specular, 0, changeProperties); 
			input.reflectivity = lerp(input.reflectivity, 0, changeProperties);
		#endif

		float3 pointLight = GetPointLight(volumeSamplePosition, normal, input.ao, viewDir, specular, reflectionColor);



		float3 diffuseColor = pointLight + max(lightColor, bake * diffuseAO);// * input.ao;
		float3 col = input.tex.rgb * diffuseColor;

		// ********************* Reflection

		topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, worldPos, rawNormal, specular);
		reflectionColor += topDownAmbientSpec.rgb * input.ao;
		input.ao *= topDownAmbientSpec.a;
	
	

		#if !_qc_IGNORE_SKY
			reflectionColor += GetDirectionalSpecular(normal, viewDir, specular) * lightColor;
		#endif



		//return GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular, input.traced, input.ao);

		// AO Doesn't contribute sufficiently'
		//reflectionColor += GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular, input.traced, input.ao);
		#if _PER_PIXEL_REFLECTIONS_INVERTEX
			reflectionColor += input.traced.rgb;
		#elif _PER_PIXEL_REFLECTIONS_OFF
			reflectionColor += Savage_GetVolumeBake(worldPos, reflectedRay, rawNormal, volumeSamplePosition) * input.ao;
		#else

			#if _REFLECTIVITY_MIXED_METAL
			if (input.metal > 0.5)
			{
				float4 refAndAo = GetRayTrace_AndAo(GetVolumeSamplingPosition(worldPos, rawNormal), reflectedRay, specular);
				reflectionColor += refAndAo.rgb;
				input.ao *= refAndAo.a;
			} else 
			#endif
			 {	
				float3 refAndAo = GetBakedAndTracedReflection(GetVolumeSamplingPosition(worldPos, rawNormal), reflectedRay, specular);
				reflectionColor += refAndAo.rgb;
			 }
		#endif

	//	reflectionColor *= input.ao;

		float reflectivity = specular + (1-specular) * input.reflectivity * input.fresnel;

		//input.reflectivity * 0.5

		#if _REFLECTIVITY_MIXED_METAL
			reflectionColor *= lerp(1, input.metalColor.rgb, input.metal);
			reflectivity = lerp(reflectivity, 0.9, input.metal);
		#endif
				
		ReflectionByAo(reflectionColor, input.ao, input.fresnel);

		#if _qc_USE_RAIN
			float3 byWater = lerp(input.tex.rgb * diffuseColor, reflectionColor, waterLayer);
			MixInSpecular_Plastic(col, reflectionColor, reflectivity);
			col = lerp(col, byWater, sharpstep(0.25, 0.4, waterLayer));
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
float3 diffuseColor = pointLight + max(lightColor, bake * diffuseAO);
return input.tex.rgb * diffuseColor;

#endif

return 0;
}

float ApplyWater(inout float water, float rain, inout float ao, float displacement, inout float4 madsMap, inout float3 tnormal, float3 worldPos, float up)
{
	float4 noise = GetRainNoise(worldPos,  displacement,  up,  rain);
	float flattenSurface = ApplyWater(water, rain,  ao, displacement,  madsMap, noise);

#if !_SIMPLIFY_SHADER

	float2 off = noise.rg - 0.5;
	off *= 0.05;

	#if _qc_USE_RAIN
		float droplet = sharpstep(0.4, 6, noise.g) * rain;
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

