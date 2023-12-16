#include "Assets/Qc_Rendering/Shaders/PrimitivesScene.cginc"

/*
sampler2D _RayMarchingVolume_UP;
sampler2D _RayMarchingVolume_DOWN;
sampler2D _RayMarchingVolume_LEFT;
sampler2D _RayMarchingVolume_RIGHT;
sampler2D _RayMarchingVolume_BACK;
sampler2D _RayMarchingVolume_FRONT;
*/

uniform float qc_KWS_FogAlpha;

UNITY_DECLARE_TEX2DARRAY(_RayMarchingVolume_CUBE);

sampler2D _qc_CloudShadows_Mask;
float _qc_Rtx_CloudShadowsVisibility;

float4 _qc_ColorCorrection_Color;
float4 _qc_ColorCorrection_Params;

float _qc_FogVisibility;

float _RT_CubeMap_FadeIn;

void ColorCorrect(inout float3 col)
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

float SampleSkyShadow(float3 pos)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	//#if _qc_CLOUD_SHADOWS
		
		if (_qc_SunVisibility<0.01)
			return 0;

		return  smoothstep(0, _qc_Rtx_CloudShadowsVisibility, tex2Dlod(_qc_CloudShadows_Mask, float4(pos.xz * 0.0002 + _Time.x*0.2,0,0)).r);

	//#else

	//	return 1;

//	#endif
}

float3 GetAvarageAmbient(float3 normal)
{

#if _qc_IGNORE_SKY
	return 0;
	#endif

	return GetAmbientLight() * lerp(0.5,1,smoothstep(-1,0,normal.y));

	//	float4 ambFog = unity_FogColor * 0.2;

	//float isUp = smoothstep(0, 1, normal.y);
	//float isVert = abs(normal.y);

	//normal.y = -abs(normal.y) - 0.1;

	//return 
	//ambFog //* smoothstep(1, 0, isVert) + 
		//SampleSkyBox(normal);
		// *isUp;// *isUp;// getSkyColor(normal, 1) * isUp;// +SampleSkyShadow(float3(0, -1, 0)) * isUp;
}

void ApplyBottomFog(inout float3 col, float3 worldPos, float viewDirY)
{

	#if _qc_IGNORE_SKY
		return;
	#endif

	if (_qc_FogVisibility == 0)
	{
		return;
	}

	float bottomFog = smoothstep(-0.35, -0.02, viewDirY);

	float3 diff = worldPos - _WorldSpaceCameraPos.xyz;

	float fromCamera = length(diff);

	float dist01 =  smoothstep(0,1, fromCamera * _ProjectionParams.w) ;

	float minFog = smoothstep(50, 150, fromCamera) * smoothstep(fromCamera*0.2, 0, worldPos.y);

	float byHeight = smoothstep(0, -300, worldPos.y);

	float3 fogCol = GetAvarageAmbient(normalize(diff));

	col.rgb = lerp(col.rgb, fogCol, smoothstep(0,1,minFog * 0.5 + byHeight + dist01 * bottomFog * bottomFog) * _qc_FogVisibility);// smoothstep(0, 1, 1)); // dist01* bottomFog + minFog + byHeight));
	
}


float4 SampleCubemap_Internal(float4 uvs, float upperFraction, int depth)
{
	float4 bake = UNITY_SAMPLE_TEX2DARRAY_LOD(_RayMarchingVolume_CUBE, float3(uvs.xy, depth),0); //tex2Dlod(volume, float4(uvs.xy, 0, 0));
	float4 bakeUp = UNITY_SAMPLE_TEX2DARRAY_LOD(_RayMarchingVolume_CUBE, float3(uvs.zw, depth),0); //tex2Dlod(volume, float4(uvs.zw, 0, 0));
	return lerp(bake, bakeUp, upperFraction);
}

