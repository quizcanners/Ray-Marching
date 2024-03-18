Shader "QcRendering/Terrain/Terrain Itself"
{
	Properties
	{
		[KeywordEnum(Terrain, MainTex)] _CONTROL("Control Type", Float) = 0

		_MainTex("Control Texture", 2D) = "white" {}

		[Toggle(_OFFSET_BY_HEIGHT)] heightOffset("Offset By Height", Float) = 0
		_HeightOffset("Height Offset", Range(0.01,0.3)) = 0.2

		_HorizontalTiling("Horizontal Tiling", float) = 1
		_Cliff_Tex("Cliffs Albedo (RGB)", 2D) = "white" {}
		_Cliff_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		_Cliff_BumpMap("Normal Map", 2D) = "bump" {}
	
		
		_Overlay("Overlay (RGBA)", 2D) = "white" {}
		_OverlayTiling("Overlay Tiling", float) = 1

		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0


	}

	Category
	{
		SubShader
		{
			CGINCLUDE

			#define RENDER_DYNAMICS

			#pragma target 3.0

			//#pragma multi_compile __ RT_FROM_CUBEMAP 
			#define RENDER_DYNAMICS
			#pragma multi_compile ___ _qc_USE_RAIN

			#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED

			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler.cginc"
			#include "Assets\The-Fire-Below\Common\Shaders\qc_terrain_cg.cginc"

			sampler2D _Control;
			sampler2D _MainTex;

			ENDCG

			Pass
			{
				Tags
				{
					"Queue" = "Geometry"
					"RenderType" = "Opaque"
					"LightMode" = "ForwardBase"
				//"DisableBatching" = "True"
				}

				ColorMask RGBA
				Cull Back
				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				//#pragma multi_compile_instancing

				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				#pragma shader_feature_local _CONTROL_TERRAIN _CONTROL_MAINTEX

				#pragma shader_feature_local ___ _OFFSET_BY_HEIGHT

				//#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
				#pragma multi_compile ____ _qc_WATER

				#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
				#pragma multi_compile __ _qc_IGNORE_SKY 

				struct v2f 
				{
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float3 worldPos		: TEXCOORD1;
					float3 viewDir		: TEXCOORD2;
					float2 topdownUv : TEXCOORD3;
					float2 lightMapUv : TEXCOORD4;
					float3 normal : TEXCOORD5;
					SHADOW_COORDS(6)
					float4 traced : TEXCOORD7;
				};

				sampler2D _CliffTex_ATL_UvTwo;
				float4 _CliffTex_ATL_UvTwo_TexelSize;

				v2f vert(appdata_full v) 
				{
					v2f o;
					//UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = v.texcoord;
					o.worldPos = worldPos;
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					//o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);
					o.lightMapUv = v.texcoord1.xy; 

					o.traced = GetTraced_Mirror_Vert(o.worldPos, normalize(o.viewDir.xyz), o.normal.xyz);


					//TRANSFER_WTANGENT(o)
					TRANSFER_TOP_DOWN(o);
					TRANSFER_SHADOW(o);

					return o;
				}

				float GetShowNext(float currentHeight, float newHeight, float dotNormal)
				{
					return smoothstep(0, 0.2, (0.2+newHeight) * dotNormal - ((0.2+currentHeight) * (1-dotNormal)));
				}

				/*
				void CombineMaps(inout float currentHeight, inout float4 bumpMap, out float3 tnormal, out float showNew, float dotNormal, float2 uv)
				{
					float4 newbumpMap; 
					float newHeight = GetHeight (newbumpMap,  tnormal,  uv);

					showNew = GetShowNext(currentHeight, newHeight, dotNormal);//smoothstep(0, 0.2, newHeight * dotNormal - currentHeight * (1-dotNormal));
					currentHeight = lerp(currentHeight,newHeight ,showNew);
					bumpMap = lerp(bumpMap,newbumpMap ,showNew);
				}*/

				float4 _CliffTex_ST;
				float4 _CliffTex_TexelSize;
				float _HorizontalTiling;
				float _HeightOffset;

				sampler2D _Cliff_Tex;
				sampler2D _Cliff_SpecularMap;
				sampler2D _Cliff_BumpMap;


#if _OFFSET_BY_HEIGHT
				FragColDepth frag(v2f i)
#else 
				float4 frag(v2f i) : COLOR
#endif
				{
					#if _CONTROL_TERRAIN 
						float4 terrainControl = tex2D(_Control, i.texcoord.xy);
					#else
						float4 terrainControl = tex2D(_MainTex, i.texcoord.xy);
					#endif

					float4 terrainHeight = tex2D(_qcPp_mergeTerrainHeight, i.texcoord.xy);
					float3 terrainNormal = (terrainHeight.rgb - 0.5) * 2;

					float overlay = smoothstep(0.75, 0.5, terrainControl.g + terrainControl.b + terrainControl.a);
					overlay = (2 - overlay * smoothstep(0.85, 1, terrainNormal.y)) * 0.5;

					float3 viewDir = normalize(i.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, terrainNormal));
					float offsetAmount = (1 + rawFresnel * rawFresnel * 4);

					float3 uvHor = i.worldPos * _HorizontalTiling;
					 float toCamera = length(_WorldSpaceCameraPos - i.worldPos.xyz) - _ProjectionParams.y;
					 float useLarge = smoothstep(30, 100, toCamera);


					const float LARGE_UPSCALE = 0.3;


					float2 uvHor_Large = uvHor.zy*LARGE_UPSCALE;
					// Horizontal Sampling X
		
					float3 tex = lerp( tex2D(_Cliff_Tex, uvHor.zy), tex2D(_Cliff_Tex,uvHor_Large), useLarge);
					float4 mads = lerp( tex2D(_Cliff_SpecularMap, uvHor.zy), tex2D(_Cliff_SpecularMap, uvHor_Large), useLarge);
					float3 bump = UnpackNormal(lerp( tex2D(_Cliff_BumpMap, uvHor.zy), tex2D(_Cliff_BumpMap, uvHor_Large), useLarge));

					float3 horNorm = float3(0 ,-bump.y, -bump.x);
					float horHeight = mads.b;

					// Horixontal Sampling Z
					uvHor_Large = uvHor.xy*LARGE_UPSCALE;

					float3 texZ = lerp( tex2D(_Cliff_Tex,  uvHor.xy).rgb, tex2D(_Cliff_Tex,  uvHor_Large).rgb, useLarge);
					float4 madsZ = lerp( tex2D(_Cliff_SpecularMap, uvHor.xy), tex2D(_Cliff_SpecularMap, uvHor_Large), useLarge);
					float3 bumpZ = UnpackNormal(lerp( tex2D(_Cliff_BumpMap, uvHor.xy), tex2D(_Cliff_BumpMap, uvHor_Large), useLarge));

					float showZ = GetShowNext(horHeight, madsZ.b, abs(i.normal.z));

					float3 tnormalZ;
					

				//	return showZ;

				//	CombineMaps(horHeight, bump, tnormalZ, showZ, abs(normal.z) , uvHor.xy);


					tex = lerp(tex,texZ ,showZ);
					mads = lerp(mads, madsZ, showZ);
					horNorm = lerp(horNorm, float3(-bumpZ.x, -bumpZ.y, 0), showZ);

				//	return madsZ;

				//	horHeight = mads.b;
				
					float4 terrain_Mads;
					float3 vertical_Normal = terrainNormal;
					float3 terrain_Tex = GetTerrainBlend(i.worldPos, terrainControl, terrain_Mads, vertical_Normal);
					float showTerrain = GetShowNext( mads.b, terrain_Mads.b, abs(i.normal.y));

				//	return showTerrain;

					//return float4 (horNorm * (1-showTerrain),1);

					//showTerrain = 0;

					tex = lerp(tex, terrain_Tex, showTerrain);
					mads = lerp(mads, terrain_Mads, showTerrain);
					float3 normal = normalize(lerp((horNorm + i.normal) * 0.5, vertical_Normal, showTerrain));

					
				//	return float4(normal,1);

				//	Terrain_CombineLayers(texTop, texTopNext, bumpMapTop, bumpMapTop_Next,
					//	tnormalTop, tnormalTop_Next, topHeight, topHeight_Next, terrainControl.a);

					//float3 topNorm = float3(tnormalTop.x , 0, tnormalTop.y);

					// Combine

				//	float showTop = GetShowNext(horHeight, topHeight, pow(normal.y, 1.45)); // smoothstep(0.6, 0.75, abs(normal.y))); //);
					
				//	float height = lerp(horHeight,topHeight ,showTop);
					//tex = lerp(tex, texTop ,showTop);
				//	float4 bumpMap = lerp(bumpMapHor, bumpMapTop ,showTop);

				//	float3 triplanarNorm = lerp(horNorm, topNorm, showTop);

				

					//normal = normalize(terrainNormal + normal * 2);


					float ao = mads.g;

					// LIGHTING

// ********************** WATER
					float water = 0;


#if _qc_WATER
					float waterLevel = i.worldPos.y - _qc_WaterPosition.y;

					water = smoothstep(1, 0, abs(waterLevel));

					//tex.a = lerp(tex.a, 0.7, smoothstep(1, 0, abs(waterLevel)));
					//tex.a = lerp(tex.a, 0.1, smoothstep(0, -0.1, waterLevel));
#endif

	float shadow = SHADOW_ATTENUATION(i) * overlay;

					float displacement = mads.b;
#if _qc_USE_RAIN 

					float rain = GetRain(i.worldPos, normal, i.normal, shadow);

					rain *= 0.75; // For Terrain only

					float flattenWater = ApplyWater(water, rain, ao, displacement, mads, normal, i.worldPos, normal.y);

					normal = lerp(normal, terrainNormal, flattenWater);

					//return displacement;

#endif

					// **************** light

					float metal = mads.r;
					float fresnel = GetFresnel(normal, viewDir);
					ao += fresnel * (1-ao); 
					fresnel *= ao;

					float specular = mads.a * mads.a; //GetSpecular(mads.a, fresnel, metal);

				//	return mads.g;

				

					float3 lightColor = Savage_GetDirectional_Opaque(shadow, ao, normal, i.worldPos);
					
					// LIGHTING
					float3 bake;
					float3 volumeSamplePosition = i.worldPos;

#if LIGHTMAP_ON
					float3 lightMap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightMapUv));
					bake = lightMap;
#elif _SIMPLIFY_SHADER
					bake = GetAvarageAmbient(normal);
#else
					bake = Savage_GetVolumeBake(i.worldPos, normal, i.normal, volumeSamplePosition);

#endif

					TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
					float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, i.worldPos);
					ao *= topDownAmbient.a;
					bake += topDownAmbient.rgb;
			

					ModifyColorByWetness(tex.rgb, water, mads.a);

					float3 reflectionColor = 0;
					float3 pointLight = GetPointLight(volumeSamplePosition, normal, ao, viewDir, specular, reflectionColor);

					float3 col = tex.rgb * (pointLight + lightColor + bake * ao);

					// ******************* Reflections

#if !LIGHTMAP_ON
					float3 reflectedRay = reflect(-viewDir, normal);

					float4 topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, i.worldPos, i.normal.xyz, specular);
					ao *= topDownAmbientSpec.a;
					reflectionColor += topDownAmbientSpec.rgb;

					reflectionColor += GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular, i.traced);
					reflectionColor *= ao;

					///return specular;

					reflectionColor += GetDirectionalSpecular(normal, viewDir, specular * 0.95) * lightColor;

					//float specularReflection = GetDirectionalSpecular(normal, viewDir, specular * 0.95);// pow(dott, power) * brightness;

				//	float3 reflectionColor = specularReflection * lightColor
						//+ (topDownAmbientSpec.rgb + reflectedBake) * ao ;


					MixInSpecular(col, reflectionColor, tex, metal, specular, fresnel);
