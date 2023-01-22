Shader "RayTracing/Baker/RayBakingOfLight"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		[Toggle(_DEBUG)] debugOn("Debug", Float) = 0
	}

	SubShader{

		Tags{
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
		}

		ColorMask RGBA
		Cull Off
		ZWrite Off
		ZTest Off
		Blend One One//One Zero 

		Pass{

			CGPROGRAM

			#define _qc_AMBIENT_SIMULATION
			#include "PrimitivesScene.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile __ RT_DENOISING

			struct v2f {
				float4 pos : 		SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float3 viewDir: 	TEXCOORD1;
				float2 noiseUV :	TEXCOORD2;
			};

			float4 _Effect_Time;
			sampler2D _MainTex;
	
			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.texcoord = v.texcoord.xy;

				o.noiseUV = o.texcoord * (123.12345678) + float2(sin(_Effect_Time.x), cos(_Effect_Time.x*1.23)) * 123.12345612 * (1 + o.texcoord.y);


				return o;
			}

			float4 frag(v2f o) : COLOR{

				float3 worldPos = volumeUVtoWorld(o.texcoord.xy 
					, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
					, _RayMarchingVolumeVOLUME_H_SLICES);

				float4 noise = tex2Dlod(_Global_Noise_Lookup, float4(o.noiseUV, 0, 0));

				float4 nrmDist = NormalAndDistance(worldPos);

				float3 rayDirection = //normalize(
					normalize(noise.rgb - 0.5); // +nrmDist.xyz * smoothstep(2, 0, nrmDist.w));
	
				float4 col = //(
					render(worldPos, rayDirection, noise);
					/* + render(worldPos, rayDirection, noise.yzwx)
					+ render(worldPos, rayDirection, noise.zwxy)
					+ render(worldPos, rayDirection, noise.wxyz)
					) *0.25;*/
		
				
#ifdef UNITY_COLORSPACE_GAMMA
				col.rgb = pow(col.rgb, GAMMA_TO_LINEAR);
#endif

				col.a = 1;

				return col;
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}