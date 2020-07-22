Shader "RayTracing/Geometry/With Reflection"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_Gloss("Glossyness (RGB)", 2D) = "white" {}
		_Normal("Noraml (RGB)", 2D) = "bump" {}
		 [Toggle(_DEBUG)] debugOn("Debug", Float) = 0
	}

	SubShader
	{

		Tags
		{
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
			"LightMode" = "ForwardBase"
		}

		ColorMask RGB
		Cull  Back
		ZWrite On
		ZTest On

		Pass
		{
			CGPROGRAM

			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			#define RENDER_DYNAMICS
			#include "PrimitivesScene_Sampler.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase // useful to have shadows 

			#pragma shader_feature_local ____ _DEBUG 

			#pragma target 3.0

			struct v2f 
			{
				float4 pos			: SV_POSITION;
				float3 worldPos		: TEXCOORD0;
				float3 normal		: TEXCOORD1;
				float3 viewDir		: TEXCOORD3;
				//float4 screenPos	: TEXCOORD4;
				float2 texcoord		: TEXCOORD4;
				float4 wTangent		: TEXCOORD5;
				float2 topdownUv	: TEXCOORD6;

				SHADOW_COORDS(7)
				float4 color		: COLOR;
			};

			sampler2D _MainTex;
			sampler2D _Gloss;
			sampler2D _Normal;
			float4 _Normal_ST;


			v2f vert(appdata_full v) 
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				o.texcoord = v.texcoord.xy;
				o.normal.xyz = UnityObjectToWorldNormal(v.normal);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				//o.screenPos = ComputeScreenPos(o.pos);
				o.color = v.color;

				o.wTangent.xyz = UnityObjectToWorldDir(v.tangent.xyz);
				o.wTangent.w = v.tangent.w * unity_WorldTransformParams.w;

				o.topdownUv = (o.worldPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;

				
				TRANSFER_SHADOW(o);
				return o;
			}


			float4 frag(v2f o) : COLOR
			{
				o.viewDir.xyz = normalize(o.viewDir.xyz);

				float4 tex = tex2D(_MainTex, o.texcoord);
				float gloss = tex2D(_Gloss, o.texcoord).r;
				float3 tnormal = UnpackNormal(tex2D(_Normal, TRANSFORM_TEX(o.texcoord, _Normal)));

				float3 normal = o.normal.xyz;
				ApplyTangent(normal, tnormal, o.wTangent);

				float3 position = o.worldPos.xyz;

				float outOfBounds;
				float4 bake = SampleVolumeOffsetByNormal(position, normal, outOfBounds);
				bake = lerp(bake, _RayMarchSkyColor + (unity_FogColor) * 0.1, outOfBounds);

				float3 lightDir = normalize(_WorldSpaceLightPos0.xyz * 1000 - position);
				float lightAtten = max(0, dot(lightDir, normal));
				float shadow = lightAtten * SHADOW_ATTENUATION(o);

				float3 dynamicLight = 0;

				float4 topDown = tex2Dlod(_RayTracing_TopDownBuffer, float4(o.topdownUv + normal.xz * _RayTracing_TopDownBuffer_Position.w, 0, 0));
				float topDownVisible = smoothstep(3, 0, abs(_RayTracing_TopDownBuffer_Position.y - o.worldPos.y));
				topDown *= topDownVisible;

				float ambientBlock = max(0.25f, 1 - topDown.a * 0.25);

				shadow *= ambientBlock;
				bake *= ambientBlock;

				dynamicLight += topDown.rgb;

				float3 lightColor = _LightColor0.rgb * shadow;

				float4 avgColor = _RayMarchSkyColor * 0.75  + _LightColor0 * 0.5 + (unity_FogColor) * 0.15;


				float3 reflection;

	
				if (gloss > 0.5) 
				{
					float toview = max(0, dot(normal, o.viewDir.xyz));
					float3 reflectedRay = -normalize(o.viewDir.xyz - 2 * (toview)*normal);

					float3 normalTmp;
					float4 mat = 0; // RGB = color
					float2 MIN_MAX = float2(0.0001, MAX_DIST_EDGE);
					float3 ro = position;
					float3 res = worldhit(ro, reflectedRay, MIN_MAX, normalTmp, mat);

					float type = res.z;
					float reflectedDistance = res.y;

					float3 emmissiveReflectedLight = 0;
					float3 reflectionPos;

					if (type >= SUBTRACTIVE)
					{
						ro += (reflectedDistance - 0.001) * reflectedRay;
						float insideSub = worldhitSubtractive(ro, reflectedRay, MIN_MAX);

						reflectedDistance += insideSub;
						ro += insideSub  * reflectedRay;
						res = worldhit(ro, reflectedRay, MIN_MAX, normalTmp, mat);

						reflectedDistance += res.y;
						reflectionPos = position + reflectedDistance * reflectedRay;

					} else if (type >= EMISSIVE) 
					{
						emmissiveReflectedLight = mat.rgb;
						reflectionPos = position + reflectedDistance * reflectedRay;

					/* } else if (type >= METAL)
					{
						ro += reflectedDistance * reflectedRay;
						reflectedRay = reflect(reflectedRay, normalTmp);
						res = worldhit(ro, reflectedRay, MIN_MAX, normalTmp, mat);
						reflectionPos = ro + res.y * reflectedRay;*/
					} else 
					{
						reflectionPos = position + reflectedRay * reflectedDistance;// *gloss;
					}

					//normalTmp = EstimateNormal(reflectionPos);

					float4 sdfNnD = SdfNormalAndDistance(reflectionPos, reflectedDistance  *0.01);


					normalTmp = sdfNnD.rgb; // *sdfNnD.w * 50;

					float outOfBoundsRefl;
					float4 bakeReflected = SampleVolumeOffsetByNormal(reflectionPos, normalTmp, outOfBoundsRefl);

					//bakeReflected *= smoothstep(-0.001, 0, sdfNnD.w);

					float2 reflTdUv = (reflectionPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;

					float4 topDownRefl = tex2Dlod(_RayTracing_TopDownBuffer, float4(reflTdUv, 0, 0));
					float topDownReflVisible = smoothstep(3, 0, abs(_RayTracing_TopDownBuffer_Position.y - reflectionPos.y));
					topDownRefl *= topDownReflVisible;
					bakeReflected.rgb *= max(0.25f, 1 - topDownRefl.a * 0.25);

					bakeReflected.rgb += topDownRefl.rgb;


			
					
					//normalTmp

					float shadow = SampleShadow(reflectionPos, normalTmp);

					float3 colorReflected = _RayMarchSkyColor * (1 + max(0, normalTmp.y)) * 0.5;
					
					float reflectedDirectional = max(0, dot(normalTmp, _WorldSpaceLightPos0.xyz));

					colorReflected += (unity_FogColor) * 0.075;

					bakeReflected.rgb = lerp(bakeReflected.rgb, colorReflected, outOfBoundsRefl);
					bakeReflected.rgb += shadow * _LightColor0.rgb * reflectedDirectional; // Baked color has reduced directional

					bakeReflected.rgb *= mat.rgb;
					bakeReflected.rgb += emmissiveReflectedLight;
					

					float reflectedSkyAmount = saturate(1 - reflectedDistance / _MaxRayMarchDistance);
					float3 reflectedSkyCol = lerp(unity_FogColor.rgb*1.5, _RayMarchSkyColor.rgb*2, reflectedRay.y);
					reflection = lerp(bakeReflected.rgb, reflectedSkyCol, 1 - reflectedSkyAmount);

					float lightRelected = gloss / ((1.00001 - saturate(dot(reflectedRay, lightDir))) * 1000);
					reflection = (2 - max(0, dot(o.viewDir.xyz, normal))) * (reflection + lightColor * lightRelected * 64) * 0.5;

					reflection = lerp(reflection, avgColor.rgb, smoothstep(0.6, 0.5, gloss));

					//reflection *= shadow;

				}// else 
				//#endif
				//{
				//	reflection = avgColor.rgb;
				//}

				float4 col = 1;

				float3 ambient = dynamicLight + bake + lightColor;

				col.rgb = lerp(tex.rgb * ambient.rgb, reflection,  gloss);

				ColorCorrect( col.rgb);

				float3 mix = col.gbr * col.brg;
				col.rgb += mix.rgb * 0.02;

				float bottomFog = smoothstep(-0.35, -0.02, o.viewDir.y);
				float dist01 = (1 - saturate((_ProjectionParams.z - length(o.worldPos.xyz - _WorldSpaceCameraPos.xyz)) / _ProjectionParams.z)) * bottomFog;
				col.rgb = lerp(col.rgb, unity_FogColor.rgb, dist01);

				return 	col;
			}
			ENDCG
		}
		UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}
