Shader "RayTracing/Baker/Intersect & March"
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

			#define _qc_AMBIENT_SIMULATION
			#define RENDER_DYNAMICS
			#define RAYMARCH_DYNAMICS
			#include "PrimitivesScene.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile __ RT_MOTION_TRACING
			#pragma multi_compile __ RT_DENOISING
			#pragma multi_compile __ _IS_RAY_MARCHING  _IS_PROGRESSIVE_MARCHING
			#pragma multi_compile __ RT_PROGRESSIVE_BUFFER
			#pragma multi_compile ___ _qc_IGNORE_SKY

			struct v2f {
				float4 pos : 		SV_POSITION;
				float3 viewDir: 	TEXCOORD1;
				float4 screenPos : 	TEXCOORD2;
				float pixSize :		TEXCOORD3;
				float2 noiseUV :	TEXCOORD4;
			};

			sampler2D _MainTex;
			float4 _MainTex_TexelSize;
			float4 _RayTracing_MarchingProgressive_TexelSize;
			sampler2D _RayTracing_MarchingProgressive;

			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.screenPos = ComputeScreenPos(o.pos);

	
				o.noiseUV = o.screenPos.xy / o.screenPos.z * (123.12345678) + float2(_SinTime.x, _CosTime.y) * 32.12345612;

				float viewDepth = -UnityObjectToViewPos(v.vertex);
				o.pixSize = min(_MainTex_TexelSize.x, _MainTex_TexelSize.y) / (unity_CameraProjection._m00 * _ScreenParams.x) * 8;

				//float2 coeff = pow(float2(unity_CameraProjection._m00, unity_CameraProjection._m11), 2);
				//o.pixSize = 0.01 * _MainTex_TexelSize.xy * coeff;

				return o;
			}

			inline float4 Denoise(float2 screenUV, float2 pixSize, float colA, float strictness) {
				float4 off = tex2Dlod(_RayTracing_SourceBuffer, float4(screenUV + pixSize, 0, 0));
				off.a = 1 - saturate(abs(colA - off.a) * strictness);
				return off;
			}

			float4 frag(v2f o) : COLOR{

				float3 rayOrigin = _WorldSpaceCameraPos.xyz;
				float3 rayDirection = -normalize(o.viewDir.xyz);
				// +_ProjectionParams.y * rayDirection;

				float2 screenUV = o.screenPos.xy / o.screenPos.w;


#if _IS_PROGRESSIVE_MARCHING
#if RT_PROGRESSIVE_BUFFER
				return renderSdfProgression(rayOrigin, rayDirection, o.pixSize);
#else

				float2 pointUV = (floor(screenUV * _RayTracing_MarchingProgressive_TexelSize.zw) + 0.5) * _RayTracing_MarchingProgressive_TexelSize.xy;

				float4 preMarch = tex2Dlod(_RayTracing_MarchingProgressive, float4(pointUV,0,0));
				rayOrigin += preMarch.a * rayDirection;
#endif
#endif

				float4 noise =
					/*float4(
					hash33(uint3(screenUV * 12345, _SinTime.x * 123456)),
					hash1(_Time.x * 456789)
					); */
					// + float2(_SinTime.x, _CosTime.y));
					tex2Dlod(_Global_Noise_Lookup, float4(o.noiseUV, 0, 0)); //screenUV * (123.12345678) + float2(_SinTime.x, _CosTime.y + screenUV.y) * 32.12345612, 0, 0));

				noise.a = hash31(float3(screenUV, _Time.x));// ((noise.r + noise.b) * 2) % 1;

				float aaCoef = (min(_ScreenParams.z, _ScreenParams.w) - 1); 

				float3 rand = normalize(noise.rgb - 0.5) * noise.a;// *noise.a;

				// AA
				float3 rd = rayDirection + rand * aaCoef;

				// DOF
				/*#if RT_MOTION_TRACING
					float3 ro = rayOrigin;
				#else*/
					float3 fp = rayOrigin + rd * _RayTraceDofDist;
					float3 ro = rayOrigin +rand.gbr * _RayTraceDOF;
					rd = normalize(fp - ro);
			//	#endif

				#if RT_DENOISING && !_IS_RAY_MARCHING && !_IS_PROGRESSIVE_MARCHING

					#if _IS_RAY_MARCHING || _IS_PROGRESSIVE_MARCHING
										float4 col = renderSdf(ro, rd, noise);
					#else
										float4 col = render(ro, rd, noise);

						/*#if RT_MOTION_TRACING
							col += render(ro, rd + rand.zxy * aaCoef, noise.wxyz);
							col += render(ro, rd + rand.yzx * aaCoef, noise.zxwy);
							col += render(ro, rd - rand.xzy * aaCoef, noise.xzwy);

							col *= 0.25;
						#endif*/


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

					#if RT_MOTION_TRACING && !_IS_RAY_MARCHING && !_IS_PROGRESSIVE_MARCHING
						col.rgb = max(previousFrame.rgb / count * 0.75 , (col.rgb + previousFrame.rgb) / (count + 1));
					#else
						previousFrame = previousFrame / count;
						col.rgb = col.rgb * _RayTraceTransparency + max(0, previousFrame.rgb) * (1 - _RayTraceTransparency);
					#endif

				#else
					#if _IS_RAY_MARCHING || _IS_PROGRESSIVE_MARCHING
						float4 col = renderSdf(ro, rd, noise);
					#else
						float4 col = render(ro, rd, noise);
					#endif

						float4 previousFrame = tex2Dlod(_RayTracing_SourceBuffer, float4(screenUV, 0, 0));
						col.rgb = col.rgb * _RayTraceTransparency + max(0, previousFrame.rgb) *(1 - _RayTraceTransparency);
				#endif


			

						return col;
			}
			ENDCG
		}
	}
			  Fallback "Legacy Shaders/Transparent/VertexLit"
}