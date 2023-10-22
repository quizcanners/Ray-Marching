Shader "RayTracing/Geometry/Debug"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
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

			#include "PrimitivesScene_Sampler.cginc"

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
				UNITY_SETUP_INSTANCE_ID(v);
				return o;
			}

	
			float4 frag(v2f o) : COLOR
			{

				float scale = _RayMarchingVolumeVOLUME_POSITION_OFFSET.w;

				float4 tex = tex2D(_MainTex, o.texcoord.xy) * o.color;

				tex.rgb = lerp(o.color.rgb, tex.rgb, o.color.a);

				float2 screenUV = o.screenPos.xy / o.screenPos.w;

	
		

				float outOfBounds;
				float4 col = SampleVolume(o.worldPos, outOfBounds);

				col = lerp(col, 0.5, outOfBounds);

				//col.rgb = lerp(col.rgb,  _RayMarthMinLight.rgb * deepIndide, internal);

			//	return col.a * 0.001;

				//return light;

				//float4 col = light;//(light + unity_FogColor *internal);
				//col = max(col, float4(0.1, 0.1, 0.1, 0));
				//return useSdf;

			//	float unFogged = smoothstep(0.5, 0, outOfBounds);//min(1, col.a/100);

			
			//	col.rgb = lerp(unity_FogColor.rgb, tex.rgb * col.rgb, unFogged);// *internal;
				
				//return tex;

				return col;
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
}