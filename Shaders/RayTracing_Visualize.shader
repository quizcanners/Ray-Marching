Shader "RayTracing/Screen Space/Visualize"
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

			#include "PrimitivesScene.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile __ RT_MOTION_TRACING 

			struct v2f {
				float4 pos : 		SV_POSITION;
				float4 screenPos : 	TEXCOORD2;
			};

			uniform sampler2D _MainTex;
			uniform sampler2D _RayTracing_TargetBuffer;
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

				float4 col = tex2Dlod(_RayTracing_TargetBuffer, float4(screenUV,0,0));


#if RT_MOTION_TRACING
				float2 off = _RayTracing_TargetBuffer_ScreenFillAspect.zw * 1.5;

				float4 blur;
				float same;

				#define R(kernel) blur = tex2Dlod( _RayTracing_TargetBuffer, float4(screenUV + kernel* off  ,0,0)); same = 1 - min(1, abs(blur.a - col.a)*0.01); col.rgb = max(col.rgb, blur.rgb * same * 0.55)

				//float4 blur =	
				R(float2(-1, 0));
				R(float2(1, 0));
				R(float2(0, -1));
				R(float2(0, 1));
				R(float2(1, 1));
				R(float2(-1, -1));
				R(float2(1, -1));
				R(float2(-1, 1)); //col;

				//col.rgb = blur /= 9;
#endif

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