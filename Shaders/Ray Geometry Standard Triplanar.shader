Shader "RayTracing/Geometry/Standard Triplanar"
{
	Properties
	{
		_HorizontalTiling("Tiling", Range(0.01,10)) = 1

		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		[KeywordEnum(OFF, PLASTIC, METAL, LAYER, MIXED_METAL)] _REFLECTIVITY("Reflective Material Type", Float) = 0
		[KeywordEnum(OFF, ON)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0

		_BumpMap("Normal Map", 2D) = "bump" {}

		[KeywordEnum(MADS, None, Separate)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}
		
		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0

	//	[Toggle(_SDF_AMBIENT)] sdfAmbient("SDF Ambient", Float) = 0

		[Toggle(_BEVELED)] isBeveled("Beveled", Float) = 0


		_EdgeColor("Edge Color Tint", Color) = (0.5,0.5,0.5,0)
		_EdgeMads("Edge (Metal, AO, Displacement, Smoothness)", Vector) = (0,1,1,0)

		[Toggle(_SDF_Bevel)] sdfBevel("SDF To Bevel Merge (Expensive)", Float) = 0

		[Toggle(_OFFSET_BY_HEIGHT)] heightOffset("Offset By Height", Float) = 0

		[Toggle(_DAMAGED)] isDamaged("_DAMAGED", Float) = 0
		[Toggle(_DAM_UV_1)] useUv1Damaged("use UV1", Float) = 0

		[NoScaleOffset] _Damage_Tex("DAMAGE (_UV1 for Beveled)", 2D) = "black" {}

		_DamDiffuse("Damaged Diffuse", 2D) = "white" {}
		_DamDiffuse2("Damaged Diffuse Deep", 2D) = "white" {}

		_BloodPattern("Blood Pattern", 2D) = "gray" {}

		_Reflectivity("Refectivity", Range(0,1)) = 0.33

		_MetalColor("Metal Color", Color) = (0.5, 0.5, 0.5, 0)

		[Toggle(_SIMPLIFY_SHADER)] simplifyShader("Simplify Shader", Float) = 0
	}

	Category
	{
		SubShader
		{
	

			Tags
			{
				"Queue" = "Geometry"
				"RenderType" = "Opaque"
				"LightMode" = "ForwardBase"
				"DisableBatching" = "True"
				"Solution" = "Bevel With Seam"
			}

			Pass
			{
				ColorMask RGBA
				Cull Back

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				#pragma multi_compile ___ _qc_USE_RAIN
				#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
				#pragma multi_compile __ _qc_IGNORE_SKY 
					
				#define RENDER_DYNAMICS

				#pragma shader_feature_local ___ _BEVELED
				#pragma shader_feature_local ___ _DAMAGED
				#pragma shader_feature_local ___ _DAM_UV_1
				#pragma shader_feature_local ___ _OFFSET_BY_HEIGHT
				#pragma shader_feature_local ___ _COLOR_R_AMBIENT
				#pragma shader_feature_local ___ _SIMPLIFY_SHADER
				#pragma shader_feature_local ___ _SDF_Bevel
				#pragma shader_feature_local _REFLECTIVITY_OFF _REFLECTIVITY_PLASTIC _REFLECTIVITY_METAL _REFLECTIVITY_LAYER _REFLECTIVITY_MIXED_METAL
				#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON 
			//	#pragma shader_feature_local ___ _SDF_AMBIENT
		

				#include "Assets/Ray-Marching/Shaders/Savage_Sampler_Debug.cginc"
				#include "Assets/Ray-Marching/Shaders/RayMarching_SmoothedDepth.cginc"
				
				struct v2f
				{
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float3 worldPos		: TEXCOORD1;
					float3 normal		: TEXCOORD2;
					float4 wTangent		: TEXCOORD3;
					float3 viewDir		: TEXCOORD4;
					SHADOW_COORDS(5)

#if _BEVELED

					float4 edge			: TEXCOORD6;
					float3 snormal		: TEXCOORD7;
					float3 edgeNorm0	: TEXCOORD8;
					float3 edgeNorm1	: TEXCOORD9;
					float3 edgeNorm2	: TEXCOORD10;
#else
					float2 texcoord1	: TEXCOORD6;
#endif
				//	float4 screenPos : TEXCOORD11;

					fixed4 color : COLOR;
				};

				v2f vert(appdata_full v)
				{
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = v.texcoord;
				//	o.screenPos = ComputeScreenPos(o.pos);
					o.worldPos = worldPos;
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);
					
#if _BEVELED
					o.edge = float4(v.texcoord1.w, v.texcoord2.w, v.texcoord3.w, v.texcoord.w);
					o.edgeNorm0 = UnityObjectToWorldNormal(v.texcoord1.xyz);
					o.edgeNorm1 = UnityObjectToWorldNormal(v.texcoord2.xyz);
					o.edgeNorm2 = UnityObjectToWorldNormal(v.texcoord3.xyz);

					float3 deEdge = 1 - o.edge.xyz;

					// This one is inconsistent with Batching
					o.snormal.xyz = normalize(o.edgeNorm0 * deEdge.x + o.edgeNorm1 * deEdge.y + o.edgeNorm2 * deEdge.z);
#else
					o.texcoord1 = v.texcoord1;
#endif


					TRANSFER_WTANGENT(o)
					TRANSFER_SHADOW(o);
					return o;
				}

				sampler2D _MainTex;
				sampler2D _SpecularMap;
				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				sampler2D _BumpMap;
				float4 _EdgeColor;
				float4 _EdgeMads;
				float _HorizontalTiling;
				float4 _MetalColor;


#				if _DAMAGED
					sampler2D _Damage_Tex;
					float4 _Damage_Tex_TexelSize;
					sampler2D _DamDiffuse;
					float4 _DamDiffuse_TexelSize;
					sampler2D _DamDiffuse2;
					float4 _DamDiffuse2_TexelSize;
					
#				endif

				sampler2D _BloodPattern;
				float4 _BloodPattern_ST;


				float GetShowNext(float currentHeight, float newHeight, float dotNormal)
				{
					return smoothstep(0, 0.2, newHeight * dotNormal - currentHeight * (1-dotNormal));
				}

				void CombineMaps(inout float currentHeight, inout float4 madsMap, out float3 tnormal, out float showNew, float dotNormal, float2 uv)
				{
					tnormal = UnpackNormal(tex2D(_BumpMap, uv));
					float4 newMadspMap = tex2D(_SpecularMap, uv);
					float newHeight = 0.5 + newMadspMap.b*0.5;  

					showNew = GetShowNext(currentHeight, newHeight, dotNormal);
					currentHeight = lerp(currentHeight,newHeight ,showNew);
					madsMap = lerp(madsMap, newMadspMap, showNew);
				}


				float _Reflectivity;


				
#if _OFFSET_BY_HEIGHT
				FragColDepth frag(v2f i)
#else 
				float4 frag(v2f i) : COLOR
#endif
				{
					float3 viewDir = normalize(i.viewDir.xyz);
				//	float2 screenUV = i.screenPos.xy / i.screenPos.w;

				
				
					float3 preNormal;
#if _BEVELED

					float4 seam = i.color;

					//return seam;
					float edgeColorVisibility;
					preNormal = GetBeveledNormal_AndSeam(seam, i.edge,viewDir, i.normal.xyz, i.snormal.xyz, i.edgeNorm0, i.edgeNorm1, i.edgeNorm2, edgeColorVisibility);
					
				

#else
					preNormal = i.normal.xyz;
#endif

					float3 distanceToCamera = length(_WorldSpaceCameraPos - i.worldPos);

					
#if _SDF_Bevel

					float coef = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;//0.5;

					float oobSDF;
					float4 sdfWorld = SampleSDF(i.worldPos , oobSDF);
					sdfWorld.a += oobSDF * 1000;

					//return sdfWorld.w;
					float useSdf = smoothstep(1, 0.75, abs(dot(sdfWorld.xyz, preNormal))) * (1-oobSDF);

				//	return useSdf;

				
					/*
				#if _BEVELED 
					edgeColorVisibility = lerp(edgeColorVisibility, 1, useSdf);
					_EdgeColor.a = lerp(_EdgeColor.a, 1, useSdf);
				#endif
				*/
#endif
					
					float3 normal = preNormal;

				
					float3 uvHor = i.worldPos * _HorizontalTiling;
					float2 tiling = _MainTex_ST.xy;
					float2 damageUV = uvHor.zy%1;
					// Horizontal Sampling X
					float3 tnormalX = UnpackNormal(tex2D(_BumpMap, uvHor.zy * tiling));
					float4 madsMap = tex2D(_SpecularMap, uvHor.zy * tiling);
					float horHeight = madsMap.b;
					
					float4 tex = tex2D(_MainTex, uvHor.zy * tiling);

					float3 horNorm = float3( 0 , tnormalX.y, tnormalX.x);

					// Horixontal Sampling Z
					float3 tnormalZ;
					float showZ;
					CombineMaps(horHeight, madsMap, tnormalZ, showZ, abs(normal.z) , uvHor.xy * tiling);

					float4 texZ = tex2Dlod(_MainTex, float4(uvHor.xy * tiling, 0, 0));

					//return texZ;
					damageUV = lerp(damageUV, uvHor.xy%1, abs(preNormal.z));
					tex = lerp(tex,texZ ,showZ);

					horNorm = lerp(horNorm, float3(tnormalZ.x, tnormalZ.y, 0), showZ);

					// Update normal
					float horBumpVaidity = 1-abs(normal.y);
					normal = normalize(normal + horNorm * horBumpVaidity);
					
					// Vertial Sampling
					float4 texTop = tex2Dlod(_MainTex, float4(uvHor.xz * tiling, 0, 0));

					float3 tnormalTop = UnpackNormal(tex2D(_BumpMap, uvHor.xz * tiling ));
					float3 topNorm = float3(tnormalTop.x, 0, tnormalTop.y);

					float4 madsMapTop = tex2D(_SpecularMap, uvHor.xz * tiling);
					float topHeight = 0.5 + madsMapTop.b * 0.5;

				

					// Combine

					float showTop = GetShowNext(horHeight, topHeight, pow(abs(normal.y),2));
					
					float height = lerp(horHeight,topHeight ,showTop);
					tex = lerp(tex, texTop ,showTop);

					damageUV = lerp(damageUV, uvHor.xz % 1, abs(preNormal.y));

					madsMap = lerp(madsMap, madsMapTop, showTop);

					float3 triplanarNorm = lerp(horNorm, topNorm, showTop);


				#if _SDF_Bevel
					preNormal = lerp(preNormal, sdfWorld.xyz, useSdf);
				#endif


					normal = normalize(preNormal.xyz + triplanarNorm * 3);

#if _BEVELED
					float disAndAo = 1-(1-madsMap.g)* (1-madsMap.b);

					edgeColorVisibility = smoothstep((1 - disAndAo)*0.75,1, edgeColorVisibility);
					tex = lerp(tex, _EdgeColor, edgeColorVisibility * _EdgeColor.a);
					madsMap = lerp(madsMap, _EdgeMads, edgeColorVisibility);
					normal = normalize(lerp(normal, preNormal, edgeColorVisibility));
#endif

					// Add Damage

					float ao = madsMap.g ;
					

					//	ao = lerp(ao,1, rawFresnel);

					float2 damProjectionUV =
#					if _BEVELED
						damageUV;
#					elif _DAM_UV_1
						i.texcoord;
#					else
						i.texcoord1;
#					endif

					float noise = tex2D(_BloodPattern, damProjectionUV * _BloodPattern_ST.xy).r;

					float water = 0;

					float displacement = madsMap.b;

						float showRed = 0;
#				if _DAMAGED

					// R - Blood
					// G - Damage
					
					float2 damUV =

#					if _BEVELED || _DAM_UV_1
						i.texcoord;
#					else
						i.texcoord1;
#					endif

					// X - zy
					// Y - xz
					// Z - xy

					float4 mask = tex2D(_Damage_Tex, damUV) * (0.5 + noise);// .r;// -mask.g;

					float2 damPix = _Damage_Tex_TexelSize.xy;

					float maskY = tex2D(_Damage_Tex, damUV + float2(0, damPix.y)).g;
					float maskX = tex2D(_Damage_Tex, damUV + float2(damPix.x, 0)).g;

					float damDepth = mask.g * (1 + (madsMap.b + madsMap.g) * 0.5);

					const float SHOW_THOLD = 0.01;

					float damAlpha = smoothstep(SHOW_THOLD, SHOW_THOLD + 0.2, damDepth);

					float flatten = (0.01 + damDepth);

					float forOff = mask.g;

					float2 offMask = float2(maskX - forOff, maskY - forOff);

					float3 damBump = float3(
						preNormal.x * flatten
						+ abs(preNormal.z) * offMask.y
						- abs(preNormal.y) * offMask.x
						,
						preNormal.y * flatten
						- preNormal.z * offMask.x
						+ preNormal.x * offMask.x
						,
						preNormal.z * flatten - preNormal.y * offMask.y + abs(preNormal.x) * offMask.y // Correct
						);

					normal = normalize(lerp(normal, damBump, damAlpha));

					float4 dam = tex2D(_DamDiffuse, damProjectionUV *4 + offMask * 0.2);
					float4 dam2 = tex2D(_DamDiffuse2, damProjectionUV);

					float damAlpha2 = smoothstep(0.25, 0.45, damDepth);

					dam = lerp(dam, dam2, damAlpha2);
				
					tex = lerp(tex * (1- damAlpha), dam, damAlpha);

					float brightness = dot(dam.rgb, dam.rgb);

					float dentAmbient =  (2-brightness) * (1 + damDepth);

					ao = lerp(ao, smoothstep(8, 0, dentAmbient), damAlpha);

					madsMap = lerp(madsMap, float4(0, ao, 0.5, 0), damAlpha);

					water = lerp(water, 0, damAlpha);

					displacement = madsMap.b;

					float damHole = smoothstep(4, 0, damDepth);

					mask *= smoothstep(0, 1, (2 - damHole));

					showRed = ApplyBlood(mask, water, tex.rgb, madsMap, displacement);

#				endif

#if _COLOR_R_AMBIENT
					ao *= (0.25 + i.color.r * 0.75);
#endif

	//ao*= (1- GetAmbientOccusion(screenUV, viewDir, i.worldPos));


float shadow = SHADOW_ATTENUATION(i);
float glossLayer = 0;

					// ********************** WATER

#if _qc_USE_RAIN || _DAMAGED

					float rain = GetRain(i.worldPos, normal, i.normal, shadow);

					glossLayer = ApplyWater(water, rain, ao, displacement, madsMap, triplanarNorm, i.worldPos, i.normal.y);

					#if _DAMAGED
						madsMap.r = lerp(madsMap.r,1, step(0.0001, showRed));
					#endif

					float3 tmpNormal = preNormal;
					ApplyTangent(tmpNormal, triplanarNorm, i.wTangent);

					normal = lerp(normal, tmpNormal, glossLayer);
#endif


//#if _SDF_AMBIENT
float3 worldPosAdjusted = i.worldPos;
	ao *=SampleContactAO_OffsetWorld(worldPosAdjusted, normal);
//#endif

// ********************* LIGHT

					float fresnel = GetFresnel_FixNormal(normal, i.normal.xyz, viewDir) * ao;//GetFresnel(normal, viewDir) * ao;

					float rawFresnel = smoothstep(1,0, dot(viewDir, normal));


					float metal = madsMap.r;
					float specular = madsMap.a; // GetSpecular(madsMap.a, fresnel * _Reflectivity, metal);

#if _DAMAGED
					specular *= (6 - showRed * noise) / 6;
#endif

					

					ModifyColorByWetness(tex.rgb, water, madsMap.a);
					float4 traced = float4(1,0,1,1);

					//return float4(normal,1);

					MaterialParameters precomp;
					
					precomp.shadow = shadow;
					precomp.ao = ao;
					precomp.fresnel = fresnel;
					precomp.tex = tex;
					precomp.smoothsness= specular;
					precomp.reflectivity= _Reflectivity;
					precomp.metal = metal;
					precomp.traced = traced;
					precomp.water = water;
					precomp.microdetail = 0;
					precomp.metalColor = lerp(tex, _MetalColor, _MetalColor.a);
					//normal = i.snormal.xyz;

					float3 col = GetReflection_ByMaterialType(precomp, normal,  preNormal, viewDir, worldPosAdjusted);



					/*
					float direct = shadow * smoothstep(1 - ao, 1.5 - ao * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));
					float3 lightColor = GetDirectional() * direct;// *skyShadow;

					// LIGHTING
					float3 bake;
					float outOfBounds;

					float3 avaragedAmbient = GetAvarageAmbient(normal);
						
					float3 volumeSamplePosition = i.worldPos + preNormal * _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

					bake = SampleVolume_CubeMap(volumeSamplePosition, normal);




					//float2 	topdownUv = (i.worldPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;
					TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
					float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, i.worldPos);
					ao *= topDownAmbient.a;
					bake += topDownAmbient.rgb;

					ModifyColorByWetness(tex.rgb, water);

					float3 reflectionColor = 0;
					float3 pointLight = GetPointLight(volumeSamplePosition, normal, ao, viewDir, specular, reflectionColor);


					float3 col = tex.rgb * (lightColor + pointLight + bake * ao);



						// *********************  Reflections

					float3 reflectedRay = reflect(-viewDir, normal);

					float4 topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, i.worldPos, i.normal.xyz, specular);

					float3 reflectedBake = GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular);

					ao *= topDownAmbientSpec.a;

					//return fresnel;

					float specularReflection = GetDirectionalSpecular(normal, viewDir, specular);// pow(dott, power) * brightness;

					reflectionColor +=
						specularReflection * lightColor
						+ (topDownAmbientSpec.rgb + reflectedBake)
						* ao
						;

					float reflectivity = specular + (1-specular) * _Reflectivity * fresnel * ao;


					MixInSpecular_Layer(col, reflectionColor, tex, metal, reflectivity, fresnel,glossLayer);
					*/

					ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);



#if _OFFSET_BY_HEIGHT
					FragColDepth mobres;
					//edgeColorVisibility
					float depthOffset = (1- edgeColorVisibility) * (height - 0.5) * (1 + rawFresnel * rawFresnel * 4) * 0.2;

					mobres.depth = calculateFragmentDepth(i.worldPos + depthOffset * viewDir);
					mobres.col = float4(col, 1);

					return mobres;
#else 
					return float4(col, 1);
#endif

					//return float4(col,1);

				}
				ENDCG
			}

			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

		}
		Fallback "Diffuse"
	}
}