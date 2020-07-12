Shader "RayMarching/RayBakingOfLight"
{
	Properties{
		   _MainTex("Albedo (RGB)", 2D) = "white" {}
		   [Toggle(_DEBUG)] debugOn("Debug", Float) = 0
	}

	SubShader{

		Tags{
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
		}

		ColorMask RGBA
		Cull Back
		ZWrite On
		ZTest Off
		Blend One Zero //SrcAlpha OneMinusSrcAlpha

		Pass{

			CGPROGRAM

			#include "PrimitivesScene.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile __ RT_USE_DIELECTRIC
			#pragma multi_compile __ RT_USE_CHECKERBOARD
			#pragma multi_compile __ _IS_RAY_MARCHING

			struct v2f {
				float4 pos : 		SV_POSITION;
				float3 viewDir: 	TEXCOORD1;
				float2 texcoord : TEXCOORD0;
			};

			sampler2D _MainTex;
			float4 _RayMarchingVolumeVOLUME_POSITION_OFFSET;

			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.texcoord = v.texcoord.xy;
				return o;
			}

			float4 frag(v2f o) : COLOR{

				float3 worldPos = volumeUVtoWorld(o.texcoord.xy
					, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
					, _RayMarchingVolumeVOLUME_H_SLICES);


				float4 previous = SampleVolume(_MainTex
					, worldPos + _RayMarchingVolumeVOLUME_POSITION_OFFSET.xyz
					, _RayMarchingVolumeVOLUME_POSITION_N_SIZE,
					_RayMarchingVolumeVOLUME_H_SLICES);

				float2 screenUV = o.texcoord.xy * ( 4 * _CosTime.y ) + _SinTime.x;

				float4 noise = tex2Dlod(_Global_Noise_Lookup, float4(screenUV * (123.12345678)  
					+ float2(_SinTime.w, _CosTime.w) * 32.12345612, 0, 0));

				float3 rayDirection = normalize(noise.rgb - 0.5);

				#if _IS_RAY_MARCHING
					float4 col = renderSdf(worldPos, rayDirection, noise);
				#else
					float4 col = render(worldPos, rayDirection, noise);
				#endif

				float accumulation = previous.a;

				//float keepPrevious = (1 - _RayTraceTransparency)*accumulation;

				col.a = accumulation + 1;

				col.rgb = (col.rgb + max(0,previous.rgb) * accumulation)/ col.a;

				 //saturate(1 - pow((1-accumulation),2));

				return col ;
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}