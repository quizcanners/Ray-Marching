Shader "RayTracing/Top Down/Light And Shadow"
{
	Properties{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		[HDR]_Color("Color", Color) = (1,1,1,1)
		[KeywordEnum(Radiant, Sharp, Square)] _SHAPE("Shape", Float) = 0
		[Toggle(_IGNORE_HEIGHT)] ignoreHeight("Ignore Y offset", Float) = 0
		[Toggle(_DEBUG)] debugOn("Debug", Float) = 0
		_Range("Range", Range(1,100)) = 1
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
			#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase // useful to have shadows 
			#pragma shader_feature ____ _DEBUG 
			#pragma shader_feature_local _SHAPE_RADIANT _SHAPE_SHARP _SHAPE_SQUARE 
			#pragma shader_feature ___ _IGNORE_HEIGHT 
			

			#pragma target 3.0

			struct v2f {
				float4 pos : 		SV_POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
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
			float _Range;

			/*UNITY_INSTANCING_BUFFER_START(Props)
				UNITY_DEFINE_INSTANCED_PROP(float, _Distance)
				UNITY_INSTANCING_BUFFER_END(Props)*/

			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				//o.normal.xyz = UnityObjectToWorldNormal(v.normal);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				//o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
				//o.screenPos = ComputeScreenPos(o.pos);
				o.color = v.color * _Color;
				return o;
			}

		

			float4 frag(v2f i) : COLOR
			{

				float2 uv = i.texcoord.xy - 0.5;
				float dist = uv.x * uv.x + uv.y * uv.y;

				float alpha;

				float wPosY = (i.worldPos.y - _RayTracing_TopDownBuffer_Position.y) / _Range;

				float sharpness =
				#if _IGNORE_HEIGHT
					1;
				#else
					1/(1 + abs(wPosY)); // Geting softer when further away from ground
				#endif

#if _SHAPE_RADIANT
				#if _IGNORE_HEIGHT
					alpha = smoothstep(0.25,0,dist) /(1+ pow(dist * _Range,2));
				#else 
					alpha = sharpness*smoothstep(0.25,0,dist) / (1 + pow(dist *  (1 + 9 * sharpness), 2));
				#endif
#elif _SHAPE_SHARP
				alpha = smoothstep(0.25, 0, dist);
#else
				alpha = 1;
#endif
				  

				// return -dist; //saturate(dist * dist);

				return i.color * alpha
				#if !_IGNORE_HEIGHT
					* smoothstep(10,0.25, wPosY) * smoothstep(-1.5, 0, wPosY)
				#endif
				;
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"

					
}