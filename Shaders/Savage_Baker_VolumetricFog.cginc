#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_VolumetricFog.cginc"
#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Tracing.cginc"

#include "Assets/Qc_Rendering/Shaders/Savage_Shadowmap.cginc"

uniform float4 _Effect_Time;

Texture3D<float4> Qc_Zibra_Illumination;
SamplerState samplerQc_Zibra_Illumination;

float4 Qc_Zibra_ContainerPosition;
float4 Qc_Zibra_ContainerScale;
float4 Qc_Zibra_GridSize;

static const float myDitherPattern[8][8] =
{
	{
		0.012f, 0.753f, 0.200f, 0.937f, 0.059f, 0.800f, 0.243f, 0.984f
	},
	{
		0.506f, 0.259f, 0.690f, 0.443f, 0.553f, 0.306f, 0.737f, 0.490f
	},
	{
		0.137f, 0.875f, 0.075f, 0.812f, 0.184f, 0.922f, 0.122f, 0.859f
	},
	{
		0.627f, 0.384f, 0.569f, 0.322f, 0.675f, 0.427f, 0.612f, 0.369f
	},
	{
		0.043f, 0.784f, 0.227f, 0.969f, 0.027f, 0.769f, 0.212f, 0.953f
	},
	{
		0.537f, 0.290f, 0.722f, 0.475f, 0.522f, 0.275f, 0.706f, 0.459f
	},
	{
		0.169f, 0.906f, 0.106f, 0.843f, 0.153f, 0.890f, 0.090f, 0.827f
	},
	{
		0.659f, 0.412f, 0.600f, 0.353f, 0.643f, 0.400f, 0.584f, 0.337f
	},
};



float3 WorldToQzUVW(float3 p)
{
    return (p - (Qc_Zibra_ContainerPosition - Qc_Zibra_ContainerScale * 0.5)) / Qc_Zibra_ContainerScale + 0.5/Qc_Zibra_GridSize;
}

float4 SampleZibraSmoke(float3 pos)
{
    return Qc_Zibra_Illumination.SampleLevel(samplerQc_Zibra_Illumination, WorldToQzUVW(pos), 0);
}



float2 GetLayerUvs (float2 uv, out float index)
{
	float2 upscaledUv = uv * 4;
    float2 indexXY = floor(upscaledUv);
   
    index = indexXY.y * 4 + indexXY.x;

	return upscaledUv - indexXY;
}

float GetDither(float2 pixelIndex) 
{
	pixelIndex += float2(_Effect_Time.w*3, _Effect_Time.w * 7);

	pixelIndex %= 8;

	return myDitherPattern[pixelIndex.x][pixelIndex.y];
}

float GetStartOfGeometricSeries(float initialSize, float scaling, float index)
{
    return initialSize * (1-pow(scaling, index)) / (1-scaling);
}

void GetFogLayerSegment(float index, out float start, out float finish)
{
	 float initialStep = 0.01;
     float scaling = 2;

	 float precalculate = initialStep / (scaling-1);

	  start = precalculate * (pow(scaling, index)-1);
      finish = precalculate * (pow(scaling, index + 1)-1);
}

float3 GetPointLight_Fog(float3 position)
{
	if (_qc_PointLight_Color.a==0)
	{
		return 0;
	}

	float3 lightDir = _qc_PointLight_Position.xyz - position;

	float distance = length(lightDir);

	lightDir = normalize(lightDir);

	float2 MIN_MAX = float2(0.0001, distance);

	bool isHit = RaycastStaticPhisics(position, lightDir, MIN_MAX);

	if (isHit) 
		return 0;
	
	float distFade = (1+qc_LayeredFog_Alpha * 8)/(pow(distance, 2 + qc_LayeredFog_Alpha) + 1);
	//float distFadeSquare =  distFade * distFade;
	float3 col = _qc_PointLight_Color.rgb * distFade;

	return col;
}

