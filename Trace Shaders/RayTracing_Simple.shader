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
			#pragma multi_compile __ RT_USE_DIELECTRIC
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

			uniform float _RayTraceDofDist;
			uniform float _RayTraceDOF;

			float4 frag(v2f o) : COLOR{

				float3 ro = _WorldSpaceCameraPos.xyz; 
				float3 rd = -normalize(o.viewDir.xyz);

				float4 noise = tex2Dlod(_Global_Noise_Lookup, float4(o.screenPos.xy * 13.5 + float2(_SinTime.w, _CosTime.w) * 32, 0, 0));

				// AA
				rd += normalize(noise.rgb-0.5)*noise.a * (_ScreenParams.z-1) * 2;


				// DOF
		
					float3 fp = ro + rd * _RayTraceDofDist;
					ro = ro + normalize(noise.rgb - 0.5) * _RayTraceDOF;
					rd = normalize(fp - ro);


				float3 col = 	render(ro, rd, noise);

				return float4(col, _RayTraceTransparency);
			}
			ENDCG
		}
	}
	 Fallback "Legacy Shaders/Transparent/VertexLit"
}