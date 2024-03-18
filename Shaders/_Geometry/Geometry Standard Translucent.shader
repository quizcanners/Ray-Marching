Shader "QcRendering/Geometry/Standard Translucent"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		_BumpMap("Normal Map", 2D) = "bump" {}

		[KeywordEnum(None, MADS, Separate)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}

		[Toggle(_AMBIENT_IN_UV2)] ambInuv2("Ambient mapped to UV2", Float) = 0
		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0

	//	[KeywordEnum(None, Unity, VertexTraced, PixelTraced)] _SHADOW("Shadow", Float) = 0

		[Toggle(_MICRODETAIL)] microdetail("Use Microdetail", Float) = 0
		_MicrodetailMap("Microdetail Map", 2D) = "white" {}

		[Toggle(_SIMPLIFY_SHADER)] simplifyShader("Simplify Shader", Float) = 0

		[Toggle(_PARALLAX)] parallax("Parallax", Float) = 0
		_ParallaxForce("Parallax Amount", Range(0.001,0.3)) = 0.01

		[Toggle(_OFFSET_BY_HEIGHT)] heightOffset("Offset By Height", Float) = 0
		_HeightOffset("Height Offset", Range(0.01,0.3)) = 0.2

		_SubSurface("Sub Surface Color", Color) = (1,1,1,0)

		[Toggle(_MIRROR)] isMirror("Mirror", Float) = 0

		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0

	}

	Category
	{
		Tags
		{
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
			"LightMode" = "ForwardBase"
		}

		SubShader
		{

		


			Pass
			{
				ColorMask RGBA
				Cull Back

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				//#pragma target 3.0
				#pragma multi_compile_instancing

				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				
				#pragma multi_compile ___ _qc_IGNORE_SKY

				#pragma shader_feature_local ___ _OFFSET_BY_HEIGHT
				#pragma shader_feature_local ___ _MIRROR
				#pragma shader_feature_local ___ _MICRODETAIL
				#pragma shader_feature_local ___ _AMBIENT_IN_UV2
				#pragma shader_feature_local _AO_NONE _AO_MADS _AO_SEPARATE
				#pragma shader_feature_local ___ _COLOR_R_AMBIENT
				#pragma shader_feature_local ___ _PARALLAX

				#pragma shader_feature_local ___ _SHOWUVTWO
				#pragma shader_feature_local ___ _SIMPLIFY_SHADER


				//#pragma shader_feature_local _SHADOW_NONE _SHADOW_UNITY  _SHADOW_VERTEXTRACED _SHADOW_PIXELTRACED

				#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
		
				#define RENDER_DYNAMICS
		
				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Transparent.cginc"
				#include "AutoLight.cginc"

				struct v2f 
				{
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float2 texcoord1	: TEXCOORD1;
					float3 worldPos		: TEXCOORD2;
					float3 normal		: TEXCOORD3;
					float4 wTangent		: TEXCOORD4;
					float3 viewDir		: TEXCOORD5;
					SHADOW_COORDS(6)
					float4 traced : TEXCOORD7;
				
#if _PARALLAX 
					float3 tangentViewDir : TEXCOORD8; // 5 or whichever is free
#endif
					fixed4 color : COLOR;
				};

				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;

			


				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.texcoord1 = v.texcoord1;
					o.worldPos = worldPos;
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);
				
#					if _PARALLAX 
						TRANSFER_TANGENT_VIEW_DIR(o);
#					endif

					TRANSFER_WTANGENT(o)
					TRANSFER_SHADOW(o);


					float3 refractedRay = refract(-normalize(o.viewDir.xyz), o.normal.xyz, 0.5);

				

					o.traced = 1; // GetTraced_Glassy_Vertex(o.worldPos, normalize(o.viewDir.xyz), o.normal.xyz);

					/*
					#if _SHADOW_VERTEXTRACED
						o.traced.a =  GetTranslucentTracedShadow(worldPos, refractedRay, 1) * 0.75 + o.traced.a * 0.25;
					#endif
						*/
					
					return o;
				}

				sampler2D _MainTex;
#if _AO_SEPARATE
				sampler2D _OcclusionMap;
#endif

			
				sampler2D _BumpMap;
				sampler2D _SpecularMap;
				sampler2D _MicrodetailMap;

				float4 _MicrodetailMap_ST;

				float _HeightOffset;
				float _ParallaxForce;

				float4 _SubSurface;

#if _OFFSET_BY_HEIGHT
				FragColDepth frag(v2f i)
#else 
				float4 frag(v2f i) : COLOR
#endif
				{

					float3 viewDir = normalize(i.viewDir.xyz);
					float rawFresnel = saturate(1 - dot(viewDir, i.normal.xyz));
					float2 uv = i.texcoord.xy;
					float offsetAmount = (1 + rawFresnel * rawFresnel * 4);

					float4 madsMap = tex2D(_SpecularMap, uv);
					float displacement = madsMap.b;

#if _PARALLAX 
					i.tangentViewDir = normalize(i.tangentViewDir);
					i.tangentViewDir.xy /= i.tangentViewDir.z; // abs(i.tangentViewDir.z + 0.42);
					float deOff = _ParallaxForce / offsetAmount;

					CheckParallax(uv, madsMap, _SpecularMap, i.tangentViewDir, deOff, displacement);
#endif

					float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));
					uv -= tnormal.rg * _MainTex_TexelSize.xy;
					float3 normal = i.normal.xyz;

					float ao;

