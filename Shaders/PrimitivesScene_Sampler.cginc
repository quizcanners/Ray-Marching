#include "Assets/Ray-Marching/Shaders/PrimitivesScene.cginc"

float4 _RayTracing_TopDownBuffer_Position;
sampler2D _RayTracing_TopDownBuffer;

sampler2D _qc_CloudShadows_Mask;
float _qc_Rtx_CloudShadowsVisibility;

float4 _qc_ColorCorrection_Color;
float4 _qc_ColorCorrection_Params;

inline void ColorCorrect(inout float3 col)
{
	return;
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

	col = nromCol * brightness;

	

	//col.rgb = lerp(col.rgb, brightness, saturation);
	
	//col.rgb += _qc_ColorCorrection_Params.x * nrmCol * smoothstep(0, _qc_ColorCorrection_Params.x, brightness); // *smoothstep(_qc_ColorCorrection_Params.x, -0.001, col.rgb);

	//col.rgb += _qc_ColorCorrection_Color.rgb * shadow * (brightness + 0.1) * smoothstep(shadow, -0.001, brightness);

	//

	//col.rgb = nrmCol * brightness;

	//col *= _qc_ColorCorrection_Color;
}


inline float SampleSkyShadow(float3 pos)
{
	//#if _qc_CLOUD_SHADOWS
		
		return smoothstep(0, _qc_Rtx_CloudShadowsVisibility, tex2Dlod(_qc_CloudShadows_Mask, float4(pos.xz * 0.0002 + _Time.x*0.2,0,0)).r);

	//#else

	//	return 1;

//	#endif
}


inline void ApplyBottomFog(inout float3 col, float3 worldPos, float viewDirY)
{
	float bottomFog = smoothstep(-0.35, -0.02, viewDirY);
	float dist01 =  smoothstep(1,0,(_ProjectionParams.z - length(worldPos - _WorldSpaceCameraPos.xyz)) * _ProjectionParams.w) ;

	col.rgb = lerp(col.rgb, lerp(_RayMarchSkyColor.rgb , unity_FogColor.rgb, bottomFog ), dist01);

	col.rgb = lerp(col.rgb, unity_FogColor.rgb, smoothstep(0, -300, worldPos.y) );

}

inline float3 GetAvarageAmbient(float3 normal)
{
	float4 ambFog = unity_FogColor * 0.2;

	float isUp = smoothstep(0, 1, normal.y);
	float isVert = abs(normal.y);

	float3 avaragedAmbient =
		ambFog * (0.7 - isVert * 0.1) +
		_LightColor0.rgb * MATCH_RAY_TRACED_SUN_COEFFICIENT * 0.2 * (1 - isUp) + // Light bounced from floor
		_RayMarchSkyColor  * 0.5 * (1 + isUp);

	return avaragedAmbient;
}

float3 GetDirectional()
{
	return _LightColor0.rgb;// *MATCH_RAY_TRACED_SUN_COEFFICIENT;// * smoothstep(0, 0.1, _WorldSpaceLightPos0.y);
}


inline float4 SampleVolumeOffsetByNormal(float3 pos, float3 normal, out float outOfBounds)
{
	normal = normal * _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 0.15;

	float4 bake = SampleVolume(_RayMarchingVolume, pos + normal
		, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
		, _RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);

	return bake;
}

inline float4 SampleVolume(sampler2D tex, float3 pos, out float outOfBounds)
{
	float4 bake = SampleVolume(tex, pos
		, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
		, _RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);


	return bake;
}

inline float3 volumeUVtoWorld(float2 uv) 
{
	return volumeUVtoWorld(uv, _RayMarchingVolumeVOLUME_POSITION_N_SIZE, _RayMarchingVolumeVOLUME_H_SLICES);
}



inline void ApplyTopDownLightAndShadow(float2 topdownUv, float3 normal, float3 worldPos, float gotVolume, inout float4 bake)
{

	float4 tdUv = float4(topdownUv + normal.xz * _RayTracing_TopDownBuffer_Position.w * 2, 0, 0);

	float4 topDown = tex2Dlod(_RayTracing_TopDownBuffer, tdUv);


	float2 offUv = tdUv - 0.5;

	float topDownVisible =
		
		 (1 - smoothstep(0.2, 0.25, length(offUv * offUv))) *
		
		//gotVolume * 
		smoothstep(3, 0, abs(_RayTracing_TopDownBuffer_Position.y - worldPos.y));
	topDown *= topDown;
	float ambientBlock = max(0.25f, 1 - topDown.a);

	float3 light = topDown.rgb;

	bake *= ambientBlock;
	bake.rgb += light;
}

