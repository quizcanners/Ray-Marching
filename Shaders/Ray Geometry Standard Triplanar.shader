Shader "RayTracing/Geometry/Standard Triplanar"
{
	Properties
	{
		[KeywordEnum(Nonmetal, Metal, Glass)] _SURFACE("Surface", Float) = 0

		_HorizontalTiling("Tiling", float) = 1
		_MainTex("Cliffs Albedo (RGB)", 2D) = "white" {}
		
		[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_Map("Cliffs Bump/Combined Map (or None)", 2D) = "gray" {}
		_OcclusionMap(" Cliffs Height Map", 2D) = "white" {}
		
		_Overlay("Overlay (RGBA)", 2D) = "white" {}
		_OverlayTiling("Overlay Tiling", float) = 1

		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0

		[Toggle(_SHOWUVTWO)] thisDoesntMatter("Debug Uv 2", Float) = 0

		[Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
		_SubSurface("Sub Surface Scattering", Color) = (1,0.5,0,0)
		_SkinMask("Skin Mask (_UV2)", 2D) = "white" {}
	}

	Category
	{
		SubShader
		{
			CGINCLUDE
				#define RENDER_DYNAMICS

				#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
				#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
				#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
				#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"
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

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON

				#pragma shader_feature_local _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 
				#pragma shader_feature_local _SURFACE_NONMETAL _SURFACE_METAL _SURFACE_GLASS  
				
				#pragma shader_feature_local ___ _COLOR_R_AMBIENT

				#pragma shader_feature_local ___ _SUB_SURFACE
				#pragma shader_feature_local ___ _SHOWUVTWO
				#pragma multi_compile ___ _qc_Rtx_MOBILE

				struct v2f 
				{
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float2 texcoord1	: TEXCOORD1;
					float3 worldPos		: TEXCOORD2;
					float3 normal		: TEXCOORD3;
					float4 wTangent		: TEXCOORD4;
					float3 viewDir		: TEXCOORD5;
					float2 topdownUv : TEXCOORD7;
					SHADOW_COORDS(8)
					float2 lightMapUv : TEXCOORD9;
					//float4 screenPos	: TEXCOORD10;
					fixed4 color : COLOR;
				};

				sampler2D _MainTex_ATL_UvTwo;
				float4 _MainTex_ATL_UvTwo_TexelSize;

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
					o.lightMapUv = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
					//o.screenPos = ComputeScreenPos(o.pos);

					TRANSFER_WTANGENT(o)
					TRANSFER_TOP_DOWN(o);
					TRANSFER_SHADOW(o);

					return o;
				}

				sampler2D _OcclusionMap;
				sampler2D _Map;
				float4 _Map_ST;
				sampler2D _MainTex;

				
				float GetHeight (out float4 bumpMap, out float3 tnormal, float2 uv)
				{
					SampleBumpMap(_Map, bumpMap, tnormal, uv);

					return
					#if _BUMP_COMBINED
						bumpMap.a;
					#else 
						tex2D(_OcclusionMap, uv).r;
					#endif
				}

				float GetShowNext(float currentHeight, float newHeight, float dotNormal)
				{
					return smoothstep(0, 0.2, newHeight * dotNormal - currentHeight * (1-dotNormal));
				}

				void CombineMaps(inout float currentHeight, inout float4 bumpMap, out float3 tnormal, out float showNew, float3 normal, float dotNormal, float2 uv)
				{
					float4 newbumpMap; 
					float newHeight = GetHeight (newbumpMap,  tnormal,  uv);

					showNew = GetShowNext(currentHeight, newHeight, dotNormal);//smoothstep(0, 0.2, newHeight * dotNormal - currentHeight * (1-dotNormal));
					currentHeight = lerp(currentHeight,newHeight ,showNew);
					bumpMap = lerp(bumpMap,newbumpMap ,showNew);
				}

				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				sampler2D _Bump;
				sampler2D _SkinMask;
				float4 _SubSurface;

				//float _VerticalTiling;
				float _HorizontalTiling;

				float4 frag(v2f o) : COLOR
				{


					#if _qc_Rtx_MOBILE

				float4 mobTex = tex2D(_MainTex, o.texcoord);

				ColorCorrect(mobTex.rgb);

					#if LIGHTMAP_ON
						mobTex.rgb *= DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
					#else 

						float oobMob;
						mobTex.rgb *= SampleVolume(o.worldPos, oobMob).rgb;

					#endif

					return mobTex;

				#endif


					//float2 screenUV = o.screenPos.xy / o.screenPos.w;
					float3 viewDir = normalize(o.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, o.normal.xyz));
					float3 normal = o.normal.xyz;

					//float toCamera = length(_WorldSpaceCameraPos - o.worldPos.xyz) - _ProjectionParams.y;

				

					//Find the pixel level of detail
					float LOD = fwidth(o.worldPos)*4; // toCamera * 0.01; // ;
					//Round LOD down
					float LOD_floor = floor(LOD);
					//Compute the fract part for interpolating
					float LOD_fract = LOD - LOD_floor;

					//return LOD_floor * 0.1;

					 //;
					float3 uvHor = o.worldPos * _HorizontalTiling;
					float3 uvHorBig = uvHor / pow(LOD_floor+2,2); // / exp(LOD_floor + 1);/// (exp(LOD_floor + 1));
					uvHor /= pow(LOD_floor+1,2); ///= exp(LOD_floor); ///= (exp(LOD_floor));


							//return float4(0,0, LOD_fract,1);

					// Horizontal Sampling X
					float3 tnormalX;
					float4 bumpMapHor; 
					float horHeight = GetHeight (bumpMapHor,  tnormalX,  uvHor.zy);
					float4 tex = lerp(
						
						tex2Dlod(_MainTex, float4(uvHor.zy,0,0))
						, tex2Dlod(_MainTex, float4(uvHorBig.zy,0,0)),  LOD_fract);


				//	return tex;


					float3 horNorm = float3( 0 , tnormalX.y, tnormalX.x);

					// Horixontal Sampling Z
					float3 tnormalZ;
					float showZ;
					CombineMaps(horHeight, bumpMapHor, tnormalZ, showZ, normal, abs(normal.z) , uvHor.xy);

					float4 texZ = 
						lerp(
							tex2Dlod(_MainTex, float4(uvHor.xy, 0, 0))
							, tex2Dlod(_MainTex, float4(uvHorBig.xy, 0, 0))
							, LOD_fract);

				

					tex = lerp(tex,texZ ,showZ);

					horNorm = lerp(horNorm, float3(tnormalZ.x, tnormalZ.y, 0), showZ);

					// Update normal
					float horBumpVaidity = 1-abs(normal.y);
					normal = normalize(normal + horNorm * horBumpVaidity);
					
					// Vertial Sampling


					float4 texTop = lerp(
						tex2Dlod(_MainTex, float4(uvHor.xz, 0, 0))
						,tex2Dlod(_MainTex, float4(uvHorBig.xz, 0, 0))
						, LOD_fract);
					float3 tnormalTop;
					float4 bumpMapTop;
					float topHeight = GetHeight(bumpMapTop, tnormalTop, uvHor.xz);

					float3 topNorm = float3(tnormalTop.x , 0, tnormalTop.y);

					//return texTop;

					// Combine

					float showTop = GetShowNext(horHeight, topHeight, pow(abs(normal.y),2));
					
					float height = lerp(horHeight,topHeight ,showTop);
					tex = lerp(tex, texTop ,showTop);

					ColorCorrect(tex.rgb);
				//	return tex;

					float4 bumpMap = lerp(bumpMapHor, bumpMapTop ,showTop);

					float3 triplanarNorm = lerp(horNorm, topNorm, showTop);

					normal = normalize(o.normal.xyz + triplanarNorm * 3);

					float fresnel = saturate(dot(normal,viewDir));

					float showReflected = 1 - fresnel;

					float ambient = 
#if _COLOR_R_AMBIENT
						o.color.r * 
#endif
						smoothstep(0, 0.5, height);

					float smoothness = 
					#if _BUMP_COMBINED
						bumpMap.b;
					#else 
						0.1;
					#endif

					// LIGHTING

					float shadow = SHADOW_ATTENUATION(o) * SampleSkyShadow(o.worldPos);

					#if _SURFACE_NONMETAL  

					
					float4 bakeRaw;
					float outOfBounds;
					float gotVolume;

					#if LIGHTMAP_ON
						float3 lightMap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
						bakeRaw.rgb = lightMap; 
						bakeRaw.a = 0;
						outOfBounds = 0;
						gotVolume = 1;

						//return bakeRaw;
					#else 

						float4 normalAndDist = SdfNormalAndDistance(o.worldPos);

						float3 volumePos = o.worldPos + (normal + normalAndDist.xyz * saturate(normalAndDist.w))
							* lerp(0.5, 1 - fresnel, smoothness) * 0.5
							* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

						outOfBounds;
						bakeRaw = SampleVolume(volumePos, outOfBounds);

						gotVolume = bakeRaw.a * (1 - outOfBounds);
						outOfBounds = 1 - gotVolume;

						bakeRaw.rgb = lerp(bakeRaw.rgb, GetAvarageAmbient(normal), outOfBounds);

						//return bakeRaw;
					#endif

					float4 bake = bakeRaw;
					float3 col;


				
					float direct = shadow * smoothstep(1 - ambient, 1.5 - ambient * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));

					//return shadow;
					float3 lightColor = GetDirectional() * direct;
					

				
					ApplyTopDownLightAndShadow(o.topdownUv,  normal,  bumpMap,  o.worldPos,  gotVolume, fresnel, bake);

					#if _SUB_SURFACE
						float2 damUv = o.texcoord1.xy;
						float4 mask = tex2D(_MainTex_ATL_UvTwo, damUv);

						float skin = tex2D(_SkinMask, damUv);
						float subSurface = _SubSurface.a * skin * (1-mask.g)  * (1+rawFresnel) * 0.5;
					#endif

					col = lightColor * (1 + outOfBounds) + bake.rgb * ambient;
					
					//return ambient;

					col.rgb *=tex.rgb;

				

					AddGlossToCol(lightColor);

					#if _SUB_SURFACE
						col *= 1-subSurface;
						TopDownSample(o.worldPos, bakeRaw.rgb, outOfBounds);
						col.rgb += subSurface * _SubSurface.rgb * (_LightColor0.rgb * shadow + bakeRaw.rgb);
					#endif

					#elif _SURFACE_METAL

						float3 reflectionPos;
						float outOfBoundsRefl;
						float3 bakeReflected = SampleReflection(o.worldPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);

						TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);

						float3 col =  tex.rgb * bakeReflected;

					#elif _SURFACE_GLASS

					//float shadow = 1;
						float3 reflectionPos;
						float outOfBoundsRefl;
						float3 bakeReflected = SampleReflection(o.worldPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);

						TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);

						float outOfBounds;
						float3 straightHit;
						float3 bakeStraight = SampleRay(o.worldPos, normalize(-viewDir - normal*0.5), shadow, straightHit, outOfBounds );

						TopDownSample(straightHit, bakeStraight, outOfBounds);

			

						float3 col;

						col = lerp (bakeStraight,
						bakeReflected , showReflected);

#					endif


					ApplyBottomFog(col, o.worldPos.xyz, viewDir.y);

					return float4(col,1);

				}
				ENDCG
			}


			
			/*
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
				Cull Off //Back
				ZWrite Off

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma shader_feature_local _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 
				
				#pragma shader_feature_local ___ _SUB_SURFACE
				#pragma shader_feature_local ___ _SHOWUVTWO
					#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON

				//  sampler2D _CameraDepthTexture;

				struct v2f {
					float4 pos			: SV_POSITION;
					float3 worldPos		: TEXCOORD1;
					float3 normal		: TEXCOORD2;
					//float4 wTangent		: TEXCOORD3;
					float3 viewDir		: TEXCOORD4;
					SHADOW_COORDS(5)
					float2 topdownUv : TEXCOORD6;
					float4 screenPos : TEXCOORD7;
					float3 tc_Control : TEXCOORD8;
					float2 lightMapUv : TEXCOORD9;
				//	fixed4 color : COLOR;
					
				};

				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.normal.xyz = UnityObjectToWorldNormal(v.normal);

		
					 float toCamera = length(_WorldSpaceCameraPos - worldPos.xyz) - _ProjectionParams.y;

					worldPos.xyz += o.normal.xyz * (0.001 + smoothstep(0,5, smoothstep(0.8, 0.9, o.normal.y) * toCamera) * 0.3); 

					v.vertex = mul(unity_WorldToObject, float4(worldPos.xyz, v.vertex.w));
					o.pos = UnityObjectToClipPos(v.vertex); // don't forget

					o.worldPos = worldPos;
					
					//o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);

					o.screenPos = ComputeScreenPos(o.pos);
					 o.lightMapUv = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
					o.tc_Control = WORLD_POS_TO_TERRAIN_UV_3D(worldPos);
					COMPUTE_EYEDEPTH(o.screenPos.z);
					//TRANSFER_WTANGENT(o)
					TRANSFER_TOP_DOWN(o);
					TRANSFER_SHADOW(o);

					return o;
				}


				float _VerticalTiling;
				sampler2D _Overlay;
				float _OverlayTiling;

				float4 frag(v2f o) : COLOR
				{
					float3 viewDir = normalize(o.viewDir.xyz);
					float2 screenUV = o.screenPos.xy / o.screenPos.w;
					float2 uv = o.worldPos.xz * _OverlayTiling * 1.234;

					float4 tex = tex2D(_Overlay, uv) * smoothstep(0.8, 0.9, o.normal.y);

					float3 normal = o.normal.xyz;

					float fresnel = abs(dot(normal, viewDir));

					float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
					float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));

					 float toCamera = length(_WorldSpaceCameraPos - o.worldPos.xyz) - _ProjectionParams.y;


					 	float4 terrainMask = tex2D(_qcPp_mergeControl, o.tc_Control.xz); 
				//	col.a *= terrainMask.r;

					float fade = 
						smoothstep(0,0.2, sceneZ - o.screenPos.z) *
						smoothstep(0, 0.5, fresnel) *
						smoothstep(5, 8, toCamera) *
						smoothstep(0.75, 1, terrainMask.r);

					tex.a *= fade;


					float smoothness = 0.5 * tex.a;
					float ambient = 1;

					float shadow = SHADOW_ATTENUATION(o);

					float direct = shadow * smoothstep(0.5, 1 , dot(normal, _WorldSpaceLightPos0.xyz));
					
					float3 lightColor = GetDirectional() * direct;

					// LIGHTING

					float4 normalAndDist = SdfNormalAndDistance(o.worldPos);
					
					float3 volumePos = o.worldPos + (normal + normalAndDist.xyz * saturate(normalAndDist.w)) 
						* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

					float outOfBounds;
					float4 bakeRaw = SampleVolume(volumePos, outOfBounds);


					#if LIGHTMAP_ON
						float3 lightMap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
						bakeRaw.rgb = lightMap; 
					#else 
						bakeRaw.rgb = lerp(bakeRaw.rgb, GetAvarageAmbient(normal), outOfBounds);
					#endif

				//	float3 avaragedAmbient = GetAvarageAmbient(normal);
				//	bakeRaw.rgb = lerp(bakeRaw.rgb, avaragedAmbient, outOfBounds); // Up 

					float4 bake = bakeRaw;

					TopDownSample(o.worldPos, bake.rgb, outOfBounds);

					float3 col = lightColor * (1 + outOfBounds) + bake.rgb * ambient;
					

				

					col.rgb *=tex.rgb * 1.5;

					

					AddGlossToCol(lightColor);

					ApplyBottomFog(col, o.worldPos.xyz, viewDir.y);





					return float4(col, tex.a);

				}
				ENDCG
			}
			*/
			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

		}
		Fallback "Diffuse"
	}
}