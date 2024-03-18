#ifndef QC_LAYER_GOG
#define QC_LAYER_GOG

//#include "Assets/Qc_Rendering/Shaders/Savage_Sampler.cginc"

uniform sampler2D qc_FogLayers;

uniform float qc_LayeredFog_Alpha;
uniform float qc_LayeredFog_Distance;


// Probably incorrect
void GetFogLayerIndexFromDistance(float distance, out float index, out float fraction)
{
	float initialStep = 0.01;
    float scaling = 2;

	//n= log ((1+sn(r-1))/G1) to base r
	float rawIndex = log2((1 + distance * (scaling-1))/initialStep);
	///float rawIndex = log2((distance + initialStep) /initialStep);
	index = floor(rawIndex);
	fraction = rawIndex - index;
}




float4 SampleLayeredFog(float distance, float2 uv)
{
	#if !qc_LAYARED_FOG
		return 0;
	#endif

	distance = min(distance, qc_LayeredFog_Distance);

	float index;
    float fraction;
    GetFogLayerIndexFromDistance(distance, index, fraction);
	
	float2 internalUv = uv / 4;

	float y = floor(index/4);
    float x = index - y*4;
	float4 last = tex2Dlod(qc_FogLayers, float4(float2(x,y)*0.25 + internalUv, 0, 0));

	index--;
	y = floor(index/4);
    x = index - y*4;
	float4 previous = tex2Dlod(qc_FogLayers, float4(float2(x,y)*0.25 + internalUv, 0, 0));

	float4 result = lerp(previous, last, fraction);

	return result;
}



inline void ApplyLayeredFog_Transparent(inout float4 col, float2 uv, float distance)
{
	#if qc_LAYARED_FOG
		float4 fogColor = SampleLayeredFog(distance, uv);
		col.rgb = lerp(col.rgb, fogColor.rgb, fogColor.a);
	#endif
}

inline void ApplyLayeredFog_Transparent(inout float4 col, float2 uv, float3 pos)
{
	#if qc_LAYARED_FOG
		float distance = length(_WorldSpaceCameraPos - pos);
		float4 fogColor = SampleLayeredFog(distance, uv);
		col.rgb = lerp(col.rgb, fogColor.rgb, fogColor.a);
	
	#endif
}

inline void ApplyLayeredFog_Transparent_Premultiplied(inout float4 col, float2 uv, float3 pos)
{
	#if qc_LAYARED_FOG
		float distance = length(_WorldSpaceCameraPos - pos);
		float4 fogColor = SampleLayeredFog(distance, uv);
		col.rgb = lerp(col.rgb, fogColor.rgb*col.a, fogColor.a);
	
	#endif
}

#endif