#endif
				

					ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

#if _OFFSET_BY_HEIGHT
					FragColDepth result;
					result.depth = calculateFragmentDepth(i.worldPos + (displacement - 0.95) * offsetAmount * viewDir * _HeightOffset);
					result.col = float4(col, 1);

					return result;
#else 
					return float4(col, 1);
#endif


				}
				ENDCG
			}


			
			
			Pass
			{
			
				Tags
				{
					"Queue" = "Transparent"
					"IgnoreProjector" = "True"
					"RenderType" = "Transparent"
				}

				Blend SrcAlpha OneMinusSrcAlpha
				ColorMask RGBA
				Cull Off 
				ZWrite Off

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma shader_feature_local _CONTROL_TERRAIN _CONTROL_MAINTEX

				#pragma shader_feature_local ___ _SUB_SURFACE
				#pragma shader_feature_local ___ _SHOWUVTWO
				#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON


				struct v2f {
					float4 pos			: SV_POSITION;
					float3 worldPos		: TEXCOORD1;
					float3 normal		: TEXCOORD2;
					float3 tangentViewDir : TEXCOORD3;
					float3 viewDir		: TEXCOORD4;
					SHADOW_COORDS(5)
					float4 screenPos : TEXCOORD7;
					float3 tc_Control : TEXCOORD8;
					
				};

				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.normal.xyz = UnityObjectToWorldNormal(v.normal);

					float toCamera = 5 +  (length(_WorldSpaceCameraPos - worldPos.xyz) - _ProjectionParams.y)*0.1;

					worldPos.xyz += o.normal.xyz * (0.01 + smoothstep(0,20, smoothstep(0.8, 0.9, o.normal.y) * toCamera)*0.3 ); 

					v.vertex = mul(unity_WorldToObject, float4(worldPos.xyz, v.vertex.w));
					o.pos = UnityObjectToClipPos(v.vertex); // don't forget

					o.worldPos = worldPos;
					
					o.viewDir = WorldSpaceViewDir(v.vertex);

					o.screenPos = ComputeScreenPos(o.pos);
					o.tc_Control = WORLD_POS_TO_TERRAIN_UV_3D(worldPos);
					COMPUTE_EYEDEPTH(o.screenPos.z);
					TRANSFER_SHADOW(o);


					TRANSFER_TANGENT_VIEW_DIR(o);

					return o;
				}


				float _VerticalTiling;
				sampler2D _Overlay;
				float _OverlayTiling;
				sampler2D _CameraDepthTexture;

				float4 frag(v2f i) : COLOR
				{

#if _CONTROL_TERRAIN 
					float4 terrainMask = tex2D(_Control, i.tc_Control.xz);
#else

					float4 terrainMask = tex2D(_MainTex, i.tc_Control.xz);
#endif

					float grassVisibility = smoothstep(0.75, 0.5, terrainMask.g + terrainMask.b + terrainMask.a);

					float2 uv = i.worldPos.xz * _OverlayTiling;


					i.tangentViewDir = normalize(i.tangentViewDir);
					i.tangentViewDir.xy /= (i.tangentViewDir.z + 0.42);
					// or ..... /= (abs(i.tangentViewDir.z) + 0.42); to work on both sides of a plane
					uv += i.tangentViewDir.xy * 0.005 * (grassVisibility - 0.5); // *(0.01 + grassBig.a * 0.001);



					float toCamera = length(_WorldSpaceCameraPos - i.worldPos.xyz) - _ProjectionParams.y;

					float4 grassBig = tex2D(_Overlay, (uv) * 1.567);

					float3 gyrPos = i.worldPos*0.1 + float3(_SinTime.x, _Time.x, 0);

					//float gyr = abs(dot(sin(gyrPos), cos(gyrPos.zxy)));
					//float gyrY = abs(dot(sin(gyrPos.zyx * 1.23), cos(gyrPos.yzx * 0.869)));
					//return gyr;

					float4 noise = Noise3D(gyrPos);

					float strength = 0.001 * (noise.r + 1 + toCamera * grassBig.a);

					float2 gyrUV = (noise.gb - 0.5) * strength;

					//gyr *= strength;
					//gyrY *= strength;

					//float2 gyrUV = float2(gyr, gyrY) * 2.234;

					uv += i.tangentViewDir.xy * 0.001 * (grassBig.a - 0.5);
					grassBig = tex2D(_Overlay, (uv + gyrUV) * 1.567);


					float4 tex = tex2D(_Overlay, (uv + gyrUV) * 3.12345  );

				//	return tex;

					tex += grassBig * (1-tex.a);//lerp(tex, , showLargeGrass);

					float3 normal = i.normal.xyz;
					tex.a *= smoothstep(0.8, 0.9, i.normal.y);

					tex.a *= grassVisibility;


					clip(tex.a - 0.01);

//					return tex;

					float3 viewDir = normalize(i.viewDir.xyz);
					float2 screenUV = i.screenPos.xy / i.screenPos.w;
					
					//float deFresnel = abs(dot(normal, viewDir));

					float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
					float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));

					float fade = 
						smoothstep(0,0.001 + 0.1f * tex.a, sceneZ - i.screenPos.z)	;

					tex.a *= fade;

					float smoothness = 0.5 * tex.a;
					float ambient = 1;

					float shadow = SHADOW_ATTENUATION(i);

					float3 lightColor = Savage_GetDirectional_Opaque(shadow, ambient, normal, i.worldPos);

					float3 volumeSamplePosition;
					float3 bake = Savage_GetVolumeBake(i.worldPos, normal, i.normal, volumeSamplePosition);

					TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
					float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, i.worldPos);
					ambient *= topDownAmbient.a;
					bake += topDownAmbient.rgb;

					float3 col = tex.rgb * (lightColor + bake * ambient);

					ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);
					return float4(col,  tex.a);

				}
				ENDCG
			}
			
			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

		}
		Fallback "Diffuse"
	}
}