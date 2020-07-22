Shader "RayTracing/Skybox"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_Clouds("Clouds (RGB)", 2D) = "clear" {}
		_CloudsBump("Clouds (Bump)", 2D) = "norm" {}
		_CloudFluff("Cloud Fluff (RGB)", 2D) = "clear" {}
		//_SunRays("Sun Rays (RGB)", 2D) = "clear" {}
		//_SunSurface("Sun Surface (RGB)", 2D) = "white" {}
		_Thickness("Cloud Thinness", Range(0.1,1)) = 0.5
		[Toggle(_CLOUDS)] useClouds ("Use Clouds", Float) = 0  
		_Test("Test", Range(0,1)) = 0.5
	}

	SubShader
	{

		Tags
		{
			
			"QUEUE" = "Background"
			"RenderType" = "Background"
			"PreviewType" = "Skybox"
		}

		ColorMask RGB
		ZWrite Off
		Cull Off
		//Blend SrcAlpha OneMinusSrcAlpha

		Pass{

			CGPROGRAM

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "PrimitivesScene.cginc"
			

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase // useful to have shadows 
			#pragma multi_compile  ___ _RAY_MARCH_STARS
			#pragma shader_feature ___ _CLOUDS

			#pragma multi_compile ___ _qc_Rtx_MOBILE

			#pragma target 3.0

			struct v2f {
				float4 pos : 		SV_POSITION;
				float3 worldPos : 	TEXCOORD0;
				float3 viewDir: 	TEXCOORD1;
				float4 screenPos : 	TEXCOORD2;
				float2 noiseUV :	TEXCOORD3;
			};

			sampler2D _MainTex;
			//sampler2D _SunRays;
			//sampler2D _SunSurface;
			sampler2D _Clouds;
			sampler2D _CloudsBump;
			sampler2D _CloudFluff;

			float4 _Global_Noise_Lookup_TexelSize;
			float _StarsVisibility;
			float _Thickness;
			float _Test;
			float4 qc_RND_SEEDS;

			v2f vert(appdata_full v) 
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.screenPos = ComputeScreenPos(o.pos);
				o.noiseUV = o.screenPos.xy * (123.12345678) + float2(_SinTime.x, _CosTime.y) * 32.12345612;

				return o;
			}

			float4 StarFromNoiseMask(float2 starsUvTiled, float w, float visibility)
			{
				float2 noiseUv = (starsUvTiled) * 0.01 + 10;
				float2 starUv = (noiseUv * _Global_Noise_Lookup_TexelSize.zw) % 1 - 0.5;
				float4 starGrid = tex2Dlod(_Global_Noise_Lookup, float4(noiseUv, 0, 0));
				float brightness = starGrid.b;
				float2 uvOff = starGrid.rg - 0.5;
				float2 starOff = starUv + uvOff * 0.6;

				float starSdf =	0.005 * brightness / length(starOff);

				starSdf *= smoothstep(0.005, 0.1, starSdf) * visibility;

				float3 starCol = float3(0.6, 0.3, 0.7) + starGrid.rgb;
				return float4(starCol * starSdf * step(0.7, brightness), 1);
			}

			float4 AllStars(float2 starsUvTiled, float w, float visibility)
			{
				const float CLOSER_STARS = 0.7;
				const float MID_STARS = CLOSER_STARS + 0.9;
				const float FAR_STARS = MID_STARS + 1.1;

				return saturate(
						StarFromNoiseMask(starsUvTiled * CLOSER_STARS, w, visibility)+
						StarFromNoiseMask(2 + starsUvTiled * MID_STARS , w, visibility)
						+ StarFromNoiseMask(10 + starsUvTiled * FAR_STARS , w, visibility)
					) * 0.4
					;
			}

			float sdGyroid(float3 pos) 
			{
				return dot(sin(pos), cos(pos.zxy));
			}

			float2 Rot(float2 uv, float angle) 
			{
				float si = sin(angle);
				float co = cos(angle);
				return float2(co * uv.x - si * uv.y, si * uv.x + co * uv.y);
			}


			float4 frag(v2f o) : COLOR
			{
					float height = _WorldSpaceCameraPos.y;
				float2 cloudsUv = (o.viewDir.xz - _WorldSpaceCameraPos.xz * 4) / (o.viewDir.y - 500 - height ) + (qc_RND_SEEDS.zw) * 100 ;

				float3 viewDir = normalize(o.viewDir.xyz);

#				if _CLOUDS
			
				float2 wind = _Time.x * 0.05;

				float2 mainCloudUv =  cloudsUv * 0.1 + wind * 0.102;
				float4 cloudMain = tex2D(_CloudFluff, mainCloudUv);
				float3 normal = UnpackNormal(tex2D(_CloudsBump,mainCloudUv)).xzy;

				float2 uvA = cloudsUv * 0.06 - float2(wind.x, -wind.y) * 0.31; //  - normal.xz*(0.015);// + cloudMain.a * 0.02;
				float4 cloudA = tex2D(_Clouds,  uvA);
				float3 normalA = UnpackNormal(tex2D(_CloudsBump,uvA)).xzy;
			
				float oscelation = smoothstep(-2,2,sdGyroid(float3(cloudsUv, _Time.x * 3))); 

				cloudA.a = lerp(cloudA.a, cloudMain.a, oscelation); 
				normal = lerp(normalA, normal, oscelation); 

				const float pii = 3.14159265359;
				const float pi2 = pii * 2;
				float radUvX = (atan2(viewDir.x, viewDir.z) + qc_RND_SEEDS.x) / pi2;
				float2 radialUv = float2(radUvX ,viewDir.y*0.5 -_Time.x*0.01);
				float4 radialClouds = tex2Dlod(_Clouds, float4(radialUv,0,0));
				float useRadial = smoothstep(0.4, 0, -viewDir.y);

				cloudA =  lerp( cloudA,  radialClouds, useRadial);
				normal = lerp (normal, float3(0,1,0), useRadial);

				float alpha = cloudA.a;

				float cloudTiny = tex2D(_CloudFluff, cloudsUv * 6 
					+ normal.xz * 3 * alpha 
					+ wind*8.5).a;

				float2 offset = float2(alpha, cos(oscelation)) ;

				float cloudTinyA = tex2D(_CloudFluff, cloudsUv * 11 - cloudTiny*0.2
					+ offset * 2* alpha 
					- wind*9.5).a;

				cloudTiny = cloudTiny * cloudTinyA;
				
				float showTiny = smoothstep(0.5, 0, cloudA.a);

				normal.xz *= (1 + cloudTiny * (0.5+showTiny));

				normal = normalize(normal);

				float4 cloudFluff = cloudA; 
				
				cloudFluff.a = lerp(cloudFluff.a, cloudTiny * alpha, showTiny);

				_StarsVisibility *= (1- cloudFluff.a);

#				endif


				float2 uv = (viewDir.xz * (8 + viewDir.y * 3) + 100);

				float3 lp = -_WorldSpaceLightPos0.xyz;

				float2 sunUv = (lp.xz * (8 + lp.y * 3) + 100);
			

				float4 noise = tex2Dlod(_Global_Noise_Lookup, 
					float4(o.noiseUV.xy//uv - float2(_Time.x * 4, _Time.x * 7.23)
						, 0, 0)
				
				) - 0.5;

				uv += noise.rg * 0.002;

				

				float dist =  dot(-viewDir.xyz, _WorldSpaceLightPos0.xyz);

				float dist01 = smoothstep(0.5, 1, dist);

				float2 fromSunUv = (uv - sunUv);

			
				float SUN_EDGE = 0.9975;
				float SUN_EDGE_THICKNESS = 0.0005;

				float sun = smoothstep(SUN_EDGE - SUN_EDGE_THICKNESS, SUN_EDGE + SUN_EDGE_THICKNESS, dist);

				float4 stars =

#				if _RAY_MARCH_STARS && !_qc_Rtx_MOBILE
					AllStars(uv, 0.1, 1)* _StarsVisibility * max(0, 1 - dist01 * dist01) ;
#				else
					0;
#				endif

				const float PI = 3.14159265359;

				float angle = (atan2(fromSunUv.x, fromSunUv.y) + PI) / (PI * 2);

				//float4 sunRays = tex2Dlod(_SunRays, float4(angle, -(1-dist* dist* dist) + _Time.x * 0.1, 0, 0));

				float outline = 5  / (abs(SUN_EDGE - dist)*2500 + 5);

				//float4 sunCol = tex2D(_SunSurface, fromSunUv);

				float subCore = //max(0,
					0.01 /(1.1 - dist);
				//smoothstep(0.99 - 0.10* brightness, 1, dist) * 0.2);

				float4 sky = float4(_RayMarchSkyColor.rgb + stars, 1);
					float isUp = smoothstep(0,0.1,-viewDir.y);

#				if _CLOUDS

				float toSunLight = smoothstep(0,1, dot(normal.xz, normalize(fromSunUv)));


				float lightTrough = smoothstep(0.9, 0,cloudFluff.a);
				
				cloudFluff.rgb =
				(cloudFluff.rgb + 1) * 0.25 * 
				lerp(  
					_RayMarchSkyColor.rgb,
					  unity_FogColor.rgb
					, alpha)
					// * 0.5 // * (1-alpha)
				+ 
				//(cloudFluff.rgb + 0.5) *
					_LightColor0.rgb *
				(
					lerp ( toSunLight * 2 , lightTrough * subCore * 50 , dist01)
					);

			

				cloudFluff.a *= isUp;

#				endif

				float4 finalColor = sky; 


				

#			if _CLOUDS

			/*	float3 sunLight =
					_LightColor0.rgb * (
						+subCore
						)
					;


				finalColor.rgb += sunLight * isUp;*/

				finalColor = lerp(finalColor, cloudFluff, smoothstep(0, 0.75, cloudFluff.a));

#			endif
				
				finalColor.rgb += _LightColor0.rgb * subCore * isUp;
			
				float3 mix = finalColor.gbr * finalColor.brg;
					finalColor.rgb += mix * 0.2; // + max(0, toView)*10;

#ifdef UNITY_COLORSPACE_GAMMA
				finalColor.rgb += (noise.rgb) * 0.02;
#else
				finalColor.rgb += (noise.rgb) * 0.0075;
#endif

				finalColor = lerp(unity_FogColor, finalColor, smoothstep(0,0.1,-viewDir.y));

				return 	finalColor;
			}
			ENDCG
		}
	}
	 Fallback "Legacy Shaders/Transparent/VertexLit"
}