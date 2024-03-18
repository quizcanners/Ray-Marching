#include "Assets/Qc_Rendering/Shaders/Savage_Sampler.cginc"

// Without Tracing part

uniform float QC_USE_HBAO;
uniform float Qc_SSAO_Intensity;
uniform float QC_AO_DECALS;
uniform sampler2D qc_DecalAoTex;

float4 _qc_ColorCorrection_Color;
float4 _qc_ColorCorrection_Params;



UNITY_DECLARE_SCREENSPACE_TEXTURE(_HBAOTex);

inline float SampleSS_Illumination(float2 screenUv, out float4 illumination)
  {
	float ao = 1;
	
	if (QC_USE_HBAO > 0)
	{
		float sampl = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_HBAOTex, screenUv).a; // * QC_USE_HBAO;
		ao *= pow(sampl, 1+Qc_SSAO_Intensity);
	}

	if (QC_AO_DECALS>0)
	{
		float4 dec = tex2D(qc_DecalAoTex, screenUv);
		illumination = dec;
		ao *= saturate(1-dec.g);
	}
	else 
	{
		illumination = 0;
	}

	return ao;
 }

inline float SampleSSAO(float2 screenUv)
 {
	float4 illumination;
	return SampleSS_Illumination(screenUv, illumination);
 }

float3 Savage_GetVolumeBake(float3 worldPos, float3 normal, float3 rawNormal, out float3 safePosition)
{
	safePosition = GetVolumeSamplingPosition(worldPos, rawNormal);//worldPos + rawNormal.xyz * _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 0.5;

#if _SIMPLIFY_SHADER
	return GetAvarageAmbient(normal);
#endif

	return SampleVolume_CubeMap(safePosition, normal).rgb;
}

float3 GetBeveledNormal_AndSeam(float4 seam, float4 edge,float3 viewDir, float3 junkNorm, float3 sharpNorm, float3 edge0, float3 edge1, float3 edge2, out float hideSeam)
{
	float dott = saturate(dot(viewDir,sharpNorm)); 

	float3 fWid = fwidth(edge.rgb);
	//float3 fWidNorm = fwidth(junkNorm.rgb);

	float width = saturate(length(fWid) * 4);
	edge = smoothstep(1 - width, 1, edge);
	seam = sharpstep(1 - width* dott, 1, seam);

	float junk = saturate(edge.x * edge.y + edge.y * edge.z + edge.z * edge.x);
	float border = saturate(edge.r + edge.g + edge.b- junk);

	border = pow(border,3);

	float3 edgeN = edge0 * edge.r + edge1 * edge.g + edge2 * edge.b;

	edgeN = lerp(edgeN, junkNorm, junk);

	hideSeam = sharpstep(0, 1, (seam.r + seam.g + seam.b + seam.a)* border);

	hideSeam *= border;

	return normalize(lerp(sharpNorm, edgeN, border));
}

inline float SampleContactAO_OffsetWorld(inout float3 pos, float3 normal)
{
	#if !qc_NO_VOLUME

		float outsideVolume;
		float4 scene = SampleSDF(pos , outsideVolume);

		float coef = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 2;

		pos += normal * coef;

		float contactShadow = sharpstep( -2 * coef, 2 * coef, (scene.a + dot(normal, scene.xyz) * 2 * coef));

		//float sameNormal = smoothstep(-1, 1, dot(normal, scene.xyz));
		return lerp(contactShadow * 0.75 + 0.25, 1, outsideVolume);
	#else 
		return 1;
	#endif
}


void ColorCorrect(inout float3 col)
{
	return;
	/*
	// X-fade shadow
	float shadow = _qc_ColorCorrection_Params.x;
	// Y-fade brightness
	float fadeBrightness = _qc_ColorCorrection_Params.y;
	// Z-Saturate
	float deSaturation = _qc_ColorCorrection_Params.z;
	// W-Colorize
	float colorize = _qc_ColorCorrection_Params.w;
	
	//float3 nrmCol = normalize(col.rgb);

	//float3 offset = col - nrmCol;

	float brightness = (col.r + col.g + col.b) + 0.001; //offset.x + offset.y + offset.z;

	float3 nromCol = col / brightness;

	brightness = sharpstep(-shadow, 1, brightness);

	brightness = lerp(brightness, 0.75, fadeBrightness);

	nromCol = lerp(nromCol, float3(0.33, 0.33, 0.33), deSaturation);

	nromCol.rgb = lerp(nromCol.rgb, _qc_ColorCorrection_Color.rgb, colorize);

	col = nromCol * brightness;*/
}

void smoothedPixelsSampling(inout float2 texcoord, float4 texelsSize) {

	float2 perfTex = (floor(texcoord * texelsSize.zw) + 0.5) * texelsSize.xy;
	float2 off = (texcoord - perfTex);
	float wigth = length(fwidth(texcoord));
	float size = 0.002 / wigth;
	off = off * saturate((abs(off) * texelsSize.zw) * size * 2 - (size - 1));
	texcoord = perfTex + off;
	/*
	float2 perfTex = (floor(texcoord*texelsSize.z) + 0.5) * texelsSize.x;
	float2 off = (texcoord - perfTex);
	off = off *saturate((abs(off) * texelsSize.z) * 40 - 19);
	texcoord = perfTex + off;*/
}