float3 SampleVolume_CubeMap(float3 pos, float3 normal)
{
	float3 avgAmb = GetAvarageAmbient(normal);

	#if qc_NO_VOLUME
		return avgAmb;
	#endif
	
	/*
	if (qc_VolumeAlpha < 0.1) 
	{
		return avgAmb;
	}*/

	//float3 offsetPosition = pos;

	float outOfBounds;

	float upperFraction;
	float4 uvs = WorldPosToVolumeUV(pos, _RayMarchingVolumeVOLUME_POSITION_N_SIZE, _RayMarchingVolumeVOLUME_H_SLICES, upperFraction, outOfBounds);

	float3 bake = SampleVolume_Internal(_RayMarchingVolume, uvs, upperFraction).rgb * 2; // To compensate brightness
		
//#if RT_FROM_CUBEMAP
	
	//if (_RT_CubeMap_FadeIn > 0.1)
	//{
		float3 absDir = abs(normal + 0.01);

		float isLeft = step(normal.x, 0);
		float isDown = step(normal.y, 0);
		float isBack = step(normal.z, 0);

		//absDir = absDir * 0.9 + 0.1; //lerp(absDir, 0.1, 0.1);

		float4 toAddX = SampleCubemap_Internal(uvs, upperFraction, isLeft);
		float4 toAddY = SampleCubemap_Internal(uvs, upperFraction, 2 + isDown);
		float4 toAddZ = SampleCubemap_Internal(uvs, upperFraction, 4 + isBack);

		float3 cubeBake = 0;
		cubeBake += absDir.x * lerp(bake, toAddX.rgb, smoothstep(0, 100, toAddX.a));
		cubeBake += absDir.y * lerp(bake, toAddY.rgb, smoothstep(0, 100, toAddY.a));
		cubeBake += absDir.z * lerp(bake, toAddZ.rgb, smoothstep(0, 100, toAddZ.a));

		//lerp(left, right, step(0, normal.x));


		//float4 right = SampleCubemap_Internal(uvs, upperFraction, 0);
		//float4 left = SampleCubemap_Internal(uvs, upperFraction, 1);

		//float4 up = SampleCubemap_Internal(uvs, upperFraction, 2);
		//float4 down = SampleCubemap_Internal(uvs, upperFraction, 3);

		//float4 forward = SampleCubemap_Internal(uvs, upperFraction, 4);
		//float4 back = SampleCubemap_Internal(uvs, upperFraction, 5);

		/*
		float4 right = SampleVolume_Internal(_RayMarchingVolume_RIGHT, uvs, upperFraction);
		float4 left = SampleVolume_Internal(_RayMarchingVolume_LEFT, uvs, upperFraction);

		float4 up = SampleVolume_Internal(_RayMarchingVolume_UP, uvs, upperFraction);
		float4 down = SampleVolume_Internal(_RayMarchingVolume_DOWN, uvs, upperFraction);

		float4 forward = SampleVolume_Internal(_RayMarchingVolume_FRONT, uvs, upperFraction);
		float4 back = SampleVolume_Internal(_RayMarchingVolume_BACK, uvs, upperFraction);

		toAdd =  lerp(left, right, step(0, normal.x));
		cubeBake += absDir.x * lerp(bake, toAdd, smoothstep(0, 100, toAdd.a));

		toAdd =  lerp(down, up, step(0, normal.y));
		cubeBake += absDir.y * lerp(bake, toAdd, smoothstep(0, 100, toAdd.a));

		toAdd =  lerp(back, forward, step(0, normal.z));
		cubeBake += absDir.z * lerp(bake, toAdd, smoothstep(0, 100, toAdd.a));
		*/
	
		bake = lerp(bake, cubeBake, _RT_CubeMap_FadeIn); 

	//}

//#endif

	

	return lerp(bake, avgAmb, lerp(1, outOfBounds, qc_VolumeAlpha));
}



float3 volumeUVtoWorld(float2 uv) 
{
	return volumeUVtoWorld(uv, _RayMarchingVolumeVOLUME_POSITION_N_SIZE, _RayMarchingVolumeVOLUME_H_SLICES);
}