inline void ApplyTopDownLightAndShadow(float2 topdownUv, float3 normal, float4 bumpMap, float3 worldPos, float gotVolume, float fresnel, inout float4 bake)
{

		float smoothness = bumpMap.b; 

		float2 offset = normal.xz * _RayTracing_TopDownBuffer_Position.w;



		float2 offUv = topdownUv - 0.5;
		gotVolume = (1 - smoothstep(0.2, 0.25, length(offUv * offUv)));

		float4 topDown = tex2D(_RayTracing_TopDownBuffer, topdownUv + offset * (0.2 + smoothness));
		float4 topDownRefl = tex2Dlod(_RayTracing_TopDownBuffer, float4(topdownUv + offset * 4 , 0, 0));
		float topDownVisible = gotVolume * (1 - fresnel*0.5) * smoothstep(3, 0, abs(_RayTracing_TopDownBuffer_Position.y - worldPos.y));
		topDown *= topDownVisible;
		topDownRefl *= topDownVisible;
		float ambientBlock = max(0.25f, 1 - topDown.a);
		//shadow *= ambientBlock;

		float3 light = (topDown.rgb + topDownRefl.rgb * bumpMap.a) * bumpMap.a;

		float3 mix = light.gbr + light.brg;

		bake *= ambientBlock;
		bake.rgb += light + mix * 0.2f;
}



#define AddGlossToCol(lCol)  // col += smoothness / (1.001 - smoothness + (1 - saturate(dot(normal, normalize(o.viewDir.xyz + _WorldSpaceLightPos0.xyz)))) * 64) * lCol * MATCH_RAY_TRACED_SUN_LIGH_GLOSS;

#define TRANSFER_TOP_DOWN(o) o.topdownUv = (o.worldPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;

#define TRANSFER_WTANGENT(o) o.wTangent.xyz = UnityObjectToWorldDir(v.tangent.xyz); o.wTangent.w = v.tangent.w * unity_WorldTransformParams.w;

#define PrimitiveLight(directional, ambient, outOfBounds, pos, normal)								\
	float  outOfBounds;																				\
	float4 vol = SampleVolume(pos, outOfBounds);													\
	float3 ambient = lerp(vol, _RayMarchSkyColor.rgb, outOfBounds);		\
	float direct = saturate((dot(normal, _WorldSpaceLightPos0.xyz)));							\
	float3 directional = GetDirectional() * direct; \




inline float3 SampleRay(float3 pos, float3 ray, float shadow, out float3 hitPos, out float outOfBounds)
{
	float4 mat = float4(getSkyColor(ray), 1); 
	float2 MIN_MAX = float2(0.0001, MAX_DIST_EDGE);
	float3 normalTmp;
	float3 res = worldhit(pos, ray, MIN_MAX, normalTmp, mat);
	float distance = res.y;
	hitPos = pos + ray * distance;
	float3 col = SampleVolumeOffsetByNormal(hitPos, normalTmp, outOfBounds).rgb * mat.rgb;

	float3 skyColor = lerp(unity_FogColor.rgb, mat.rgb, smoothstep(0,0.23, ray.y));
	float skyAmaunt = smoothstep(0, 1,distance/500); //smoothstep(0, 1, outOfBounds);
	col = lerp(col, skyColor, skyAmaunt);

	return col.rgb;
}

inline float3 SampleReflection(float3 pos, float3 viewDir, float3 normal, float shadow, out float3 reflectionPos, out float outOfBoundsRefl)
{
	float3 reflectedRay = reflect(-viewDir, normal);
	return SampleRay(pos, reflectedRay, shadow, reflectionPos, outOfBoundsRefl);
}

inline float SampleShadow(float3 pos, float3 normal)
{
	float2 MIN_MAX = float2(0.0001, MAX_DIST_EDGE);
	float3 normalTmp;
	float4 mat = float4(0,0,0,1); 
	float3 result = worldhit(pos + normal*0.1, _WorldSpaceLightPos0.xyz, MIN_MAX, normalTmp, mat);

	float distance = result.y;

	return smoothstep(MAX_DIST_EDGE -10, MAX_DIST_EDGE, distance);
}