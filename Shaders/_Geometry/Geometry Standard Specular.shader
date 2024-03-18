Shader "QcRendering/Geometry/Standard"
{
	Properties
	{
		[KeywordEnum(REGULAR, BICUBIC, PIXELATED, NONE)] _SAMPLING("Texture Sampling", Float) = 0
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		[HDR]_Color("Color", Color) = (1,1,1,1)
		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		[KeywordEnum(OFF, PLASTIC, METAL, LAYER, MIXED_METAL, PAINTED_METAL)] _REFLECTIVITY("Reflective Material Type", Float) = 0
		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0
		_Reflectivity("Added Reflectiveness (Mat)", Range(0,1)) = 0.33

		_BumpMap("Normal Map", 2D) = "bump" {}

		[KeywordEnum(None, MADS, Separate, MADSandSeparate)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}

		[Toggle(_AMBIENT_IN_UV2)] ambInuv2("Ambient mapped to UV2", Float) = 0
		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0
		[Toggle(_FRESNEL_FADE_AO)] fresFadeAo("Fresnel fades AO", Float) = 0
		[Toggle(_SDF_AMBIENT)] sdfAmbient("SDF Ambient", Float) = 0
		[Toggle(_NO_HB_AMBIENT)] noHbAmbient("Disable Screen Space Effects", Float) = 0

		[Toggle(_EMISSIVE)] emissiveTexture("Emissive Texture", Float) = 0
		_Emissive("Emissive", 2D) = "clear" {}

		[KeywordEnum(NONE, ON, LAYER)] _MICRODETAIL("Microdetail", Float) = 0
		_MicrodetailMap("Microdetail Map", 2D) = "white" {}
		_MicrodetailBump("Microdetail Bump", 2D) = "bump" {}

		[Toggle(_SECOND_LAYER)] usingLayers("Second Layer", Float) = 0
		_MainTex2("Albedo (RGB)", 2D) = "black" {}
		_SpecularMap2("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		_BumpMap2("Normal Map 2", 2D) = "bump" {}

		[Toggle(_SIMPLIFY_SHADER)] simplifyShader("Simplify Shader", Float) = 0

	
		//[Toggle(_BICUBIC_SAMPLING)] bicubic("Bicubic Sampling", Float) = 0

		[Toggle(_PARALLAX)] parallax("Parallax", Float) = 0
		_ParallaxForce("Parallax Amount", Range(0.001,0.01)) = 0.01

		[Toggle(_OFFSET_BY_HEIGHT)] heightOffset("Offset By Height", Float) = 0
		_HeightOffset("Height Offset", Range(0.01,0.3)) = 0.2

		[Toggle(_DAMAGED)] isDamaged("_DAMAGED", Float) = 0
		[NoScaleOffset] _Damage_Tex("DAMAGE (_UV1 for Beveled)", 2D) = "black" {}
		_DamDiffuse("Damaged Diffuse", 2D) = "white" {}
		[NoScaleOffset]_BumpD("Bump Damage", 2D) = "gray" {}
		_DamDiffuse2("Damaged Diffuse Deep", 2D) = "white" {}
		[NoScaleOffset]_BumpD2("Bump Damage 2", 2D) = "gray" {}

		_BloodPattern("Blood Pattern", 2D) = "gray" {}
		_MudColor("Water Mud Color", Color) = (0.5, 0.5, 0.5, 0.5)
		_MetalColor("Metal Color", Color) = (0.5, 0.5, 0.5, 0)

		[Toggle(_DYNAMIC_OBJECT)] dynamic("Dynamic Object", Float) = 0
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
				//#pragma target 3.0
				#pragma multi_compile_instancing

				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				//LIGHTPROBE_SH
				//DIRECTIONAL  - to receive shadows
				//LIGHTMAP_ON 
				//DIRLIGHTMAP_COMBINED 
				//DYNAMICLIGHTMAP_ON 
				//SHADOWS_SCREEN - to receive shadows
				//SHADOWS_SHADOWMASK 
				//LIGHTMAP_SHADOW_MIXING 
				
				#pragma multi_compile ___ qc_LAYARED_FOG
				#pragma multi_compile ___ _qc_USE_RAIN 
				#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
				#pragma multi_compile ___ _qc_IGNORE_SKY 


				#pragma shader_feature_local ___ _OFFSET_BY_HEIGHT
				#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
				#pragma shader_feature_local _REFLECTIVITY_OFF _REFLECTIVITY_PLASTIC _REFLECTIVITY_METAL _REFLECTIVITY_LAYER  _REFLECTIVITY_MIXED_METAL  _REFLECTIVITY_PAINTED_METAL


				#pragma shader_feature_local _MICRODETAIL_NONE  _MICRODETAIL_ON  _MICRODETAIL_LAYER

				//NONE, REGULAR, BICUBIC)] _SAMPLING

				#pragma shader_feature_local _SAMPLING_NONE _SAMPLING_REGULAR _SAMPLING_BICUBIC   _SAMPLING_PIXELATED

				#pragma shader_feature_local ___ _AMBIENT_IN_UV2
				#pragma shader_feature_local _AO_NONE _AO_MADS _AO_SEPARATE  _AO_MADSANDSEPARATE
				#pragma shader_feature_local ___ _COLOR_R_AMBIENT
				#pragma shader_feature_local ___ _PARALLAX
				#pragma shader_feature_local ___ _DAMAGED
				#pragma shader_feature_local ___ _SECOND_LAYER
				#pragma shader_feature_local ___ _FRESNEL_FADE_AO
				#pragma shader_feature_local ___ _DYNAMIC_OBJECT
				#pragma shader_feature_local ___ _SHOWUVTWO
				#pragma shader_feature_local ___ _SIMPLIFY_SHADER
				#pragma shader_feature_local ___ _EMISSIVE
				#pragma shader_feature_local ___ _SDF_AMBIENT
				#pragma shader_feature_local ___ _NO_HB_AMBIENT
	
				#include "UnityCG.cginc"
				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"
				
				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_VolumetricFog.cginc"
		
				#include "Assets/Qc_Rendering/Shaders/Savage_Shadowmap.cginc"

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
					float3 tangentViewDir : TEXCOORD7;
					float4 traced : TEXCOORD8;
					//#if !_NO_HB_AMBIENT
					float4 screenPos :		TEXCOORD9;
					//#endif
					fixed4 color : COLOR;

					UNITY_VERTEX_INPUT_INSTANCE_ID
					UNITY_VERTEX_OUTPUT_STEREO
				};

				v2f vert(appdata_full v) 
				{
					UNITY_SETUP_INSTANCE_ID(v);

					v2f o;
					UNITY_TRANSFER_INSTANCE_ID(v,o);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
					

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = v.texcoord;
					o.texcoord1 = v.texcoord1;
					o.worldPos = worldPos;
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);


					o.traced = 0; //GetTraced_Mirror_Vert(o.worldPos, normalize(o.viewDir.xyz), o.normal.xyz);
					//#if !_NO_HB_AMBIENT
					o.screenPos = ComputeScreenPos(o.pos);
					//#endif

					TRANSFER_TANGENT_VIEW_DIR(o);
					TRANSFER_WTANGENT(o)
					TRANSFER_SHADOW(o);

					return o;
				}

				sampler2D _MainTex;
				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;


				sampler2D _BumpMap;
				sampler2D _SpecularMap;

#if _AO_SEPARATE || _AO_MADSANDSEPARATE
				sampler2D _OcclusionMap;
#endif

	#if _EMISSIVE
				sampler2D _Emissive;
	#endif

#			if _SECOND_LAYER
				//sampler2D _MainTex2;
			
			
				Texture2D _MainTex2;
				SamplerState sampler_MainTex2;
				float4 _MainTex2_TexelSize;
				float4 _MainTex2_ST;

				Texture2D _BumpMap2;	
				Texture2D _SpecularMap2;


#			endif


#if !_MICRODETAIL_NONE
#if		!_DAMAGED && !_SECOND_LAYER
					sampler2D _MicrodetailMap;
					float4 _MicrodetailMap_ST;
				#endif
					sampler2D _MicrodetailBump;
					float4 _MicrodetailBump_ST;
				#endif


				float _HeightOffset;
				float _ParallaxForce;
				float4 _BloodPattern_ST;
				sampler2D _BloodPattern;
				float4 _MudColor;
				float4 _MetalColor;
				float _Reflectivity;


#				if _DAMAGED
					sampler2D _Damage_Tex;
					float4 _Damage_Tex_TexelSize;
					sampler2D _DamDiffuse;
					float4 _DamDiffuse_TexelSize;
					
					#if !_SECOND_LAYER && _MICRODETAIL_NONE
						sampler2D _DamDiffuse2;
						float4 _DamDiffuse2_TexelSize;
						sampler2D _BumpD;
						sampler2D _BumpD2;
					#endif
#				endif



				float4 _Color;

#if _OFFSET_BY_HEIGHT

				struct FragColDepth
				{
					float4 col: SV_Target;
					float depth : SV_Depth;
				};


				FragColDepth frag(v2f i)
#else 
				float4 frag(v2f i) : COLOR
#endif
				{
					// ***************** NON - SIMPLIFY SHADER

					float3 viewDir = normalize(i.viewDir.xyz);
					float rawFresnel = saturate(1- dot(viewDir, i.normal.xyz));

					//#if !_NO_HB_AMBIENT
						float2 screenUv = i.screenPos.xy / i.screenPos.w;
					//#endif

					float2 uv = TRANSFORM_TEX(i.texcoord.xy, _MainTex);
			

				#if _SAMPLING_BICUBIC
					float4 bicOff;
					float2 bicWeights;
					GetBicubicCoefficients(uv, _MainTex_TexelSize, bicOff, bicWeights);

				#elif _SAMPLING_PIXELATED
					smoothedPixelsSampling(uv, _MainTex_TexelSize);
				#endif

					// **************** Albedo & Masks

					float offsetAmount = (1 + rawFresnel * rawFresnel * 4);

					float4 madsMap = tex2D(_SpecularMap, uv);

				//	return madsMap.g;

					float displacement = madsMap.b;

					i.tangentViewDir = normalize(i.tangentViewDir);
					i.tangentViewDir.xy /= i.tangentViewDir.z; // abs(i.tangentViewDir.z + 0.42);
					float deOff = _ParallaxForce / offsetAmount;

#if _PARALLAX || _DAMAGED
					CheckParallax(uv, madsMap, _SpecularMap, i.tangentViewDir, deOff, displacement);
#endif


			float3 tnormal;
			#if _SAMPLING_NONE
				tnormal = float3(0,1,0);
			#else 
				float4 bumpSample;
				
				#if _SAMPLING_BICUBIC
					bumpSample = tex2DBicubicCoef(_BumpMap, bicOff, bicWeights); 
				#else
					bumpSample = tex2D(_BumpMap, uv);
				#endif
				tnormal = UnpackNormal(bumpSample);
			#endif
					
				
			// ******************** MICRODETAIL
#if !_MICRODETAIL_NONE && !_DAMAGED && !_SECOND_LAYER
					float2 microdetailUV = TRANSFORM_TEX(uv, _MicrodetailMap);
					float microdetSample = (tex2D(_MicrodetailMap, microdetailUV).a - 0.5) * 2;
					float2 microdetailUVbump = TRANSFORM_TEX(uv, _MicrodetailBump);

					float3 microNorm = UnpackNormal(tex2D(_MicrodetailBump, microdetailUVbump));

					tnormal = lerp(tnormal,microNorm, 0.5);

					microdetSample = max(0,microdetSample);
#endif

					float water = 0;

					// ************** Ambient Occlusion

			float4 tex = _Color;
			#if _SAMPLING_NONE
				//tex = 1;
			#elif _SAMPLING_BICUBIC
				tex *= tex2DBicubicCoef(_MainTex, bicOff, bicWeights); 
			#else
				tex *= tex2D(_MainTex, uv);
			#endif
			//
			/*
			#if !_COLOR_R_AMBIENT
				tex.rgb *= i.color.rgb;
			#endif
			*/
// ******************* SECOND LAYER

			float4 illumination;

			float ao = 
			#if _NO_HB_AMBIENT
				1;
				illumination = 0;
			#else
				SampleSS_Illumination( screenUv, illumination);
			#endif			

			float shadow = saturate(1-illumination.b);

#	if _DAMAGED

			float4 mask = tex2D(_Damage_Tex, i.texcoord1);// .r;// -mask.g;
#	endif


#	if _SECOND_LAYER
					float2 uv2 = TRANSFORM_TEX(i.texcoord.xy, _MainTex2);

					//uv2 += float2(i.worldPos.x + i.worldPos.y,i.worldPos.y - i.worldPos.z) * 0.01;

					const float LAYER_PARALAX = 0.002;

				//	float2 layerNoise = Noise3D(i.worldPos* 0.01);

					float2 offsetUv = uv2 + i.tangentViewDir.xy * LAYER_PARALAX;


					float fade = 0 //Noise3D(i.worldPos* 0.2).x * 0.65
#			if _DAMAGED
					+ mask.a 
#			endif
					;

				//	float4 tex2 = tex2D(_MainTex2, offsetUv);

					
					float4 tex2 = _MainTex2.Sample(sampler_MainTex2, offsetUv);

					float layerAlpha = smoothstep(0.33, 0.4, tex2.a - displacement * 0.5
					- fade 
					);

					float4 mads2 = _SpecularMap2.Sample(sampler_MainTex2, offsetUv);

					madsMap = lerp(madsMap, mads2, layerAlpha);
					tex = lerp(tex, tex2, layerAlpha);
					displacement += madsMap.b * (1-displacement) * layerAlpha;

					float4 bump2sample = _BumpMap2.Sample(sampler_MainTex2, offsetUv);

					tnormal = lerp(tnormal, UnpackNormal(bump2sample), layerAlpha);

					float2 coef = _MainTex2_TexelSize.zw * 4; // Optional

					float2 px = coef.x * ddx(uv2);
					float2 py = coef.y * ddy(uv2);

					float uvmip = (max(0, 0.5 * log2(max(dot(px, px), dot(py, py)))));

					tex2 = _MainTex2.Sample(sampler_MainTex2, (uv2 - i.tangentViewDir.xy * LAYER_PARALAX * (1-displacement*2)));

					float offsetShadow = smoothstep(1,0.1, tex2.a 
					- fade*2
					 );

					ao *= (1+offsetShadow) * 0.5;
					//madsMap.g = lerp(ao, madsMap.g, layerAlpha);

					shadow *= lerp(offsetShadow, 1, layerAlpha);
#	endif


// AO

#if _AO_SEPARATE || _AO_MADSANDSEPARATE
#	if _AMBIENT_IN_UV2
					ao *= tex2D(_OcclusionMap, i.texcoord1.xy).r;
#	else
					ao *= tex2D(_OcclusionMap, i.texcoord.xy).r;
#	endif
#endif

#if _AO_MADS || _AO_MADSANDSEPARATE
					ao *= madsMap.g + (1-madsMap.g) * rawFresnel;
#endif
					
				#if _FRESNEL_FADE_AO
					ao = lerp(ao,1, rawFresnel); // * (1-ao);
				#endif

#if _COLOR_R_AMBIENT
					ao *= (0.25 + i.color.r * 0.75);
#endif


// ******************* DAMAGE
float showRed =0;

#				if _DAMAGED

					float2 damUV = i.texcoord;

					//return smoothstep(0.9, 1, Noise3D(i.worldPos * 0.5));

					float noise = tex2Dlod(_BloodPattern, float4(damUV * _BloodPattern_ST.xy,0,12*mask.b)).r;

					// R - Blood
					// G - Damage

					float2 damPix = _Damage_Tex_TexelSize.xy;

					//float2 maskUv = i.texcoord1 + i.tangentViewDir.xy * (-damDepth) * 2 * deOff;

					//float4 mask = tex2D(_Damage_Tex, i.texcoord1);// .r;// -mask.g;
					float4 maskY = tex2D(_Damage_Tex, i.texcoord1 + float2(0, damPix.y));
					float4 maskX = tex2D(_Damage_Tex, i.texcoord1 + float2(damPix.x, 0));

					float3 damBump = normalize(float3(maskX.g - mask.g, maskY.g - mask.g, 0.1));

					mask.rga *= (1 + noise);

					float damDepth = mask.g * 2 - displacement;

					damUV -= i.tangentViewDir.xy * damDepth * deOff * 0.25;

					damDepth += mask.g - noise;

					float damAlpha = smoothstep(0, 0.5, damDepth);
					float damAlpha2 = smoothstep(1, 1.5, damDepth);

					float4 dam = tex2D(_DamDiffuse, damUV*4);
				

				

#if !_SIMPLIFY_SHADER && !_SECOND_LAYER && _MICRODETAIL_NONE

					float3 damTnormal = UnpackNormal(tex2D(_BumpD, damUV *4));
					float3 damTnormal2 = UnpackNormal(tex2D(_BumpD2, damUV));
					float4 dam2 = tex2D(_DamDiffuse2, damUV);
				
					damTnormal = lerp(damTnormal, damTnormal2, damAlpha2);

					tnormal = lerp(tnormal, damBump + damTnormal, damAlpha);
#else 
					tnormal = lerp(tnormal, damBump, damAlpha);
					float4 dam2 = tex2D(_DamDiffuse, damUV);
#endif

					dam = lerp(dam, dam2, damAlpha2);
					tex = lerp(tex, dam, damAlpha);

					float damHole = smoothstep(4, 0, damDepth);

					ao = lerp(ao, damHole, damAlpha);
					water = lerp(water, 0, damAlpha);
					displacement = lerp(displacement, 0.2 * (1- damAlpha2), damAlpha);
					madsMap = lerp(madsMap, float4(0.3, 0, 0, 0), damAlpha);
					shadow = lerp(shadow,1,damAlpha);
					mask *= smoothstep(0,1, (2 - damHole + noise));
					
					water += mask.b * 2;

					showRed = ApplyBlood(mask, water, tex.rgb, madsMap, displacement);
					_MudColor = lerp(_MudColor, _qc_BloodColor, showRed);
#				endif

					float3 normal = i.normal.xyz;

					ApplyTangent(normal, tnormal, i.wTangent);
					


					#if _NO_HB_AMBIENT
						shadow *= GetSunShadowsAttenuation(i.worldPos, i.screenPos.z);
					#else
						shadow *= SHADOW_ATTENUATION(i);
					#endif
		
// ********************** WATER

#if _qc_USE_RAIN || _DAMAGED
					float rain = GetRain(i.worldPos, normal, i.normal, shadow); 
					ApplyWater(water, rain, ao, displacement, madsMap, tnormal, i.worldPos, i.normal.y);

					#if _DAMAGED
						madsMap.r = lerp(madsMap.r, 1, showRed);
					#endif

					normal = i.normal.xyz;
					ApplyTangent(normal, tnormal, i.wTangent);
#endif

					float3 worldPosAdjusted = i.worldPos;

					#if _SDF_AMBIENT
					ao *= SampleContactAO_OffsetWorld(worldPosAdjusted, normal);
					#endif

					// **************** light

					float metal = madsMap.r;
					float fresnel = GetFresnel_FixNormal(normal, i.normal.xyz, viewDir);//GetFresnel(normal, viewDir) * ao;

					MaterialParameters precomp;
					
					precomp.shadow = shadow;
					precomp.ao = ao;
					precomp.fresnel = fresnel;
					precomp.tex = tex;
				
					precomp.reflectivity = _Reflectivity;
					precomp.metal = metal;
					precomp.traced = i.traced;
					precomp.water = water;
					precomp.smoothsness = madsMap.a;

					precomp.microdetail = _MudColor;
					precomp.metalColor = lerp(tex, _MetalColor, _MetalColor.a);

					#if !_MICRODETAIL_NONE && !_DAMAGED && !_SECOND_LAYER
						precomp.microdetail.a *= microdetSample;
					#else
						precomp.microdetail.a = 0;
					#endif

					float3 col = GetReflection_ByMaterialType(precomp, normal, i.normal.xyz, viewDir, worldPosAdjusted);


					#if _EMISSIVE
						col.rgb += tex2D(_Emissive, uv).rgb;
					#endif


					ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

					#if _NO_HB_AMBIENT
						float4 layeredFog = SampleLayeredFog(length(worldPosAdjusted-_WorldSpaceCameraPos.xyz)*0.2, screenUv);
						col.rgb = lerp(col.rgb, layeredFog.rgb, layeredFog.a);
					#endif

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

			Pass
			{
				Tags {"LightMode"="ShadowCaster"}
 
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_shadowcaster
				#pragma multi_compile_instancing
				#pragma multi_compile _ LOD_FADE_CROSSFADE
				#include "UnityCG.cginc"
 
				struct v2f {
					V2F_SHADOW_CASTER;
					 UNITY_VERTEX_INPUT_INSTANCE_ID // use this to access instanced properties in the fragment shader.
				};
 
				v2f vert(appdata_full v)
				{
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);
					UNITY_TRANSFER_INSTANCE_ID(v, o);

					o.pos = ComputeScreenPos(UnityObjectToClipPos(v.vertex));
					TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
					return o;
				}
 
				float4 frag(v2f i) : SV_Target
				{
				   // #ifdef LOD_FADE_CROSSFADE
					   // float2 vpos = i.pos.xy / i.pos.w * _ScreenParams.xy;
					  //  UnityApplyDitherCrossFade(vpos);
				   // #endif
					UNITY_SETUP_INSTANCE_ID(i);
					SHADOW_CASTER_FRAGMENT(i)
				}

				ENDCG
				//UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

			}
		}
		Fallback "Diffuse"
	}

//	CustomEditor "QuizCanners.RayTracing.MatDrawer_RayGeometryStandardSpecular"
}