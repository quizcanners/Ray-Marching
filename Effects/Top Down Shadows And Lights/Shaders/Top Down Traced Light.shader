Shader "RayTracing/Top Down/Traced"
{
	Properties{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		[HDR]_Color("Color", Color) = (1,1,1,1)
		[KeywordEnum(Radiant, Sharp, Square)] _SHAPE("Shape", Float) = 0
		[Toggle(_DEBUG)] debugOn("Debug", Float) = 0
	}

	SubShader{

		Tags{
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
		}

		ColorMask RGBA
		Cull Off
		ZWrite Off
		ZTest Off
		Blend One One

		Pass{

			CGPROGRAM

			#define RENDER_DYNAMICS
			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler.cginc"
			
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase // useful to have shadows 
			#pragma shader_feature ____ _DEBUG 
			#pragma shader_feature_local _SHAPE_RADIANT _SHAPE_SHARP _SHAPE_SQUARE 

			#pragma target 3.0

			struct v2f {
				float4 pos : 		SV_POSITION;
				float3 worldPos : 	TEXCOORD0;
				float2 texcoord : 	TEXCOORD2;
				float4 color: 		COLOR;
			};


			uniform float4 _MainTex_ST;
			sampler2D _MainTex;
			float4 _Color;
			float4 _CenterPos;

			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.color = v.color * _Color;
				return o;
			}


			float4 frag(v2f i) : COLOR
			{
				float3 toCenter = _CenterPos.xyz - i.worldPos;

				if (RaycastStaticPhisics(i.worldPos, normalize(toCenter + 0.0001), float2(0.00001, length(toCenter))))
				{
					return 0;
				}

				//return float4(toCenter, 1);

				float2 uv = i.texcoord.xy - 0.5;
				float dist = uv.x * uv.x + uv.y * uv.y;

				float alpha;

				float wPosY = i.worldPos.y - _RayTracing_TopDownBuffer_Position.y;

#if _SHAPE_RADIANT
				alpha = smoothstep(4, 512, (1 / (dist + wPosY * wPosY * 0.01 + 0.001)));//alpha = smoothstep(4, 512, (1 / (dist + 0.001)));
#elif _SHAPE_SHARP
				alpha = smoothstep(0.25, 0, dist);
#else
				alpha = 1;
#endif
				  

				return i.color * alpha * smoothstep(10,0, wPosY) * smoothstep(-1.5, 0, wPosY);
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"

					
}