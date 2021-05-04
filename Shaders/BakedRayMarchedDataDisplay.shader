Shader "RayTracing/Geometry/BakedRayMarchedDataDisplay"
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
		//ZWrite On
		//ZTest Off
		//Blend One Zero //SrcAlpha OneMinusSrcAlpha

		Pass{

			CGPROGRAM

			#include "PrimitivesScene.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile __ RT_USE_DIELECTRIC
			#pragma multi_compile __ RT_USE_CHECKERBOARD
			#pragma multi_compile __ _IS_RAY_MARCHING

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
				//o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.normal.xyz = UnityObjectToWorldNormal(v.normal);
				o.screenPos = ComputeScreenPos(o.pos);
				o.color = v.color;
				return o;
			}

	
			float4 frag(v2f o) : COLOR{

				float scale = _RayMarchingVolumeVOLUME_POSITION_OFFSET.w;

				/*float3 worldPos = volumeUVtoWorld(o.texcoord.xy
					, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
					, _RayMarchingVolumeVOLUME_H_SLICES);
					*/

				float4 tex = tex2D(_MainTex, o.texcoord.xy);

				//return o.color;

				tex.rgb = tex.rgb * o.color.a + o.color.rgb * (1- o.color.a);

				float2 screenUV = o.screenPos.xy / o.screenPos.w;


				//float3 noise = tex2Dlod(_Global_Noise_Lookup, float4(screenUV * 13.5 + float2(_SinTime.w, _CosTime.w) * 32, 0, 0));

				//	clip(tex.a - 0.1);

				float4 normalAndDist = SdfNormalAndDistance(o.worldPos); //o.normal.xyz *

			    float internal = 1 - saturate(-normalAndDist.w * scale);

				//return   internal;

				//float difference = dot(normalAndDist.rgb, o.normal.xyz) - internal;

				//return difference;
				//float internal = saturate(-normalAndDist.w);

				//float useSdf = min(1, internal * scale * 5999);

				float4 light = SampleVolume(_RayMarchingVolume, o.worldPos
					// + (useSdf * normalAndDist.rgb * internal + o.normal.xyz * (1-useSdf)) *
					//+ o.normal.xyz *scale
				, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
				, _RayMarchingVolumeVOLUME_H_SLICES);

				//return light;

				float4 col = light;//(light + unity_FogColor *internal);
				//col = max(col, float4(0.1, 0.1, 0.1, 0));
				//return useSdf;

				float unFogged = min(1, col.a);

			
				col.rgb = (tex.rgb * col.rgb * unFogged + unity_FogColor.rgb * (1 - unFogged)) *internal;
				
				//return tex;

				return col;
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
}