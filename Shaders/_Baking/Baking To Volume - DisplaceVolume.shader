Shader "RayTracing/Baker/Displace Volume Data"
{
	Properties
	{
		   _MainTex("Albedo (RGB)", 2D) = "white" {}
	}

	SubShader{
		Tags{
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
		}

		ColorMask RGBA
		Cull Back
		ZWrite Off
		ZTest Off
		Blend One Zero

		Pass{

			CGPROGRAM

			#define _qc_AMBIENT_SIMULATION
			#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Sampler.cginc"
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma fragment frag

			//#pragma multi_compile ___ Qc_OffsetRGBA
			#pragma multi_compile ___ _qc_IGNORE_SKY

			struct v2f {
				float4 pos : 		SV_POSITION;
				float2 texcoord : TEXCOORD0;
			};

			sampler2D _MainTex;
	
			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.texcoord = v.texcoord.xy;
				return o;
			}

			float4 _RayMarchingVolumeVOLUME_POSITION_N_SIZE_PREVIOUS;
			float4 _RayMarchingVolumeVOLUME_H_SLICES_PREVIOUS;

			inline float3 volumeUVtoWorld_Previous(float2 uv) 
			{
				return volumeUVtoWorld(uv, _RayMarchingVolumeVOLUME_POSITION_N_SIZE_PREVIOUS, _RayMarchingVolumeVOLUME_H_SLICES_PREVIOUS);
			}

			float4 frag(v2f o) : SV_TARGET {

				float3 worldPos = volumeUVtoWorld(o.texcoord.xy);

				float outOfBounds;

					float4 vol = SampleVolume(_MainTex, worldPos
					, _RayMarchingVolumeVOLUME_POSITION_N_SIZE_PREVIOUS
					, _RayMarchingVolumeVOLUME_H_SLICES_PREVIOUS, outOfBounds);

				
				//float4 vol = SampleVolume(_MainTex, worldPos, outOfBounds);

				vol *= (1 - outOfBounds);
				vol *= 0.5;
				
				return vol;
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}