#define AddGlossToCol(lCol)  // col += smoothness / (1.001 - smoothness + (1 - saturate(dot(normal, normalize(o.viewDir.xyz + _WorldSpaceLightPos0.xyz)))) * 64) * lCol * MATCH_RAY_TRACED_SUN_LIGH_GLOSS;



#define PrimitiveLight(directional, ambient, outOfBounds, pos, normal)\
	float  outOfBounds;\
	float4 vol = SampleVolume(pos, outOfBounds);\
	float3 ambient = lerp(vol, 0.5, outOfBounds);\
	float direct = saturate((dot(normal, _WorldSpaceLightPos0.xyz)));\
	float3 directional = GetDirectional() * direct; \

struct RaySamplerHit
{
	float3 Pos;
	float3 Normal;
	//float OutOfBounds;
	float4 Material;
};

/*
inline float3 SampleRay(float3 pos, float3 ray, float shadow, out RaySamplerHit hit)
{
	hit.Material = float4(getSkyColor(ray, shadow), 1);
	float2 MIN_MAX = float2(0.0001, MAX_DIST_EDGE);
	float3 res = worldhit(pos, ray, MIN_MAX, hit.Normal, hit.Material);
	float distance = res.y;
	hit.Pos = pos + ray * distance;

	float type = res.z;

	float3 col;

	if (type > EMISSIVE)
	{
		return hit.Material.rgb;
	}
	else if (type>0)
	{
		float OutOfBounds;
		col = SampleVolume(hit.Pos, OutOfBounds).rgb;
		float showSunLight = SampleRayShadowAndAttenuation(hit.Pos, hit.Normal);
		col += GetDirectional() * showSunLight;
		col *= hit.Material.rgb;

		ApplyBottomFog(col, hit.Pos, ray.y);
		return col.rgb;
	} else 
	{
		return hit.Material.rgb;
	}	
}*/

inline float SampleContactAO(float3 pos, float3 normal)
{
	#if !qc_NO_VOLUME
		float outsideVolume;
		float4 scene = SampleSDF(pos , outsideVolume);

		float coef = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

		//float sameNormal = smoothstep(-1, 1, dot(normal, scene.xyz));
		return lerp(smoothstep(-2 * coef,2 * coef, scene.a + dot(normal, scene.xyz)*2 * coef),1, outsideVolume);
	#else 
		return 1;
	#endif
}

float3 SampleRay_NoSun_MipSky(float3 pos, float3 ray, float smoothness, out RaySamplerHit hit)
{
	hit.Material = float4(SampleSkyBox(ray, smoothness), 0);
	float2 MIN_MAX = float2(0.0001, MAX_DIST_EDGE);

	pos = pos + ray * 0.1;
	//pos.y = abs(pos.y);

	float3 res = worldhit(pos , ray, MIN_MAX, hit.Normal, hit.Material);

	float type = res.z;

	float distance = res.y;

	hit.Pos = pos + ray * distance;

	float3 col;

	#if _qc_IGNORE_SKY
		UNITY_FLATTEN
	#else
		UNITY_BRANCH
	#endif
	if (type>0 && type < EMISSIVE)
	{
		//hit.Normal =  EstimateNormal(hit.Pos, length(distance) * 0.05);

	//float3 pos, float3 normal, out float outOfBounds
		float3 reflected = reflect(ray, hit.Normal);
		
		//float spec = hit.Material.a;

		float3 bake = SampleVolume_CubeMap(hit.Pos, hit.Normal) * SampleContactAO(hit.Pos, hit.Normal);

		col = (bake
		#if !_qc_IGNORE_SKY
			+ GetDirectional() * SampleRayShadowAndAttenuation(hit.Pos, hit.Normal)
		#endif

		) * hit.Material.rgb;

	} else 
	{
		col =  hit.Material.rgb;
	}
	
	col = lerp(col, GetAmbientLight(), qc_KWS_FogAlpha * smoothstep(0, 32, distance));

	return col;
}

float3 SampleRay_NoSun(float3 pos, float3 ray, out RaySamplerHit hit) 
{
	return SampleRay_NoSun_MipSky(pos, ray, 1.0, hit);
}

