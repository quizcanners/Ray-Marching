#include "Assets/Ray-Marching/Shaders/Savage_Sampler.cginc"

	float4 SampleVolumetricLight(float3 pos, float dist)
			{
				float4 sampled = 0;

					#if !_qc_IGNORE_SKY
						float3 atten = DirLightRealtimeShadow(0, pos);
						sampled.rgb += atten * GetDirectional() * (4 - qc_KWS_FogAlpha*3) * 0.25;
					#endif

						float outOfBounds;
						float3 baked = SampleVolume(_RayMarchingVolume, pos, outOfBounds).rgb;
						
						float valid = (1 - outOfBounds);

						baked =lerp(GetAmbientLight(), baked, valid);

						float3 reflectedTopDown = 0;
						float ao = TopDownSample(pos, reflectedTopDown);
						baked += reflectedTopDown * 0.1; 
						baked *= ao;
						sampled.rgb += baked; 

				#if _qc_USE_RAIN


					float outsideVolume;
					float4 scene = SampleSDF(pos , outsideVolume);
					float nearSurface = saturate(1-scene.a - scene.y) * (1 - outsideVolume);
				
					float3 rainSamplePos = pos;
					rainSamplePos.y *= 0.25; // stretch

					float level = log10(dist);
					float nearLevel = floor(level) + 1;
					float nextLevel = nearLevel + 1;

					float time = _Time.w - nearSurface;

					float4 noise = Noise3D((rainSamplePos+ float3(0, time , 0)) * pow(0.1 , nearLevel) );
					float4 noiseNext = Noise3D((rainSamplePos  + float3(0, time , 0)  ) * pow(0.1 , nextLevel));

					float transition = level - nearLevel;

					noise = lerp(noise,noiseNext, transition);

					
					//sampled += baked * nearSurface  * 5;


					float showRain = _qc_RainVisibility;

					showRain = lerp(1, 1 + noise.y * (1 + level + nearSurface * 10), showRain);

					#if !_qc_IGNORE_SKY
						showRain *= atten; // In Shadow is likely to be under the roof
					#endif

					sampled.a = 1;
					sampled *= showRain;
					
				#endif

				return sampled;
			}



float4 TraceVolumetricLight(float3 rayStart, float3 rayDir, float rayLength, float jitterOffset)
{
	float3 offsetStart = rayStart;

	//jitterOffset = (jitterOffset + rayLength)%1;

	float currentStep = 0.1 + 0.1 * jitterOffset;
	float currenOffset = currentStep;

	qc_KWS_FogAlpha *= 1 - abs(rayDir.y) * 0.25;

	float currentWeight = 20; // + abs(rayDir.y) * 2000;
	float blendAlpha = 0;
	float remainingAlpha = 1;
	float4 sampeled = 0;
	float totalWeight =0;
	float multiplier = lerp(1.5, 1, qc_KWS_FogAlpha);
	float multiplierGrowth = lerp(0.01, 0.2, qc_KWS_FogAlpha);
	float3 currentPos;
	float4 result = 0;

	float divideByTotal = 1 - qc_KWS_FogAlpha * qc_KWS_FogAlpha;

	UNITY_LOOP
	while (currenOffset < rayLength)
	{
		totalWeight = currentWeight + currentStep;
		blendAlpha =  min(1,currentStep * qc_KWS_FogAlpha / (1 + totalWeight * divideByTotal)) * remainingAlpha; // Blend alpha should never be 1
			
		currentPos = offsetStart + rayDir * currenOffset;
		
		sampeled = SampleVolumetricLight(currentPos, currenOffset);

		currentStep *= multiplier;//* (0.5 + jitterOffset);
		multiplier+= multiplierGrowth;
		currenOffset+= currentStep;//* (0.5 + jitterOffset);
	

		result = lerp(result,  sampeled, blendAlpha );
		remainingAlpha -= blendAlpha;
		currentWeight = totalWeight; 


		//jitterOffset = (jitterOffset + 0.23456) % 1;
	}

	totalWeight = currentWeight + currentStep;
	blendAlpha =  min(1, currentStep * qc_KWS_FogAlpha/ (1 + totalWeight * divideByTotal)) * remainingAlpha; 

	currentPos = offsetStart + rayDir * rayLength; // - currentStep*0.25);
	sampeled = SampleVolumetricLight(currentPos, currenOffset);

	//min(1, currentStep * qc_KWS_FogAlpha)  * remainingAlpha ;
	float finalChunk = (currentStep - (currenOffset - rayLength)) / currentStep;
	result = lerp(result, sampeled, blendAlpha * finalChunk);
	remainingAlpha-= blendAlpha;

	float nearFade = 1-smoothstep(0, 20, rayLength);

	nearFade= pow(nearFade,3);

	nearFade = 1-nearFade;

	result.a = (1-divideByTotal) * nearFade *
	(1 - 1/(1+rayLength*lerp(0.1, 1, qc_KWS_FogAlpha)))
		/*#if _qc_USE_RAIN
			* result.a
		#endif*/
	;

	return  result;
}