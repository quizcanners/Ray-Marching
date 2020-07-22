Shader "RayTracing/Geometry/Simple"
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

		Pass{

			CGPROGRAM

			#include "PrimitivesScene.cginc"

			#pragma vertex vert
			#pragma fragment frag

			struct v2f {
				float4 pos		: SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float3 normal : TEXCOORD2;
				float4 screenPos : TEXCOORD3;
				fixed4 color : COLOR;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.normal.xyz = UnityObjectToWorldNormal(v.normal);
				o.screenPos = ComputeScreenPos(o.pos);
				o.color = v.color;
				return o;
			}

	
			float4 frag(v2f o) : COLOR{

				float scale = _RayMarchingVolumeVOLUME_POSITION_OFFSET.w;

				float4 tex = tex2D(_MainTex, o.texcoord.xy) * o.color;

			//	tex.rgb = tex.rgb * o.color.a + o.color.rgb * (1- o.color.a);

				float2 screenUV = o.screenPos.xy / o.screenPos.w;

				float4 normalAndDist = SdfNormalAndDistance(o.worldPos); 

				float distToCenter = max(0, -(normalAndDist.w) * scale);

				float internal = min(distToCenter, 1);

				float deepIndide = min(1, 1 / (distToCenter*0.1 + 1)) ;

				float outOfBounds;
				float4 col = SampleVolume(_RayMarchingVolume, o.worldPos
					+ o.normal.xyz  * scale * 0.5
				, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
				, _RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);

				//col.rgb = col.rgb * (1- internal) + _RayMarthMinLight.rgb * internal * deepIndide;

				float unFogged = smoothstep(0.5, 0, outOfBounds);

				col.rgb =
					lerp(unity_FogColor.rgb, tex.rgb * col.rgb, unFogged);
					//(tex.rgb * col.rgb * unFogged + unity_FogColor.rgb * (1 - unFogged));

				return col;
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
}