float4 SampleVolumetricLight(float3 pos, float dist, float facingSun)
{
	float4 sampled = 0;

	#if !_qc_IGNORE_SKY
		float atten =  GetSunShadowsAttenuation(pos, dist);//DirLightRealtimeShadow(0, pos);

		sampled.rgb += atten * (0.5 + facingSun) * GetDirectional();// * (4 - qc_LayeredFog_Alpha*3) * 0.25;
	#endif

		float outOfBounds;
		float3 baked = SampleVolume(_RayMarchingVolume, pos, outOfBounds).rgb;
						
		float valid = (1 - outOfBounds);

		baked =lerp(GetAmbientLight(), baked, valid);

		float3 reflectedTopDown = 0;
		float ao = TopDownSample(pos, reflectedTopDown);
		baked += reflectedTopDown * 0.1; 
		baked *= ao;

		baked += GetPointLight_Fog(pos) * smoothstep(1, 6, dist);

		sampled.rgb += baked; 
		sampled.a = 1; // smoothstep(15, 0, pos.y);

	//	float4 smokeAndFire = SampleZibraSmoke(pos);//SampleDensityLinear(float3 pos);// SampleIlluminationDensityLinear(pos);
	//	sampled += smokeAndFire;
		

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

float4 TraceVolumetricSegment(float3 rayStart, float3 rayDir, float rayLength, float index, float toSkip, float segmentLength, float jitterOffset)
{

	float STEPS = 8;

	float stepSize = segmentLength / STEPS;


	float3 offsetStart = rayStart + rayDir * toSkip;

	
	float3 currentPos;
	float4 result = 0;
	float currenOffset = jitterOffset * stepSize;

	float stepsTaken = 0;

	float facingSun = 0.25 + 0.75 * pow(smoothstep(0,1, dot(rayDir, qc_SunBackDirection)), 5);

	UNITY_LOOP
	while (currenOffset < rayLength)
	{
		result += SampleVolumetricLight(offsetStart + rayDir * currenOffset, currenOffset, facingSun);; 
		currenOffset+= stepSize;
		stepsTaken+=1;
	}

	if (stepsTaken == 0)
	{
		result += SampleVolumetricLight(offsetStart + rayDir * rayLength, rayLength, facingSun);
		stepsTaken+=1;
	}


	result = result / stepsTaken; // finalChunk);
	result.a *= rayLength/segmentLength;

	return result;
}


// Legacy:

float4 TraceVolumetricLight(float3 rayStart, float3 rayDir, float rayLength, float jitterOffset)
{
	float3 offsetStart = rayStart;

	//jitterOffset = (jitterOffset + rayLength)%1;

	float currentStep = 0.1 + 0.1 * jitterOffset;
	float currenOffset = currentStep;

	float qc_KWS_FogAlpha = 1.5;

	//qc_KWS_FogAlpha *= 1 - abs(rayDir.y) * 0.25;

	float currentWeight = 20; // + abs(rayDir.y) * 2000;
	float blendAlpha = 0;
	float remainingAlpha = 1;
	float4 sampeled = 0;
	float totalWeight =0;
	float multiplier = 1.5; // lerp(1.5, 1, qc_KWS_FogAlpha);
	float multiplierGrowth = lerp(0.01, 0.2, qc_KWS_FogAlpha);
	float3 currentPos;
	float4 result = 0;

	float divideByTotal = 1 - qc_KWS_FogAlpha * qc_KWS_FogAlpha;

	float facingSun = 1;

	UNITY_LOOP
	while (currenOffset < rayLength)
	{
		totalWeight = currentWeight + currentStep;
		blendAlpha =  min(1,currentStep * qc_KWS_FogAlpha / (1 + totalWeight * divideByTotal)) * remainingAlpha; // Blend alpha should never be 1
			
		currentPos = offsetStart + rayDir * currenOffset;
		
		sampeled = SampleVolumetricLight(currentPos, currenOffset, facingSun);

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
	sampeled = SampleVolumetricLight(currentPos, currenOffset, facingSun);

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