#if _AO_SEPARATE
#	if _AMBIENT_IN_UV2
					ao = tex2D(_OcclusionMap, i.texcoord1.xy).r;
#	else
					ao = tex2D(_OcclusionMap, uv).r;
#	endif
#elif _AO_MADS
					ao = madsMap.g;
#else 
					ao = 1;
#endif


#if _COLOR_R_AMBIENT
					ao *= (0.25 + i.color.r * 0.75);
#endif

					float4 tex = tex2D(_MainTex, uv);//TODO: Mose this down


					float water = 0;

					ApplyTangent(normal, tnormal, i.wTangent);

					// ********************** WATER

#if _qc_USE_RAIN 

					float rain = GetRain(i.worldPos, normal, i.normal);

					float flattenWater = ApplyWater(water, rain, ao, displacement, madsMap, tnormal, i.worldPos, i.normal.y);

					normal = i.normal.xyz;
					ApplyTangent(normal, tnormal, i.wTangent);
#endif


					// ****************light

					float metal = madsMap.r;
					float fresnel = GetFresnel(normal, viewDir) * ao; // (1 - saturate(dot(normal, viewDir))); // *ao;
					float specular = GetSpecular(madsMap.a, fresnel , metal);// madsMap.a; // GetSpecular(madsMap.a, fresnel, metal);

				//normalize(-viewDir - normal * 0.5);
				//_SHADOW_NONE _SHADOW_UNITY  _SHADOW_VERTEXTRACED _SHADOW_PIXELTRACED

					float3 refractedRay =  refract(-viewDir, normal, 0.75);

					float shadow =1;
						
					//#if _SHADOW_UNITY
						shadow *= SHADOW_ATTENUATION(i);
					/*#elif _SHADOW_VERTEXTRACED
						shadow *= i.traced.a;
					#elif _SHADOW_PIXELTRACED
						shadow *= GetTranslucentTracedShadow(i.worldPos, refractedRay, 1) * 0.75 + i.traced.a * 0.25;
					#endif*/

					float3 lightColor = GetDirectional() * shadow; // Savage_GetDirectional(shadow, ao, normal, i.normal, i.worldPos);
					
					// LIGHTING

					float3 samplePos = i.worldPos + i.normal * 0.1;

				float3 reflectedRay = reflect(-viewDir, normal);
				float3 bakeReflected = GetBakedAndTracedReflection(samplePos, reflectedRay, BLOOD_SPECULAR);//SampleReflection(o.worldPos, viewDir, normal, shadow, hit);

				#if _MIRROR
					ApplyBottomFog(bakeReflected, i.worldPos.xyz, viewDir.y);
					return float4(bakeReflected,1);
				#endif

			
			//ao = 1;

				float3 bakeStraight = GetBakedAndTracedReflection(samplePos, refractedRay, BLOOD_SPECULAR);
			
				bakeStraight += GetTranslucent_Sun(refractedRay) * shadow; //translucentSun * shadow * GetDirectional() * 4; 

				//return float4(bakeStraight, 1);

				float showStraight = lerp(0.8, 0.2, fresnel); //pow(1 - fresnel, 2);

				float3 	reflectedPart = lerp( bakeReflected.rgb, bakeStraight.rgb, showStraight);// + specularReflection * lightColor;

				//return float4(bakeReflected,1);

				float3 col = reflectedPart * lerp(_SubSurface.rgb, tex.rgb, ao);



				// ************************** MICRODETAIL

#if _MICRODETAIL
					//_MicrodetailMap
					float microdetSample = tex2D(_MicrodetailMap, TRANSFORM_TEX(uv, _MicrodetailMap)).a;

					float microdet = abs(microdetSample - 0.5) * 2;

					microdet *= microdet;

					col = lerp(col, reflectedPart, microdet);
#endif

					ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);
				//	return smoothstep(-0.35, -0.02, viewDir.y);

#if _OFFSET_BY_HEIGHT
					FragColDepth result;
					result.depth = calculateFragmentDepth(i.worldPos + (displacement - 0.5) * offsetAmount * viewDir * _HeightOffset);
					result.col =  float4(col, 1);

					return result;
#else 
					return float4(col,1);
#endif


				}
				ENDCG
			}

			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

		}
		Fallback "Diffuse"
	}

	//CustomEditor "QuizCanners.RayTracing.MatDrawer_RayGeometryStandardSpecular"
}