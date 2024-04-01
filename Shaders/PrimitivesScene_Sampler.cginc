#ifndef QC_PRIM_SMP
#define QC_PRIM_SMP


#include "Assets/Qc_Rendering/Shaders/PrimitivesScene.cginc"
#include "Assets/Qc_Rendering/Shaders/Savage_VolumeSampling.cginc"

#include "UnityLightingCommon.cginc" 

// Should Ignore Non Primitive related parts

/*
sampler2D _RayMarchingVolume_UP;
sampler2D _RayMarchingVolume_DOWN;
sampler2D _RayMarchingVolume_LEFT;
sampler2D _RayMarchingVolume_RIGHT;
sampler2D _RayMarchingVolume_BACK;
sampler2D _RayMarchingVolume_FRONT;
*/


UNITY_DECLARE_TEX2DARRAY(_RayMarchingVolume_CUBE);

float _qc_FogVisibility;
float _RT_CubeMap_FadeIn;

inline float3 GetDirectional()
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	return _qc_SunColor.rgb * _qc_SunVisibility;// *MATCH_RAY_TRACED_SUN_COEFFICIENT;// * smoothstep(0, 0.1, _WorldSpaceLightPos0.y);
}

float3 getSkyColor(float3 rd, float shadow)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	float3 col = SampleSkyBox(rd);

	if (_qc_SunVisibility<=0.01)
	{
		return col; //float4(0,0,0,distance);
	}

#if defined(_qc_AMBIENT_SIMULATION)
#else
	float sun = smoothstep(1, 0, dot(qc_SunBackDirection.xyz, rd));
	col.rgb += GetDirectional() 
	* shadow * (1 / (0.01 + sun * 6000));
#endif

	return col;
}

float3 getSkyColor(float3 rd) 
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	return getSkyColor(rd, 1);
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
	
	float outOfBounds;

	float upperFraction;
	float4 uvs = WorldPosToVolumeUV(pos, _RayMarchingVolumeVOLUME_POSITION_N_SIZE, _RayMarchingVolumeVOLUME_H_SLICES, upperFraction, outOfBounds);

	float3 bake = SampleVolume_Internal(_RayMarchingVolume, uvs, upperFraction).rgb * 2; // To compensate brightness
		

		float3 absDir = abs(normal + 0.01);

		// Choose some direction over other
		//absDir = pow(absDir, 3);
		absDir = normalize(absDir);

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
	
		bake = cubeBake; // lerp(bake, cubeBake, _RT_CubeMap_FadeIn); 

	//}

//#endif

	

	return lerp(bake, avgAmb, lerp(1, outOfBounds, qc_VolumeAlpha));
}



//#define AddGlossToCol(lCol)  // col += smoothness / (1.001 - smoothness + (1 - saturate(dot(normal, normalize(o.viewDir.xyz + _WorldSpaceLightPos0.xyz)))) * 64) * lCol * MATCH_RAY_TRACED_SUN_LIGH_GLOSS;


#endif

