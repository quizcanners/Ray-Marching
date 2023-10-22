Shader "RayTracing/Geometry/Standard Specular Multitextured"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}

		[KeywordEnum(OFF, PLASTIC, METAL, LAYER, MIXED_METAL, PAINTED_METAL)] _REFLECTIVITY("Reflective Material Type", Float) = 0
		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0

		_BumpMap("Normal Map", 2D) = "bump" {}

		_MainTex2("Albedo (RGB)", 2D) = "white" {}
		_SpecularMap2("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		_BumpMap2("Normal Map", 2D) = "bump" {}

		[KeywordEnum(None, MADS, Separate)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}

		[Toggle(_AMBIENT_IN_UV2)] ambInuv2("Ambient mapped to UV2", Float) = 0
		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0

		[Toggle(_SIMPLIFY_SHADER)] simplifyShader("Simplify Shader", Float) = 0

		[Toggle(_PARALLAX)] parallax("Parallax", Float) = 0
		_ParallaxForce("Parallax Amount", Range(0.001,0.3)) = 0.01

		[Toggle(_OFFSET_BY_HEIGHT)] heightOffset("Offset By Height", Float) = 0
		_HeightOffset("Height Offset", Range(0.01,0.3)) = 0.2

		[Toggle(_DAMAGED)] isDamaged("_DAMAGED", Float) = 0

		[NoScaleOffset] _Damage_Tex("DAMAGE (_UV1 for Beveled)", 2D) = "black" {}

		_DamDiffuse("Damaged Diffuse", 2D) = "white" {}

		//_DamDiffuse2("Damaged Diffuse Deep", 2D) = "white" {}
		_Reflectivity("Added Reflectiveness (Mat)", Range(0,1)) = 0.33

		_BloodPattern("Blood Pattern", 2D) = "gray" {}

		_MudColor("Water Color", Color) = (0.5, 0.5, 0.5, 0.5)

	
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

				#define RENDER_DYNAMICS
		
				#pragma vertex vert
				#pragma fragment frag
				#pragma target 3.0
				#pragma multi_compile_instancing

				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				#pragma multi_compile ___ _qc_IGNORE_SKY
				#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
				#pragma multi_compile ___ _qc_USE_RAIN

				#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
				#pragma shader_feature_local _REFLECTIVITY_OFF _REFLECTIVITY_PLASTIC _REFLECTIVITY_METAL _REFLECTIVITY_LAYER  _REFLECTIVITY_MIXED_METAL  _REFLECTIVITY_PAINTED_METAL


				#pragma shader_feature_local ___ _OFFSET_BY_HEIGHT
				#pragma shader_feature_local ___ _AMBIENT_IN_UV2
				#pragma shader_feature_local _AO_NONE _AO_MADS _AO_SEPARATE
				#pragma shader_feature_local ___ _COLOR_R_AMBIENT
				#pragma shader_feature_local ___ _PARALLAX
				#pragma shader_feature_local ___ _DAMAGED
				#pragma shader_feature_local ___ _SHOWUVTWO
				#pragma shader_feature_local ___ _SIMPLIFY_SHADER



				#include "Assets/Ray-Marching/Shaders/Savage_Sampler_Debug.cginc"

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

#if _PARALLAX || _DAMAGED
					float3 tangentViewDir : TEXCOORD7; // 5 or whichever is free
#endif
					float4 traced : TEXCOORD8;
					fixed4 color : COLOR;
				};



				v2f vert(appdata_full v) {
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

#					if _PARALLAX || _DAMAGED
						TRANSFER_TANGENT_VIEW_DIR(o);
#					endif

					o.traced = GetTraced_Mirror_Vert(o.worldPos, normalize(o.viewDir.xyz), o.normal.xyz);

					TRANSFER_WTANGENT(o)
					TRANSFER_SHADOW(o);

					return o;
				}

				sampler2D _MainTex;
#if _AO_SEPARATE
				sampler2D _OcclusionMap;
#endif
				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
			
				sampler2D _BumpMap;
				sampler2D _SpecularMap;

				sampler2D _MainTex2;
				sampler2D _BumpMap2;
				sampler2D _SpecularMap2;
				float4 _MainTex2_ST;

				sampler2D _Damage_Tex;

				float _HeightOffset;
				float _ParallaxForce;

				float4 _MudColor;
				float _Reflectivity;
#				if _DAMAGED
					
					float4 _Damage_Tex_TexelSize;
					sampler2D _DamDiffuse;
					float4 _DamDiffuse_TexelSize;
					//sampler2D _DamDiffuse2;
					//float4 _DamDiffuse2_TexelSize;
					sampler2D _BloodPattern;
#				endif

#if _OFFSET_BY_HEIGHT
				FragColDepth frag(v2f i)
#else 
				float4 frag(v2f i) : COLOR
