#ifndef QC_RTX_POST_BAKE
#define QC_RTX_POST_BAKE

#include "PrimitivesScene_Sampler.cginc"
#include "PrimitivesScene_Intersect.cginc"
//#include "PrimitivesScene_SDF.cginc"


#define ARRAY_POINT_LIGHT_COUNT 16
uniform float4 PostRtx_PointLight_Pos[ARRAY_POINT_LIGHT_COUNT];
uniform float4 PostRtx_PointLight_Color[ARRAY_POINT_LIGHT_COUNT];
uniform int PostRtx_PointLight_Count;


#define ARRAY_PROJECTOR_LIGHT_COUNT 16
uniform float4 PostRtx_ProjectorLight_Pos[ARRAY_PROJECTOR_LIGHT_COUNT];
uniform float4 PostRtx_ProjectorLight_DirAngle[ARRAY_PROJECTOR_LIGHT_COUNT];
uniform float4 PostRtx_ProjectorLight_Color[ARRAY_PROJECTOR_LIGHT_COUNT];
uniform int PostRtx_ProjectorLight_Count;


#define ARRAY_SUN_PORTAL_COUNT 16
uniform float4 PostRtx_SunPortal_Pos[ARRAY_SUN_PORTAL_COUNT];
uniform float4 PostRtx_SunPortal_Color[ARRAY_SUN_PORTAL_COUNT];
uniform float4 PostRtx_SunPortal_Size[ARRAY_SUN_PORTAL_COUNT];
uniform int PostRtx_SunPortal_Count;


#define ARRAY_AMBIENT_SPHERE_COUNT 16
uniform float4 PostRtx_AmbientSphere_Pos[ARRAY_AMBIENT_SPHERE_COUNT];
uniform float4 PostRtx_AmbientSphere_Color[ARRAY_AMBIENT_SPHERE_COUNT];
uniform int PostRtx_AmbientSphere_Count;

void SamplePostEffects(float3 pos, out float3 col, out float ao, float4 seed) {

	col=0;
	ao=1;

	float VOL_SIZE = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;
	float oobSDF;
	float4 normalTmp = SampleSDF(pos , oobSDF);
	float farEnough = smoothstep(VOL_SIZE * 0.5, VOL_SIZE, normalTmp.w);

	if (farEnough < 0.1)
		return;

	
	for (int i =0; i<PostRtx_PointLight_Count; i++)	{
		float3 lightPos = PostRtx_PointLight_Pos[i];	
		if (Raycast(pos, lightPos))
			continue;
		float3 lightCol = PostRtx_PointLight_Color[i];

		col += farEnough * lightCol / (1 + pow(length(pos-lightPos),2));
	}

	for (int i=0; i<PostRtx_ProjectorLight_Count; i++) {
		float3 projPos = PostRtx_ProjectorLight_Pos[i];
		float3 vec = pos - projPos;
		float3 dir = normalize(vec);
		float4 dirAng = PostRtx_ProjectorLight_DirAngle[i];
		float angle = dot(dirAng.xyz, dir);
		float minAngle = dirAng.w;
		if (angle < minAngle)
			continue;

		if (Raycast(pos, projPos))
			continue;

		//float strength = 1-angle / maxAngle;
		float strength = (angle - minAngle)/(1.1-minAngle);

		float3 lightCol = PostRtx_ProjectorLight_Color[i];
		col += lightCol * strength / (1 + pow(length(vec),2));
	}

	float cellSize = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 2;

	
	#if !_qc_IGNORE_SKY
		float3 rd = qc_SunBackDirection.xyz;
		float3 ro = pos;
		float3 sunCol = GetDirectional();

		float3 m = sign(rd) / max(abs(rd), 0.00001);

		for (int i=0; i<PostRtx_SunPortal_Count; i++){
			float3 portPos = PostRtx_SunPortal_Pos[i];
			float4 window = PostRtx_SunPortal_Size[i];

			if (length(max(0,abs(portPos - pos) - window - cellSize)) == 0)
				continue;

			if (!IsHitBox(ro - portPos.xyz, rd, window.xyz, m))
				continue;

			

			/*
			float alpha = 1;

			float3 relativePos = ro - portPos.xyz;

			alpha += IsHitBox(relativePos + float3(cellSize,0,0), rd, window.xyz, m) ? 1 : 0;
			alpha += IsHitBox(relativePos + float3(-cellSize,0,0), rd, window.xyz, m) ? 1 : 0;

			alpha += IsHitBox(relativePos + float3(0, cellSize,0), rd, window.xyz, m) ? 1 : 0;
			alpha += IsHitBox(relativePos + float3(0, -cellSize,0), rd, window.xyz, m) ? 1 : 0;

			alpha += IsHitBox(relativePos + float3(0, 0, cellSize), rd, window.xyz, m) ? 1 : 0;
			alpha += IsHitBox(relativePos + float3(0, 0, -cellSize), rd, window.xyz, m) ? 1 : 0;

			if (alpha < 0.1)
				continue;*/

			if (Raycast(pos, portPos))
				continue;

			//alpha /= 6;

			col += sunCol;// * alpha;
		}
	#endif
	

	for (int i=0; i<PostRtx_AmbientSphere_Count; i++) {
		float3 lightPos = PostRtx_AmbientSphere_Pos[i];	
		float3 lightCol = PostRtx_AmbientSphere_Color[i];
		float alpha = 1/ (1 + pow(length(pos-lightPos),2));
		col += lightCol * alpha;
		ao *= 1-alpha;
	}
}

