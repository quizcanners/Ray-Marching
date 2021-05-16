Shader "RayTracing/Baker/Shape"
{
	Properties{
		   _MainTex("Albedo (RGB)", 2D) = "white" {}
		   _ObjectPos("World Position", Vector) = (0,0,0,0)
		   _ObjectSize("Object Size", Vector) = (0,0,0,0)
		  // [Toggle(_DEBUG)] debugOn("Debug", Float) = 0
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
		

			struct v2f {
				float4 pos : 		SV_POSITION;
				float3 viewDir: 	TEXCOORD1;
				float2 texcoord : TEXCOORD0;
			};

			sampler2D _MainTex;
			float4 _ObjectPos;
			float4 _ObjectSize;


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

				float dist = length(_ObjectPos - worldPos);
				
				float alpha = step(dist, _ObjectSize.x);

			//	clip(_ObjectSize.x - dist);

				//float3 offsetPos = worldPos + _RayMarchingVolumeVOLUME_POSITION_OFFSET.xyz;
				float outOfBounds;

				float4 previous = SampleVolume(_MainTex
					, worldPos //offsetPos
					, _RayMarchingVolumeVOLUME_POSITION_N_SIZE,
					_RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);

				//clip(1500 - previous.a);

				float4 col = float4(1,0,0,MAX_VOLUME_ALPHA) * alpha + previous * (1-alpha);

				return col;
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}