#endif
				{
					
					float3 viewDir = normalize(i.viewDir.xyz);
					float rawFresnel = saturate(1- dot(viewDir, i.normal.xyz));
					float2 uv = TRANSFORM_TEX(i.texcoord.xy, _MainTex);
					float2 uv2 = TRANSFORM_TEX(i.texcoord.xy, _MainTex2) * 1.234;

					float offsetAmount = (1 + rawFresnel * rawFresnel * 4);

					float control = tex2D(_Damage_Tex, i.texcoord.xy).a;

					//return control;

					float4 madsMapA = tex2D(_SpecularMap, uv);
					float4 madsMapB = tex2D(_SpecularMap2, uv2);

					float showB = smoothstep(0, 0.2, madsMapB.b + control * 2 - (1+madsMapA.b));

					float4 madsMap = lerp(madsMapA, madsMapB, showB);

					float displacement = madsMap.b;

#if _PARALLAX || _DAMAGED
					i.tangentViewDir = normalize(i.tangentViewDir);
					i.tangentViewDir.xy /= i.tangentViewDir.z;
					float deOff = _ParallaxForce / offsetAmount;
#endif

					float4 tnormalA = tex2D(_BumpMap, uv);
					float4 tnormalB = tex2D(_BumpMap2, uv2);

					float3 tnormal = UnpackNormal(lerp(tnormalA, tnormalB, showB));
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

					float4 texA = tex2D(_MainTex, uv);
					float4 texB = tex2D(_MainTex2, uv2);
					float4 tex = lerp(texA, texB, showB);

					float water = 0;
					float4 mask = tex2D(_Damage_Tex, i.texcoord1);

					water += mask.b;

					float showRed = 0;

#				if _DAMAGED

					// R - Blood
					// G - Damage

					float2 damUV = i.texcoord;

					float2 damPix = _Damage_Tex_TexelSize.xy;

				
					float4 maskY = tex2D(_Damage_Tex, i.texcoord1 + float2(0, damPix.y));
					float4 maskX = tex2D(_Damage_Tex, i.texcoord1 + float2(damPix.x, 0));

					float noise = tex2Dlod(_BloodPattern, float4(damUV * 4.56,0,12*mask.b)).r;

				//	return noise;

					float3 damBump = normalize(float3(maskX.g - mask.g, maskY.g - mask.g, 0.1));

					float damDepth = mask.g * 2 - displacement;

					damUV += i.tangentViewDir.xy * ( -damDepth) * 2 * deOff;

					damDepth += mask.g - noise;

					float damAlpha = smoothstep(0, 0.5, damDepth);

					float4 dam = tex2D(_DamDiffuse, damUV*4);

					float2 damNormUV = damUV;

					float3 damTnormal = UnpackNormal(tex2D(_BumpMap, damNormUV *4));

					tnormal = lerp(tnormal, damBump + damTnormal, damAlpha);
					tex = lerp(tex, dam, damAlpha);

					float damHole = smoothstep(4, 0, damDepth);

					ao = lerp(ao, damHole, damAlpha);
					water = lerp(water, 0, damAlpha);
					displacement = lerp(displacement, 0.2, damAlpha);
					madsMap = lerp(madsMap, float4(0.3, 0, 0, 0), damAlpha);

					mask *= smoothstep(0, 1, (2 - damHole + noise));

					showRed = ApplyBlood(mask, water, tex.rgb, madsMap, displacement);
					_MudColor = lerp(_MudColor, _qc_BloodColor, showRed);

#				endif

					ApplyTangent(normal, tnormal, i.wTangent);

						float shadow = SHADOW_ATTENUATION(i);

					// ********************** WATER
					float rain = 0;
#if _qc_USE_RAIN || _DAMAGED
					rain = GetRain(i.worldPos, normal, i.normal, shadow);
					//water += madsMap.a * (rain + water) * 8 * (1-showRed);
#endif

					float glossLayer = ApplyWater(water, rain, ao, displacement, madsMap, tnormal, i.worldPos, i.normal.y);

					#				if _DAMAGED
					madsMap.r = lerp(madsMap.r,1,showRed);
					#endif

					//return  float4(tnormal,1);

					normal = i.normal.xyz;
					ApplyTangent(normal, tnormal, i.wTangent);


					float3 worldPosAdjusted = i.worldPos;
					ao *= SampleContactAO_OffsetWorld(worldPosAdjusted, normal);

					// ********************************* light
					float metal = madsMap.r;

					float fresnel =	GetFresnel(normal, viewDir)  * ao;
					float specular = GetSpecular(madsMap.a, fresnel, metal) ;

#if _qc_USE_RAIN || _DAMAGED
					ModifyColorByWetness(tex.rgb, water,madsMap.a, _MudColor);
#endif

		
		
					MaterialParameters precomp;
					
					precomp.shadow = shadow;
					precomp.ao = ao;
					precomp.fresnel = fresnel;
					precomp.tex = tex;
				
					precomp.reflectivity = _Reflectivity;
					precomp.metal = metal;
					precomp.traced = i.traced;
					precomp.water = water;
					precomp.smoothsness = specular;

					precomp.microdetail = _MudColor;
					precomp.metalColor = 1; //lerp(tex, _MetalColor, _MetalColor.a);

					precomp.microdetail.a = 0;
				
				//	return ao;

					float3 col = GetReflection_ByMaterialType(precomp, normal, i.normal.xyz, viewDir, worldPosAdjusted);

					ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

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

	CustomEditor "QuizCanners.RayTracing.MatDrawer_RayGeometryStandardSpecular"
}