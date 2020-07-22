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
			#include "PrimitivesScene_Sampler.cginc"

			#pragma vertex vert
			#pragma fragment frag

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

			float4 frag(v2f o) : COLOR{

				float3 worldPos = volumeUVtoWorld(o.texcoord.xy);

				float3 offsetPos = worldPos + _RayMarchingVolumeVOLUME_POSITION_OFFSET.xyz ;

				float outOfBounds;
				float4 vol = SampleVolume(_MainTex, offsetPos, outOfBounds);

				vol *= 0.98 * (1- outOfBounds);

				return vol;
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}