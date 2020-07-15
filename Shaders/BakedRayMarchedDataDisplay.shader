Shader "RayMarching/BakedRayMarchedDataDisplay"
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
		//ZWrite On
		//ZTest Off
		//Blend One Zero //SrcAlpha OneMinusSrcAlpha

		Pass{

			CGPROGRAM

			#include "PrimitivesScene.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile __ RT_USE_DIELECTRIC
			#pragma multi_compile __ RT_USE_CHECKERBOARD
			#pragma multi_compile __ _IS_RAY_MARCHING

			struct v2f {
				float4 pos		: SV_POSITION;
				//float3 viewDir	: TEXCOORD0;
				//float2 texcoord : TEXCOORD1;
				float3 worldPos : TEXCOORD0;
				float3 normal : TEXCOORD1;
			};

			sampler2D _MainTex;

			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				//o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				//o.texcoord = v.texcoord.xy;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.normal.xyz = UnityObjectToWorldNormal(v.normal);

				return o;
			}

	
			float4 frag(v2f o) : COLOR{

				/*float3 worldPos = volumeUVtoWorld(o.texcoord.xy
					, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
					, _RayMarchingVolumeVOLUME_H_SLICES);
					*/

				float4 col = SampleVolume(_RayMarchingVolume, o.worldPos 
				//+ o.normal.xyz * _RayMarchingVolumeVOLUME_POSITION_OFFSET.w
				, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
				, _RayMarchingVolumeVOLUME_H_SLICES);

				float unFogged = min(1, col.a);

				col.rgb = col.rgb * unFogged + unity_FogColor.rgb * (1-unFogged);

				return col;
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
}