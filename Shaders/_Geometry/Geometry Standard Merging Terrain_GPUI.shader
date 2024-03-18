Shader "GPUInstancer/QcRendering/Terrain/Standard Merging"
{
	Properties
	{
		_MainTex("Main Albedo (RGB)", 2D) = "white" {}
		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		_BumpMap("Normal Map", 2D) = "bump" {}
		[KeywordEnum(MADS, None, Separate, Displacement)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}
		_MergeHeight("Merge Height", Range(0,5)) = 1
        _BlendSharpness("Blend Sharpness", Range(0,1)) = 0

		[Toggle(_OFFSET_BY_HEIGHT)] heightOffset("Offset By Height", Float) = 0
		_HeightOffset("Height Offset", Range(0.01,0.3)) = 0.2

		[Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
		_SubSurface("Sub Surface Scattering", Color) = (1,0.5,0,0)
		_SkinMask("Skin Mask (_UV2)", 2D) = "white" {}

		_Reflectivity("Added Reflectiveness (Mat)", Range(0,1)) = 0.33

	}

	Category
	{
		SubShader
		{
			CGINCLUDE

			#define RENDER_DYNAMICS
			//#pragma multi_compile __ RT_FROM_CUBEMAP 
			#pragma multi_compile ___ _qc_USE_RAIN

			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Tracing.cginc"
			#include "Assets\The-Fire-Below\Common\Shaders\qc_terrain_cg.cginc"

			ENDCG

			Pass
			{
				Tags
				{
					"Queue" = "Geometry"
					"RenderType" = "Opaque"
					"LightMode" = "ForwardBase"
				}

				ColorMask RGBA
				Cull Back
				CGPROGRAM

				#include "UnityCG.cginc"
				#include "Assets/GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
				#pragma instancing_options procedural:setupGPUI
				#pragma multi_compile_instancing

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile ___ QC_MERGING_TERRAIN

				#pragma shader_feature_local ___ _OFFSET_BY_HEIGHT

				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				//#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
				#pragma multi_compile ____ _qc_WATER
				#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
				#pragma multi_compile __ _qc_IGNORE_SKY 

				#pragma shader_feature_local _AO_MADS  _AO_NONE   _AO_SEPARATE  _AO_DISPLACEMENT

				#pragma shader_feature_local ___ _SUB_SURFACE

				struct v2f 
				{
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float2 texcoord1	: TEXCOORD1;
					float3 worldPos		: TEXCOORD2;
					float3 normal		: TEXCOORD3;
					float4 wTangent		: TEXCOORD4;
					float3 viewDir		: TEXCOORD5;
					//float3 tc_Control : TEXCOORD6;
					SHADOW_COORDS(7)
					float2 lightMapUv : TEXCOORD8;
					fixed4 color : COLOR;
				};



				v2f vert(appdata_full v) 
				{
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = v.texcoord;
					o.texcoord1 = v.texcoord1;
					o.worldPos = worldPos;
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);
					//o.tc_Control = WORLD_POS_TO_TERRAIN_UV_3D(worldPos);
					o.lightMapUv = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;

					TRANSFER_WTANGENT(o);
					TRANSFER_SHADOW(o);

					return o;
				}


		
				
				sampler2D _MainTex;
				sampler2D _BumpMap;
				sampler2D _SpecularMap;
#if _AO_SEPARATE
				sampler2D _OcclusionMap;
#endif

				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				sampler2D _SkinMask;
				float4 _SubSurface;
				float _HeightOffset;

				float _MergeHeight;
				float _BlendSharpness;

				float _Reflectivity;

#if _OFFSET_BY_HEIGHT
				FragColDepth frag(v2f i)
#else 
				float4 frag(v2f i) : COLOR
#endif
				{
					float3 viewDir = normalize(i.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, i.normal.xyz));
					float3 normal = i.normal.xyz;

					float offsetAmount = (1 + rawFresnel * rawFresnel * 4);
				
					float2 uv = i.texcoord.xy;
					float4 tex = tex2D(_MainTex, uv);
					float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));
					ApplyTangent(normal, tnormal, i.wTangent);

					float4 madsMap = tex2D(_SpecularMap, uv);
				//	float specular = madsMap.a;

					float ao;
					//_AO_MADS  _AO_NONE   _AO_SEPARATE

#if _AO_SEPARATE
					ao = tex2D(_OcclusionMap, uv).r;
#elif _AO_MADS
					ao = madsMap.g;
#elif _AO_DISPLACEMENT
					ao = 0.75 + madsMap.b * 0.25;
#else 
					ao = 1;
#endif
					madsMap.g = ao;
						float displacement = madsMap.b;
#if QC_MERGING_TERRAIN

//	float _HeightOffset;
			//	float _BlendSharpness;


               //  float transition = smoothstep(_BlendHeight * _BlendSharpness * 0.99, _BlendHeight, blendWeight);
			   //_MergeHeight * smoothstep(0,1, i.normal.y)

					MergeWithTerrain(i.worldPos, normal, madsMap, tex.rgb, _MergeHeight, _BlendSharpness);
					ao = madsMap.g;

					//return float4(tex.rgb,1);
#endif

				

					// ********************** WATER

					float water = 0;

#if _qc_WATER
					float waterLevel = i.worldPos.y - _qc_WaterPosition.y;

					water = smoothstep(1, 0, abs(waterLevel));

					madsMap.a = lerp(madsMap.a, 0.7, smoothstep(0.3,0,abs(waterLevel)));
					madsMap.a = lerp(madsMap.a, 0.1, smoothstep(0, -0.01, waterLevel));
#endif

					
						float shadow = SHADOW_ATTENUATION(i);
#if _qc_USE_RAIN 

					float rain = GetRain(i.worldPos, normal, i.normal, shadow);

					float flattenWater = ApplyWater(water, rain, ao, displacement, madsMap, tnormal, i.worldPos, i.normal.y);

					normal = lerp(normal, i.normal.xyz, flattenWater);
					//normal = i.normal.xyz;
					//ApplyTangent(normal, tnormal, i.wTangent);
#endif

					// **************** light

					float metal = madsMap.r;
					float fresnel = GetFresnel(normal, viewDir);
				ao += fresnel * (1-ao); 
				fresnel *= ao;

				float specular = madsMap.a * madsMap.a;


				

					float3 lightColor = Savage_GetDirectional_Opaque(shadow, ao, normal, i.worldPos);

				
					// LIGHTING
					float3 bake;

#if LIGHTMAP_ON
					float3 lightMap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightMapUv));
					bake = lightMap;
