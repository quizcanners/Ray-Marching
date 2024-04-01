Shader "RayTracing/Baker/Post Effects"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_PreviousTex("Albedo (RGB)", 2D) = "clear" {}
		[Toggle(_DEBUG)] debugOn("Debug", Float) = 0
	}

	SubShader
	{

		Tags
		{
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
		}

		ColorMask RGBA
		Cull Off
		ZWrite Off
		ZTest Off
		Blend One One//One Zero 

		Pass
		{

			CGPROGRAM

			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_PostEffectBake.cginc"
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile __ RT_TO_CUBEMAP 

			struct v2f 
			{
				float4 pos : 		SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float3 viewDir: 	TEXCOORD1;
			};

			float4 _Effect_Time;
	
			v2f vert(appdata_full v) 
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.texcoord = v.texcoord.xy;
				return o;
			}


			sampler2D _MainTex;
			sampler2D _PreviousTex;
			float4 _RT_CubeMap_Direction;

			float4 _RayMarchingVolumeVOLUME_POSITION_N_SIZE_PREVIOUS;
			float4 _RayMarchingVolumeVOLUME_H_SLICES_PREVIOUS;

			float4 frag(v2f o) : SV_TARGET 
			{
				float3 worldPos = volumeUVtoWorld(o.texcoord.xy);

				float outOfBounds;

				/*
				float4 vol = SampleVolume(_MainTex, worldPos
					, _RayMarchingVolumeVOLUME_POSITION_N_SIZE_PREVIOUS
					, _RayMarchingVolumeVOLUME_H_SLICES_PREVIOUS, outOfBounds);
					*/

				float4 previous = tex2Dlod(_PreviousTex, float4(o.texcoord.xy, 0, 0));


				float VOL_SIZE = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

				float4 sdf = SampleSDF(worldPos, outOfBounds);

				//float blackPixel = smoothstep(0, -0.01, sdf.a) * (1-outOfBounds);
				
				float3 postCol;
				float ao;

				float4 noise = 0.5;

				#if RT_TO_CUBEMAP
					SamplePostEffects(worldPos,_RT_CubeMap_Direction.xyz, postCol, ao, noise);
				#else
					SamplePostEffects(worldPos, postCol, ao, noise);
				#endif

			

				float4 col = (previous + float4(postCol,0)) * ao;

				//col.a = 1;

				//col.rgb = lerp(col.rgb,0, blackPixel);

				return col;
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}