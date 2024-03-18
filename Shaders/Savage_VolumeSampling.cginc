#ifndef QC_VOL_SAMP
#define QC_VOL_SAMP

uniform float qc_VolumeAlpha;
uniform sampler2D Qc_SDF_Volume;
uniform float Qc_SDF_Visibility;

uniform sampler2D _RayMarchingVolume;
uniform float4 _RayMarchingVolumeVOLUME_POSITION_N_SIZE;
uniform float4 _RayMarchingVolumeVOLUME_H_SLICES;
uniform float4 _RayMarchingVolumeVOLUME_POSITION_OFFSET;

uniform float4x4 qc_RtxVolumeWorldToLocal;
uniform float4x4 qc_RtxVolumeLocalToWorld;
uniform float qc_USE_DYNAMIC_RTX_VOLUME;


float3 volumeUVtoWorld(float2 uv, float4 VOLUME_POSITION_N_SIZE, float4 VOLUME_H_SLICES) 
{

	// H Slices:
	//hSlices, w * 0.5f, 1f / w, 1f / hSlices

	float hy = floor(uv.y*VOLUME_H_SLICES.x);
	float hx = floor(uv.x*VOLUME_H_SLICES.x);

	float2 xz = uv * VOLUME_H_SLICES.x;

	xz.x -= hx;
	xz.y -= hy;

	xz =  (xz*2.0 - 1.0) *VOLUME_H_SLICES.y;

	//xz *= VOLUME_H_SLICES.y*2;
	//xz -= VOLUME_H_SLICES.y;

	float h = hy * VOLUME_H_SLICES.x + hx;

	float3 bsPos = float3(xz.x, h, xz.y) * VOLUME_POSITION_N_SIZE.w;

	float3 worldPos = VOLUME_POSITION_N_SIZE.xyz + bsPos;

	return worldPos;
}

float3 volumeUVtoWorld(float2 uv) 
{
	if (qc_USE_DYNAMIC_RTX_VOLUME > 0)
	{
		float4 zeroPos = float4(0,0,0, _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w);
		float3 localPos = volumeUVtoWorld(uv, zeroPos, _RayMarchingVolumeVOLUME_H_SLICES);

		return mul(qc_RtxVolumeLocalToWorld, float4(localPos,1)).xyz;
	}

	return volumeUVtoWorld(uv, _RayMarchingVolumeVOLUME_POSITION_N_SIZE, _RayMarchingVolumeVOLUME_H_SLICES);
}


float GetAlphaToHideForUvBorders(float2 uv) 
{
	float2 offUv = uv - 0.5;
	offUv = pow(offUv,4);
	float len = offUv.x + offUv.y;
	return smoothstep(0.0625, 0.04, len);
}

float4 WorldPosToVolumeUV(float3 worldPos, float4 VOLUME_POSITION_N_SIZE, float4 VOLUME_H_SLICES, out float upperFraction, out float outOfBounds)
{
	float4 volumeUvs;

	float size = VOLUME_POSITION_N_SIZE.w;

	float3 bsPos; 
	
	if (qc_USE_DYNAMIC_RTX_VOLUME > 0.5)
	{
		float3 localPos = mul(qc_RtxVolumeWorldToLocal, float4(worldPos,1)).xyz;
		bsPos = localPos / size;

		//bsPos = (worldPos.xyz - VOLUME_POSITION_N_SIZE.xyz) / size;
	} 
	else 
	{
		bsPos = (worldPos.xyz - VOLUME_POSITION_N_SIZE.xyz) / size;
	}

	float2 posToUvUnclamped = (bsPos.xz + VOLUME_H_SLICES.y) * VOLUME_H_SLICES.z;

	bsPos.xz = saturate(posToUvUnclamped);

	float maxHeight = VOLUME_H_SLICES.x * VOLUME_H_SLICES.x - 1;

	float h = clamp(bsPos.y, 0, maxHeight);

	float hIn = smoothstep(25, 0, -bsPos.y) * smoothstep(0, 10, maxHeight - bsPos.y);

	outOfBounds = 1 - GetAlphaToHideForUvBorders(posToUvUnclamped) * hIn;

	bsPos.xz *= VOLUME_H_SLICES.w;

	float sectorY = floor(h * VOLUME_H_SLICES.w);
	float sectorX = floor(h - sectorY * VOLUME_H_SLICES.x);
	float2 sectorUnclamped = float2(sectorX, sectorY) * VOLUME_H_SLICES.w;
	volumeUvs.xy = float4(saturate(sectorUnclamped) + bsPos.xz, 0, 0);

	h += 1;

	sectorY = floor(h * VOLUME_H_SLICES.w);
	sectorX = floor(h - sectorY * VOLUME_H_SLICES.x);
	sectorUnclamped = float2(sectorX, sectorY) * VOLUME_H_SLICES.w;

	volumeUvs.zw = saturate(sectorUnclamped) + bsPos.xz;

	upperFraction = frac(h);

	return volumeUvs;
}

float4 SampleVolume_Internal(sampler2D volume, float4 uvs, float upperFraction)
{
	float4 bake = tex2Dlod(volume, float4(uvs.xy, 0, 0));
	float4 bakeUp = tex2Dlod(volume, float4(uvs.zw, 0, 0));
	return lerp(bake, bakeUp, upperFraction);
}

float4 SampleVolume(sampler2D volume, float3 worldPos, float4 VOLUME_POSITION_N_SIZE, float4 VOLUME_H_SLICES, out float outOfBounds)
{
	float upperFraction;
	float4 uvs = WorldPosToVolumeUV(worldPos, VOLUME_POSITION_N_SIZE, VOLUME_H_SLICES, upperFraction, outOfBounds);
	return SampleVolume_Internal(volume, uvs, upperFraction);
}

float4 SampleSDF(float3 pos, out float outOfBounds)
{
	if (Qc_SDF_Visibility == 0)
	{
		outOfBounds = 1;
		return 0; //float4(0,1,0,999);
	}

	float4 bake = SampleVolume(Qc_SDF_Volume, pos
		, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
		, _RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);

//	bake = lerp(bake, float4(0,1,0,999), outOfBounds);

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

#endif