#else 

					float3 volumeSamplePosition;
					bake = Savage_GetVolumeBake(i.worldPos, normal, i.normal, volumeSamplePosition);
#endif

					TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
					float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, i.worldPos);
					ao *= topDownAmbient.a;
					bake.rgb += topDownAmbient.rgb;

					ModifyColorByWetness(tex.rgb, water, madsMap.a);

					float3 col = tex.rgb * (lightColor + bake * ao);

#if !LIGHTMAP_ON

					float3 reflectedRay = reflect(-viewDir, normal);

					float3 reflectionColor = 0;

#if !_SIMPLIFY_SHADER
					float4 topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, i.worldPos, i.normal.xyz, specular);
					ao *= topDownAmbientSpec.a;
					reflectionColor += topDownAmbientSpec.rgb;
#endif

					reflectionColor *= ao;
					reflectionColor += GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular, ao);
					

#if !_SIMPLIFY_SHADER
					reflectionColor += GetDirectionalSpecular(normal, viewDir, specular * 0.95) * lightColor;
#endif
					
					float reflectivity = specular + (1-specular) * _Reflectivity * fresnel * ao;

					MixInSpecular(col, reflectionColor, tex, metal, reflectivity, fresnel);
#endif


					ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

#if _OFFSET_BY_HEIGHT
					FragColDepth result;
					result.depth = calculateFragmentDepth(i.worldPos + (displacement - 0.5) * offsetAmount * viewDir * _HeightOffset);
					result.col = float4(col, 1);

					return result;
#else 
					return float4(col, 1);
#endif

				}
				ENDCG
			}

			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

		}
		Fallback "Diffuse"
	}
}
