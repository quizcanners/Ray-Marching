#include "Assets/The-Fire-Below/Common/Shaders/quizcanners_cg.cginc"

uniform float qc_VolumeAlpha;
sampler2D Qc_SDF_Volume;
uniform float Qc_SDF_Visibility;
uniform float4 _qc_AmbientColor;

uniform sampler2D _RayMarchingVolume;

uniform float4 _RayMarchingVolumeVOLUME_POSITION_N_SIZE;
uniform float4 _RayMarchingVolumeVOLUME_H_SLICES;
uniform float4 _RayMarchingVolumeVOLUME_POSITION_OFFSET;


inline float3 GetAmbientLight()
{
	return _qc_AmbientColor.rgb;
}

float4 SampleSDF(float3 pos, out float outOfBounds)
{
	if (Qc_SDF_Visibility == 0)
	{
		outOfBounds = 1;
		return 0;
	}

	float4 bake = SampleVolume(Qc_SDF_Volume, pos
		, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
		, _RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);

	return bake;
}

float4 SampleVolume(float3 pos, out float outOfBounds)
{
	#if !qc_NO_VOLUME
		float4 bake = SampleVolume(_RayMarchingVolume, pos
			, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
			, _RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);

		return bake;
	#endif

	outOfBounds = 1;
	return 0;
	
}

float4 SampleVolume(sampler2D tex, float3 pos, out float outOfBounds)
{
	float4 bake = SampleVolume(tex, pos
		, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
		, _RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);

	return bake;
}