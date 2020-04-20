Shader "RayTracing/RayTracing_Visualize"
{
	Properties{
		 _MainTex("Albedo (RGB)", 2D) = "white" {}
	}

		SubShader{

			Tags{
				"Queue" = "Geometry"
				"IgnoreProjector" = "True"
				"RenderType" = "Opaque"
			}

			ColorMask RGBA
			Cull Off
			ZWrite Off
			ZTest Off
			Blend One Zero//SrcAlpha OneMinusSrcAlpha

			Pass{

				CGPROGRAM

				#include "UnityCG.cginc"
				#include "Lighting.cginc"
				#include "RayTrace_Scene.cginc"
				#include "Assets/Tools/Playtime Painter/Shaders/quizcanners_cg.cginc"

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile __ RAY_TRACE_BLUR
				#pragma target 3.0

				struct v2f {
					float4 pos : 		SV_POSITION;
					float4 screenPos : 	TEXCOORD2;
				};

				sampler2D _MainTex;
				uniform float4 _MainTex_TexelSize;

				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					o.pos = UnityObjectToClipPos(v.vertex);
					o.screenPos = ComputeScreenPos(o.pos);
					return o;
				}

				float4 frag(v2f o) : COLOR{

					//_RayTraceTransparency

					float2 screenUV = o.screenPos.xy / o.screenPos.w;

					float4 col = tex2Dlod(_MainTex, float4(screenUV,0,0));


//#if RAY_TRACE_BLUR
					float2 off = _MainTex_TexelSize.xy * 1.5;

					#define R(kernel) tex2Dlod( _MainTex, float4(screenUV + kernel* off  ,0,0))

					float4 blur =	
						R(float2(-1, 0)) + 
						R(float2( 1, 0)) + 
						R(float2( 0, -1)) + 
						R(float2( 0, 1)) +
						R(float2( 1, 1)) +
						R(float2(-1,-1)) +
						R(float2(1, -1)) +
						R(float2(-1, 1)) + col;

					blur /= 9;

	//				_RayTraceTransparency *= 2;

					col.rgb = col.rgb * (1 - _RayTraceTransparency) + blur * _RayTraceTransparency;
//#endif
					// gamma correction
					col = max(0, col - 0.004);
					col = (col*(6.2*col + .5)) / (col*(6.2*col + 1.7) + 0.06);

					return col;
				}
				ENDCG
			}
		}
	 Fallback "Legacy Shaders/Transparent/VertexLit"
}