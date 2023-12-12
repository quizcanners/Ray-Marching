#ifndef QC_RTX_POST_BAKE
#define QC_RTX_POST_BAKE

#include "PrimitivesScene_Sampler.cginc"

#define ARRAY_POINT_LIGHT_COUNT 8

uniform float4 PostRtx_PointLight_Pos[ARRAY_POINT_LIGHT_COUNT];
uniform float4 PostRtx_PointLight_Color[ARRAY_POINT_LIGHT_COUNT];
uniform int PostRtx_PointLight_Count;


void SamplePostEffects(float3 pos, out float3 col, out float ao)
{
	col=0;
	ao=1;

	for (int i =0; i<PostRtx_PointLight_Count; i++)
	{
		float3 lightPos = PostRtx_PointLight_Pos[i];	
		
		if (Raycast(pos, lightPos))
			continue;

		float3 lightCol = PostRtx_PointLight_Color[i];

		col += lightCol / (1 + pow(length(pos-lightPos),2));
	}
}

void SamplePostEffects(float3 pos, float3 dir, out float3 col, out float ao)
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

		if (Raycast(pos, normalize(vec), MIN_MAX))
			continue;

		float3 lightCol = PostRtx_PointLight_Color[i];

		col += lightCol * sameDirection / (1 + pow(length(pos-lightPos),2));
	}
}

#endif