void SamplePostEffects(float3 pos, float3 dir, out float3 col, out float ao, float4 seed)
{
	col=0;
	ao=1;

	for (int i =0; i<PostRtx_PointLight_Count; i++)
	{
		float3 lightPos = PostRtx_PointLight_Pos[i];	
		float3 vec = lightPos-pos;

		float distance = length(vec);

		float2 MIN_MAX = float2(0.00001, distance);

		float3 toLightVec = normalize(vec);

		float sameDirection = smoothstep(0, 0.1, dot(toLightVec, dir));

		if (sameDirection <0.01)
			continue;

		if (Raycast(pos, lightPos))
			continue;
		//if (Raycast(pos, normalize(vec), MIN_MAX))
			//continue;

		float3 lightCol = PostRtx_PointLight_Color[i];

		col += lightCol * sameDirection / (1 + pow(length(pos-lightPos),2));
	}

	for (int i=0; i<PostRtx_ProjectorLight_Count; i++) {
		float3 projPos = PostRtx_ProjectorLight_Pos[i];
		float3 fromLightVec = pos - projPos;
		float3 toLightDir = normalize(fromLightVec);
		float4 dirAng = PostRtx_ProjectorLight_DirAngle[i];
		float angle = dot(dirAng.xyz, toLightDir);
		float minAngle = dirAng.w;
		if (angle < minAngle)
			continue;

		float sameDirection = smoothstep(0, 0.1, dot(-toLightDir, dir));

		if (sameDirection <0.01)
			continue;

		if (Raycast(pos, projPos))
			continue;

		float strength = (angle - minAngle)/(1.1-minAngle); // 1-(angle / maxAngle);

		float3 lightCol = PostRtx_ProjectorLight_Color[i];
		col += lightCol * strength * sameDirection / (1 + pow(length(fromLightVec),2));
	}

	float cellSize = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 2;

	//#if !_qc_IGNORE_SKY
		float3 rd = qc_SunBackDirection.xyz;
		float3 ro = pos;
		float3 sunCol = GetDirectional();
		//qc_SunBackDirection

		float rightDirection = smoothstep(0, 0.1, dot(qc_SunBackDirection.xyz, dir));

		if (rightDirection <= 0)
			return;

		float3 m = sign(rd) / max(abs(rd), 0.00001);

		for (int i=0; i<PostRtx_SunPortal_Count; i++){
			float3 portPos = PostRtx_SunPortal_Pos[i];
			float4 window = PostRtx_SunPortal_Size[i];

			if (length(max(0,abs(portPos - pos) - window - cellSize)) == 0)
				continue;

			if (!IsHitBox(ro - portPos.xyz, rd, window.xyz, m))
				continue;

			

				/*

					float alpha = 1;
			float alpha = 0;

			float3 relativePos = ro - portPos.xyz;

			alpha += IsHitBox(relativePos + float3(cellSize,0,0), rd, window.xyz, m) ? 1 : 0;
			alpha += IsHitBox(relativePos + float3(-cellSize,0,0), rd, window.xyz, m) ? 1 : 0;

			alpha += IsHitBox(relativePos + float3(0, cellSize,0), rd, window.xyz, m) ? 1 : 0;
			alpha += IsHitBox(relativePos + float3(0, -cellSize,0), rd, window.xyz, m) ? 1 : 0;

			alpha += IsHitBox(relativePos + float3(0, 0, cellSize), rd, window.xyz, m) ? 1 : 0;
			alpha += IsHitBox(relativePos + float3(0, 0, -cellSize), rd, window.xyz, m) ? 1 : 0;

			if (alpha < 0.1)
				continue;
				
				alpha /= 6;				
				*/

			if (Raycast(pos, portPos))
				continue;

			

			col += sunCol * rightDirection;
		}
	//#endif

}

#endif
