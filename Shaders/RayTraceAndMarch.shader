﻿Shader "RayTracing/Bake/To Screen"
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
			#pragma multi_compile __ RT_MOTION_TRACING
			#pragma multi_compile __ RT_DENOISING
			#pragma multi_compile __ RT_USE_CHECKERBOARD
			#pragma multi_compile __ _IS_RAY_MARCHING

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

			inline float4 Denoise(float2 screenUV, float2 pixSize, float colA, float strictness) {
				float4 off = tex2Dlod(_RayTracing_SourceBuffer, float4(screenUV + pixSize, 0, 0));
				off.a = 1 - saturate(abs(colA - off.a) * strictness);
				return off;
			}

			float4 frag(v2f o) : COLOR{

				float3 rayDirection = -normalize(o.viewDir.xyz);
				float3 rayOrigin = _WorldSpaceCameraPos.xyz; // +_ProjectionParams.y * rayDirection;

				float2 screenUV = o.screenPos.xy / o.screenPos.w;

				float4 noise = tex2Dlod(_Global_Noise_Lookup, float4(screenUV * (123.12345678) // - _RayTraceTransparency * 12)  
					+ float2(_SinTime.w, _CosTime.w) * 32.12345612, 0, 0));

				float aaCoef = (_ScreenParams.z - 1) * 2;

				float3 rand = normalize(noise.rgb - 0.5) * noise.a* noise.a;

				// AA
				float3 rd = rayDirection + rand * aaCoef;

				// DOF
				#if RT_MOTION_TRACING
					float3 ro = rayOrigin;
				#else
					float3 fp = rayOrigin + rd * _RayTraceDofDist;
					float3 ro = rayOrigin + rand.gbr * _RayTraceDOF;
					rd = normalize(fp - ro);
				#endif

				#if RT_DENOISING && !_IS_RAY_MARCHING

					#if _IS_RAY_MARCHING
										float4 col = renderSdf(ro, rd, noise);
					#else
										float4 col = render(ro, rd, noise);
					#endif

					float2 pixSize = _RayTracing_SourceBuffer_ScreenFillAspect.zw * 4;

					float count = 0;
					float3 previousFrame = 0;

					#define APPLY previousFrame.rgb += deNoise.rgb * deNoise.a; count += deNoise.a;

					float strictness = (10 * (1.1 - _RayTraceTransparency)); 
					float4 deNoise = 0;

					#if RT_MOTION_TRACING
						deNoise = Denoise(screenUV, 0, col.a, strictness);
						APPLY
					#else
						previousFrame = tex2Dlod(_RayTracing_SourceBuffer, float4(screenUV, 0, 0)).rgb;
						count += 1;
					#endif

					deNoise = Denoise(screenUV, pixSize * rand.rgb, col.a, strictness);
					APPLY

					deNoise = Denoise(screenUV, pixSize * rand.gbr,  col.a, strictness);
					APPLY

					deNoise = Denoise(screenUV, pixSize * rand.brg,  col.a, strictness);
					APPLY

					deNoise = Denoise(screenUV, pixSize * rand.rbg, col.a, strictness);
					APPLY

					#if RT_MOTION_TRACING && !_IS_RAY_MARCHING
						col.rgb = max(previousFrame.rgb / count * 0.75 , (col.rgb + previousFrame.rgb) / (count + 1));
					#else
						previousFrame = previousFrame / count;
						col.rgb = col.rgb * _RayTraceTransparency + max(0, previousFrame.rgb) * (1 - _RayTraceTransparency);
					#endif

				#else
					#if _IS_RAY_MARCHING
						float4 col = renderSdf(ro, rd, noise);
					#else
						float4 col = render(ro, rd, noise);
					#endif

						float4 previousFrame = tex2Dlod(_RayTracing_SourceBuffer, float4(screenUV, 0, 0));
						col.rgb = col.rgb * _RayTraceTransparency + max(0, previousFrame.rgb) * (1 - _RayTraceTransparency);
				#endif

						return col;
			}
			ENDCG
		}
	}
			  Fallback "Legacy Shaders/Transparent/VertexLit"
}