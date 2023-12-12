Shader "RayTracing/Skybox"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
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

		Pass{

			CGPROGRAM

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			//#include "PrimitivesScene.cginc"
			

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile  ___ _RAY_MARCH_STARS
			#pragma multi_compile ___ _ROTATE_SKYBOX

			#include "Assets/Ray-Marching/Shaders/Savage_Sampler_Debug.cginc"

			#pragma target 3.0

			struct v2f {
				float4 pos : 		SV_POSITION;
				float3 worldPos : 	TEXCOORD0;
				float3 viewDir: 	TEXCOORD1;
				float4 screenPos : 	TEXCOORD2;
				float2 noiseUV :	TEXCOORD3;
			};

			sampler2D _MainTex;

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




	




			float4 _SkyboxRotation;

			float4 frag(v2f o) : COLOR
			{
		

				float height = _WorldSpaceCameraPos.y;
				//float2 cloudsUv = (o.viewDir.xz - _WorldSpaceCameraPos.xz * 4) / (o.viewDir.y - 500 - height ) + (qc_RND_SEEDS.zw) * 100 ;

				float3 viewDir = normalize(o.viewDir.xyz);
				#if _ROTATE_SKYBOX
					
					_SkyboxRotation.xyz = -_SkyboxRotation.xyz;
					
					viewDir = Rotate (viewDir, _SkyboxRotation);
				#endif

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

				float SUN_EDGE = 0.9998;
				float SUN_EDGE_THICKNESS = 0.0001;

				//float sun = smoothstep(SUN_EDGE - SUN_EDGE_THICKNESS, SUN_EDGE + SUN_EDGE_THICKNESS, dist);


				float4 stars =

#				if _RAY_MARCH_STARS
					AllStars(uv, 0.1, 1)* _StarsVisibility * max(0, 1 - dist01 * dist01) ;
#				else
					0;
#				endif

				//const float PI = 3.14159265359;

				//float angle = (atan2(fromSunUv.x, fromSunUv.y) + PI) / (PI * 2);

			//	float outline = 5  / (abs(SUN_EDGE - dist)*2500 + 5);

				//float subCore = 1 /(1.01 - dist);

				float3 skyColor = SampleSkyBox(-viewDir);

				//return float4(skyColor,1);

				float sun = smoothstep(1, 0, dist);
				sun = (1 / (0.01 + sun * 50000));

				float4 sky = float4(skyColor + stars, 1);
				float isUp = smoothstep(0,0.1,-viewDir.y);

				float4 finalColor = sky; 

				finalColor.rgb += _LightColor0.rgb * sun * isUp;

				if (_qc_FogVisibility > 0)
				{
					float3 fogCol = GetAvarageAmbient(viewDir);

					finalColor.rgb = lerp(finalColor, fogCol, (1-isUp) * _qc_FogVisibility);
				}



				return 	finalColor;
			}
			ENDCG
		}
	}
	 Fallback "Legacy Shaders/Transparent/VertexLit"
}