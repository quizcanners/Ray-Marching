Shader "RayTracing/RayTracing"
{
	Properties{
		 _MainTex("Albedo (RGB)", 2D) = "white" {}
		 [Toggle(_DEBUG)] debugOn("Debug", Float) = 0
	}

		SubShader{

			Tags{
				"Queue" = "Geometry"
				"IgnoreProjector" = "True"
				"RenderType" = "Opaque"
			}

			ColorMask RGBA
			Cull Back
			ZWrite On
			ZTest Off
			Blend SrcAlpha OneMinusSrcAlpha

			Pass{

				CGPROGRAM

				#include "UnityCG.cginc"
				#include "Lighting.cginc"
				#include "RayTrace_Scene.cginc"
				#include "Assets/Tools/Playtime Painter/Shaders/quizcanners_cg.cginc"

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase // useful to have shadows 
				#pragma shader_feature ____ _DEBUG 

				#pragma target 3.0

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

				float4 frag(v2f o) : COLOR{

					float3 ro = _WorldSpaceCameraPos.xyz; 
					float3 rd = -normalize(o.viewDir.xyz);

					float4 noise = tex2Dlod(_Global_Noise_Lookup, float4(o.screenPos.xy * 13.5 + float2(_SinTime.w, _CosTime.w) * 32, 0, 0));

					// AA
					rd += (noise.rgb-0.5) * (_ScreenParams.z-1) * 2;


					// DOF
					float fpd = 1;
					float3 fp = ro + rd * fpd;
					ro = ro + normalize(noise.rgb - 0.5) * 0.02; //* float3(randomInUnitDisk(seed), 0.)*.001;
					rd = normalize(fp - ro);

					//float2 viewTangent = mul((float3x3) UNITY_MATRIX_IT_MV, rd).xy;

					//rd.xy += viewTangent * (noise.rg - 0.5) * 0.1;


					float3 col = 	render(ro, rd, noise);

					// gamma correction
					col = max(0, col - 0.004);
					col = (col*(6.2*col + .5)) / (col*(6.2*col + 1.7) + 0.06);




					return float4(col, 0.01);
				}
				ENDCG
			}
		}
	 Fallback "Legacy Shaders/Transparent/VertexLit"
}