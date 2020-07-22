Shader "GPUInstancer/RayTracing/Terrain/Standard Merging"
{
	Properties
	{
		[KeywordEnum(Nonmetal, Metal, Glass)] _SURFACE("Surface", Float) = 0

		_MainTex("Main Albedo (RGB)", 2D) = "white" {}
		
		[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_Map("Main Bump/Combined Map (or None)", 2D) = "gray" {}
		_Ambient("Main Height Map", 2D) = "white" {}

		_MergeHeight("Merge Height", Range(0,20)) = 1

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
#include "UnityCG.cginc"
#include "./../../GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
#pragma instancing_options procedural:setupGPUI
#pragma multi_compile_instancing

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fwdbase
				#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
				#pragma multi_compile ___ _qc_Rtx_MOBILE

				#pragma shader_feature_local _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 
				#pragma shader_feature_local _SURFACE_NONMETAL _SURFACE_METAL _SURFACE_GLASS  
				#pragma shader_feature_local ___ _SUB_SURFACE
				#pragma shader_feature_local ___ _SHOWUVTWO

				struct v2f 
				{
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float2 texcoord1	: TEXCOORD1;
					float3 worldPos		: TEXCOORD2;
					float3 normal		: TEXCOORD3;
					float4 wTangent		: TEXCOORD4;
					float3 viewDir		: TEXCOORD5;
					float3 tc_Control : TEXCOORD6;
					float2 topdownUv : TEXCOORD7;
					SHADOW_COORDS(8)
					float2 lightMapUv : TEXCOORD9;
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
					o.tc_Control = WORLD_POS_TO_TERRAIN_UV_3D(worldPos);
					o.lightMapUv = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;

					TRANSFER_WTANGENT(o)
					TRANSFER_TOP_DOWN(o);
					TRANSFER_SHADOW(o);

					return o;
				}

				sampler2D _MainTex;
				sampler2D _Ambient;
				sampler2D _Map;
				float4 _Map_ST;
				sampler2D _Diffuse;
				float _MergeHeight;
				
				float GetHeight (out float4 bumpMap, out float3 tnormal, float2 uv)
				{
					SampleBumpMap(_Map, bumpMap, tnormal, uv);

					return
					#if _BUMP_COMBINED
						bumpMap.a;
					#else 
						tex2D(_Ambient, uv).r;
					#endif
				}

				float GetShowNext(float currentHeight, float newHeight, float dotNormal)
				{
					return smoothstep(0, 0.2, lerp (currentHeight, newHeight, dotNormal));
				}

				void CombineMaps(inout float currentHeight, inout float4 col, inout float4 bumpMap, out float3 tnormal, out float showNew, float3 normal, float dotNormal, float2 uv)
				{
					float4 newbumpMap; 
					float newHeight = GetHeight (newbumpMap,  tnormal,  uv);

					showNew = GetShowNext(currentHeight, newHeight, dotNormal);//smoothstep(0, 0.2, newHeight * dotNormal - currentHeight * (1-dotNormal));
					currentHeight = lerp(currentHeight,newHeight ,showNew);
					col = lerp(col,tex2D(_Diffuse,uv) ,showNew);
					bumpMap = lerp(bumpMap,newbumpMap ,showNew);
				}

				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				sampler2D _Bump;
				sampler2D _SkinMask;
				float4 _SubSurface;

				float4 frag(v2f o) : COLOR
				{
					float4 tex = tex2D(_MainTex, o.texcoord);
					
					#if _qc_Rtx_MOBILE

					ColorCorrect(tex.rgb);
						#if LIGHTMAP_ON
							tex.rgb *= DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
						#else 
							float oobMob;
							tex.rgb *= SampleVolume(o.worldPos, oobMob).rgb;
						#endif

						return tex;

					#endif

					float3 viewDir = normalize(o.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, o.normal.xyz));
					float3 normal = o.normal.xyz;

					float2 terrainUV = o.tc_Control.xz;
					float4 terrain = tex2D(_qcPp_mergeTerrainHeight, terrainUV);
					

					float3 terrainNormal = (terrain.rgb - 0.5)*2;
					float aboveTerrain = (o.worldPos.y - _qcPp_mergeTeraPosition.y) - saturate(terrain.a)*_qcPp_mergeTerrainScale.y;

					//return aboveTerrain;

					normal = lerp(terrainNormal, normal, smoothstep(0.2,0.5, aboveTerrain));

					//return normal.y;

					float4 bumpMapMain;
					float3 tnormal;
					float mainHeight = GetHeight (bumpMapMain,  tnormal, o.texcoord);

					ApplyTangent(normal, tnormal, o.wTangent);

					// Vertial Sampling
					float4 texTop;
					float4 bumpMapTop; 
					float3 tnormalTop;
					SampleTerrain_0(o.worldPos, texTop, bumpMapTop, tnormalTop);
					float terrainHeight = bumpMapTop.a;

					float3 topNorm = float3(tnormalTop.x , 0, tnormalTop.y);

					// Combine

					float isLookingUp =  max(0, normal.y) * terrainHeight;
					float terrainEdge = _MergeHeight * isLookingUp;
					float showTerrain = smoothstep(terrainEdge, terrainEdge*0.25, aboveTerrain) ;
					
					float height = lerp(mainHeight, terrainHeight ,showTerrain);
					tex = lerp(tex, texTop ,showTerrain);
					float4 bumpMap = lerp(bumpMapMain, bumpMapTop ,showTerrain);

					normal = lerp(normal, normalize(o.normal.xyz + topNorm), showTerrain);

					float fresnel = saturate(dot(normal,viewDir));
					float showReflected = 1 - fresnel;

					float smoothness = 
					#if _BUMP_COMBINED
						bumpMap.b;
					#else 
						0.1;
					#endif

					

					float shadow = SHADOW_ATTENUATION(o) * SampleSkyShadow(o.worldPos);

				//	smoothness = shadow;

				//	return shadow;

					float ambient = smoothstep(0, 0.5, height); // - SceneSdf(o.worldPos, 5));

					float direct = shadow * smoothstep(1 - ambient, 1.5 - ambient * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));
					
					float3 lightColor = GetDirectional() * direct;

					// LIGHTING

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
					#else 
					float4 normalAndDist = SdfNormalAndDistance(o.worldPos);

						float3 volumePos = o.worldPos + (normal + normalAndDist.xyz * saturate(normalAndDist.w))
							* lerp(0.5, 1 - fresnel, smoothness) * 0.5
							* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

						bakeRaw = SampleVolume(volumePos, outOfBounds);

						gotVolume = bakeRaw.a * (1 - outOfBounds);
						outOfBounds = 1 - gotVolume;

						bakeRaw.rgb = lerp(bakeRaw.rgb, GetAvarageAmbient(normal), outOfBounds);
					#endif

					float4 bake = bakeRaw;

					ApplyTopDownLightAndShadow(o.topdownUv,  normal,  bumpMap,  o.worldPos,  gotVolume, fresnel, bake);

					#if _SUB_SURFACE
						float2 damUv = o.texcoord1.xy;
						float4 mask = tex2D(_MainTex_ATL_UvTwo, damUv);

						float skin = tex2D(_SkinMask, damUv);
						float subSurface = _SubSurface.a * skin * (1-mask.g)  * (1+rawFresnel) * 0.5;
					#endif

						float3 col = lightColor // *(1 + outOfBounds)
					+ bake.rgb * ambient
					;
					
					ColorCorrect(tex.rgb);

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


				float3 reflectionPos;
				float outOfBoundsRefl;
				float3 bakeReflected = SampleReflection(o.worldPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);

				TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);

				float outOfBounds;
				float3 straightHit;
				float3 bakeStraight = SampleRay(o.worldPos, normalize(-viewDir - normal*0.5), shadow, straightHit, outOfBounds );

				TopDownSample(straightHit, bakeStraight, outOfBounds);

				float3 col;

				col = lerp (bakeStraight,bakeReflected , showReflected);

#			endif


					ApplyBottomFog(col, o.worldPos.xyz, viewDir.y);

					return float4(col,1);

				}
				ENDCG
			}

			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

		}
		Fallback "Diffuse"
	}
}
