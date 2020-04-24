Shader "RayTracing/RayTracing"
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

			#include "RayTrace_Scene.cginc"
			#include "Assets/Tools/Playtime Painter/Shaders/quizcanners_cg.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile __ RT_USE_DIELECTRIC
			#pragma multi_compile __ RT_MOTION_TRACING

			struct v2f {
				float4 pos : 		SV_POSITION;
				float3 viewDir: 	TEXCOORD1;
				float4 screenPos : 	TEXCOORD2;
			};

			sampler2D _MainTex;
			
			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.screenPos = ComputeScreenPos(o.pos);
				return o;
			}

			uniform float _RayTraceDofDist;
			uniform float _RayTraceDOF;
			uniform sampler2D _RayTracing_SourceBuffer;

			float4 frag(v2f o) : COLOR{

				float3 rayOrigin = _WorldSpaceCameraPos.xyz; 
				float3 rayDirection = -normalize(o.viewDir.xyz);

				o.screenPos.xy /= o.screenPos.w;

				float4 noise = tex2Dlod(_Global_Noise_Lookup, float4(o.screenPos.xy * 13.5123 + float2(_SinTime.w, _CosTime.w) * 32.12345612, 0, 0));

				float4 previousFrame = tex2Dlod(_RayTracing_SourceBuffer, float4(o.screenPos.xy, 0, 0));

				float aaCoef = (_ScreenParams.z - 1) * 2;

				/*
#if RT_MOTION_TRACING
				#define ITER  3
				for (int i = 0; i < ITER; i++) {

#endif
*/
					float3 rand = normalize(noise.rgb - 0.5);

					// AA
					float3 rd = rayDirection + rand *noise.a * aaCoef;

					// DOF

					float3 fp = rayOrigin + rd * _RayTraceDofDist;
					float3 ro = rayOrigin + rand.gbr * _RayTraceDOF;
					rd = normalize(fp - ro);


					float3 col = render(ro, rd, noise);
					/*
#if RT_MOTION_TRACING

					noise = noise.gbar;
				}
				
				col /= ITER;

				float diff = 0.5 + saturate(abs(col.a - previousFrame.a))*0.5;

				col.rgb = col.rgb * diff + previousFrame.rgb * (1 - diff);

				//col = (previousFrame.rgb + col.rgb)/ (ITER + 1);

#else*/
				col = col * _RayTraceTransparency * 1000 + max(0,previousFrame.rgb) * (1 - _RayTraceTransparency);
//#endif

				return float4(col,1);
			}
			ENDCG
		}
	}
	 Fallback "Legacy Shaders/Transparent/VertexLit"
}