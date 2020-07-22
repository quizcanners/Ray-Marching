Shader "RayTracing/Terrain/Terrain Itself"
{
	Properties
	{
		[KeywordEnum(Nonmetal, Metal, Glass)] _SURFACE("Surface", Float) = 0

		_HorizontalTiling("Horizontal Tiling", float) = 1
		_MainTex("Cliffs Albedo (RGB)", 2D) = "white" {}
		
		[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_Map("Cliffs Bump/Combined Map (or None)", 2D) = "gray" {}
		_OcclusionMap(" Cliffs Height Map", 2D) = "white" {}
		
		_Overlay("Overlay (RGBA)", 2D) = "white" {}
		_OverlayTiling("Overlay Tiling", float) = 1

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

				#pragma multi_compile ___ _qc_Rtx_MOBILE
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
				#pragma shader_feature_local _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 

				#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON

				struct v2f 
				{
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float2 texcoord1	: TEXCOORD1;
					float3 worldPos		: TEXCOORD2;
					float3 normal		: TEXCOORD3;
					float4 wTangent		: TEXCOORD4;
					float3 viewDir		: TEXCOORD5;
					float2 topdownUv : TEXCOORD6;
					SHADOW_COORDS(7)
					float2 lightMapUv : TEXCOORD8;
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
					o.lightMapUv = v.texcoord1.xy; 

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

				void CombineMaps(inout float currentHeight, inout float4 bumpMap, out float3 tnormal, out float showNew, float dotNormal, float2 uv)
				{
					float4 newbumpMap; 
					float newHeight = GetHeight (newbumpMap,  tnormal,  uv);

					showNew = GetShowNext(currentHeight, newHeight, dotNormal);//smoothstep(0, 0.2, newHeight * dotNormal - currentHeight * (1-dotNormal));
					currentHeight = lerp(currentHeight,newHeight ,showNew);
					bumpMap = lerp(bumpMap,newbumpMap ,showNew);
				}

				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				float _HorizontalTiling;
				sampler2D _Control;

				float4 frag(v2f o) : COLOR
				{

					#if _qc_Rtx_MOBILE

							float4 mobTex = tex2D(_qcPp_mergeSplat_0, o.worldPos.xz * 0.1);

						#if LIGHTMAP_ON
							mobTex.rgb *= DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
						#else 

							float oobMob;
							mobTex.rgb *= SampleVolume(o.worldPos, oobMob).rgb;

						#endif

						return mobTex;

					#endif

					float4 terrain = tex2D(_Control, o.texcoord.xy);


					float3 viewDir = normalize(o.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, o.normal.xyz));
					float3 normal = o.normal.xyz;

					float3 uvHor = o.worldPos * _HorizontalTiling;

					 float toCamera = length(_WorldSpaceCameraPos - o.worldPos.xyz) - _ProjectionParams.y;

					 float useLarge = smoothstep(30, 200, toCamera);

					const float LARGE_UPSCALE = 0.3;

					// Horizontal Sampling X
					float3 tnormalX;
					float4 bumpMapHor; 
					float horHeight = GetHeight (bumpMapHor,  tnormalX,  uvHor.zy);
					float4 tex = lerp( tex2D(_MainTex, uvHor.zy), tex2D(_MainTex, uvHor.zy*LARGE_UPSCALE), useLarge);

					float3 horNorm = float3( 0 , tnormalX.y, tnormalX.x);

					// Horixontal Sampling Z
					float3 tnormalZ;
					float showZ;
					CombineMaps(horHeight, bumpMapHor, tnormalZ, showZ, abs(normal.z) , uvHor.xy);

					float4 texZ = lerp( tex2D(_MainTex,  uvHor.xy), tex2D(_MainTex,  uvHor.xy*LARGE_UPSCALE), useLarge);

					tex = lerp(tex,texZ ,showZ);

					horNorm = lerp(horNorm, float3(tnormalZ.x, tnormalZ.y, 0), showZ);

					// Update normal
					float horBumpVaidity = 1-abs(normal.y);
					normal = normalize(normal + horNorm * horBumpVaidity);
					
					// Vertial Sampling
			
					float4 texTop;
					float4 bumpMapTop; 
					float3 tnormalTop;
					SampleTerrain_0(o.worldPos, texTop, bumpMapTop, tnormalTop);
					float topHeight = bumpMapTop.a;

					float4 texTop1;
					float4 bumpMapTop1; 
					float3 tnormalTop1;
					SampleTerrain_1(o.worldPos, texTop1, bumpMapTop1, tnormalTop1);
					float topHeight1 = bumpMapTop1.a;

					float showTex1 =  smoothstep(-0.1, 0.1, terrain.g * 2 - 1 + topHeight1 - topHeight);

					texTop = lerp(texTop, texTop1, showTex1);
					bumpMapTop = lerp(bumpMapTop, bumpMapTop1, showTex1);
					tnormalTop = lerp(tnormalTop, tnormalTop1, showTex1);
					topHeight = lerp(topHeight, topHeight1, showTex1 );

					float3 topNorm = float3(tnormalTop.x , 0, tnormalTop.y);

					// Combine

					float showTop = GetShowNext(horHeight, topHeight, pow(abs(normal.y),2));
					
					float height = lerp(horHeight,topHeight ,showTop);
					tex = lerp(tex, texTop ,showTop);
					float4 bumpMap = lerp(bumpMapHor, bumpMapTop ,showTop);

					float3 triplanarNorm = lerp(horNorm, topNorm, showTop);


					normal = normalize(o.normal.xyz + triplanarNorm * 3);


					float fresnel = saturate(dot(normal,viewDir));

					float showReflected = 1 - fresnel;

					float ambient = smoothstep(0, 0.5, height);

					float smoothness = 
					#if _BUMP_COMBINED
						bumpMap.b;
					#else 
						0.1;
					#endif


					// LIGHTING

				
					float4 bake;
					float gotVolume;
					float outOfBounds;

					#if LIGHTMAP_ON
						float3 lightMap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
						bake.rgb = lightMap;
						bake.a = 0;
						gotVolume = 1; // Will need to recalculate
						outOfBounds = 0;
						//return bakeRaw;
					#else 

						//float4 normalAndDist = SdfNormalAndDistance(o.worldPos);

						float3 volumePos = o.worldPos + (normal) //+ normalAndDist.xyz * saturate(normalAndDist.w))
							* lerp(0.5, 1 - fresnel, smoothness) * 0.5
							* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

						
						bake = SampleVolume(volumePos, outOfBounds);

						gotVolume = bake.a * (1 - outOfBounds);
						outOfBounds = 1 - gotVolume;

						bake.rgb = lerp(bake.rgb, GetAvarageAmbient(normal), outOfBounds);

					#endif

				
					float shadow = SHADOW_ATTENUATION(o) * SampleSkyShadow(o.worldPos);

					float direct = shadow * smoothstep(1 - ambient, 1.5 - ambient * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));
					
					float3 lightColor = GetDirectional() * direct;

					ApplyTopDownLightAndShadow(o.topdownUv,  normal,  bumpMap,  o.worldPos,  gotVolume, fresnel, bake);

					float3 col = lightColor 
						+ bake.rgb * ambient;
					
					ColorCorrect(tex.rgb);

					col.rgb *=tex.rgb;

					AddGlossToCol(lightColor);

					ApplyBottomFog(col, o.worldPos.xyz, viewDir.y);

					return float4(col,1);

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
				#pragma shader_feature_local _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 
				
				#pragma shader_feature_local ___ _SUB_SURFACE
				#pragma shader_feature_local ___ _SHOWUVTWO
				#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON


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
					
					o.viewDir = WorldSpaceViewDir(v.vertex);

					o.screenPos = ComputeScreenPos(o.pos);
					o.lightMapUv = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
					o.tc_Control = WORLD_POS_TO_TERRAIN_UV_3D(worldPos);
					COMPUTE_EYEDEPTH(o.screenPos.z);
					TRANSFER_TOP_DOWN(o);
					TRANSFER_SHADOW(o);

					return o;
				}


				float _VerticalTiling;
				sampler2D _Overlay;
				float _OverlayTiling;

				float4 frag(v2f o) : COLOR
				{
					float2 uv = o.worldPos.xz * _OverlayTiling * 1.234;

					#if _qc_Rtx_MOBILE

							float4 mobTex = tex2D(_Overlay, uv);

						#if LIGHTMAP_ON
							mobTex.rgb *= DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
						#else 

							float oobMob;
							mobTex.rgb *= SampleVolume(o.worldPos, oobMob).rgb;

						#endif

						mobTex.a *= smoothstep(0.8, 0.9, o.normal.y);

						return mobTex;

					#endif

					float3 viewDir = normalize(o.viewDir.xyz);
					float2 screenUV = o.screenPos.xy / o.screenPos.w;
					

					float4 tex = tex2D(_Overlay, uv) * smoothstep(0.8, 0.9, o.normal.y);

					float3 normal = o.normal.xyz;

					float fresnel = abs(dot(normal, viewDir));

					float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
					float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));

					 float toCamera = length(_WorldSpaceCameraPos - o.worldPos.xyz) - _ProjectionParams.y;


					 	float4 terrainMask = tex2D(_qcPp_mergeControl, o.tc_Control.xz); 
				//	col.a *= terrainMask.r;

					float fade = 
						smoothstep(0,0.2, sceneZ - o.screenPos.z) 
						* smoothstep(0, 0.5, fresnel) 
						* smoothstep(5, 8, toCamera) 
						* smoothstep(0.4, 0.6,  terrainMask.r) 
						;

					tex.a *= fade;


					float smoothness = 0.5 * tex.a;
					float ambient = 1;

					float shadow = getShadowAttenuation(o.worldPos + float3(0,-0.5*tex.a,0)) 	//SHADOW_ATTENUATION(o) 
						* SampleSkyShadow(o.worldPos);

					//return shadow;

					float direct = shadow * smoothstep(0.5, 1 , dot(normal, _WorldSpaceLightPos0.xyz));
					
					float3 lightColor = GetDirectional() * direct;

					// LIGHTING

					float outOfBounds;
					float4 bakeRaw;

					#if LIGHTMAP_ON
						float3 lightMap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
						bakeRaw.rgb = lightMap; 
						bakeRaw.a = 0;
						outOfBounds = 0;

						//return bakeRaw;
					#else 

						float4 normalAndDist = SdfNormalAndDistance(o.worldPos);

						float3 volumePos = o.worldPos + (normal + normalAndDist.xyz * saturate(normalAndDist.w))
							* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

						bakeRaw = SampleVolume(volumePos, outOfBounds);

						bakeRaw.rgb = lerp(bakeRaw.rgb, GetAvarageAmbient(normal), outOfBounds);
					#endif

					float4 bake = bakeRaw;

					TopDownSample(o.worldPos, bake.rgb, outOfBounds);

					float3 col = lightColor +bake.rgb * 0.5;
					
					ColorCorrect(tex.rgb);

					col.rgb *=tex.rgb * 1.5;

				//	AddGlossToCol(lightColor);

					ApplyBottomFog(col, o.worldPos.xyz, viewDir.y);

					return float4(col, tex.a);

				}
				ENDCG
			}
			
			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

		}
		Fallback "Diffuse"
	}
}