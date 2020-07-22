Shader "RayTracing/Top Down/Shadow"
{
	Properties{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
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

			#include "UnityCG.cginc"

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
				//float3 normal : 	TEXCOORD1;
				float2 texcoord : 	TEXCOORD2;
				//float3 viewDir: 	TEXCOORD3;
				//float4 screenPos : 	TEXCOORD4;
				float4 color: 		COLOR;
			};


			uniform float4 _MainTex_ST;
			sampler2D _MainTex;
			float4 _Color;

			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				//o.normal.xyz = UnityObjectToWorldNormal(v.normal);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				//o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
				//o.screenPos = ComputeScreenPos(o.pos);
				o.color = v.color * _Color;
				return o;
			}


			float4 frag(v2f o) : COLOR
			{
				float2 uv = o.texcoord.xy - 0.5;
				float dist = uv.x * uv.x + uv.y * uv.y;

				float alpha;

#if _SHAPE_RADIANT
				alpha = smoothstep(4, 512, (1 / (dist + 0.001)));
#elif _SHAPE_SHARP
				alpha = smoothstep(0.25, 0, dist);
#else
				alpha = 1;
#endif
				  

				return o.color * alpha * smoothstep(10,0.25, o.worldPos.y) * smoothstep(-1.5, 0, o.worldPos.y);
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"

					
}