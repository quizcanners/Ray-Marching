Shader "RayTracing/Geometry/With Transparent Overlay"
{
	Properties
	{
		_Diffuse("Albedo (RGB)", 2D) = "white" {}

		[KeywordEnum(Nonmetal, Metal, Glass)] _SURFACE("Surface", Float) = 0

		[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_Map("Bump/Combined Map (or None)", 2D) = "gray" {}
	

		_Overlay("Overlay Mask (RGB)", 2D) = "white" {}
		_OverlayTexture("Overlay Texture (RGB)", 2D) = "white" {}

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

				#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
				#pragma multi_compile ___ _qc_Rtx_MOBILE

				sampler2D _MainTex_ATL_UvTwo;
				float4 _MainTex_ATL_UvTwo_TexelSize;

				sampler2D _Diffuse;
				sampler2D _Bump;
				sampler2D _SkinMask;
				float4 _Diffuse_ST;
				float4 _Diffuse_TexelSize;
				float4 _SubSurface;

				float4 _Overlay_ST;
				sampler2D _Overlay;

				float4 _OverlayTexture_ST;
				sampler2D _OverlayTexture;

				sampler2D _Map;
				float4 _Map_ST;

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
				#pragma shader_feature_local _SURFACE_NONMETAL _SURFACE_METAL _SURFACE_GLASS  

				#pragma shader_feature_local ___ _SUB_SURFACE
				#pragma shader_feature_local ___ _SHOWUVTWO

				struct v2f {
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float2 texcoord1	: TEXCOORD1;
					float3 worldPos		: TEXCOORD2;
					float3 normal		: TEXCOORD3;
					float4 wTangent		: TEXCOORD4;
					float3 viewDir		: TEXCOORD5;
					SHADOW_COORDS(6)

					float2 topdownUv : TEXCOORD7;
					float2 lightMapUv : TEXCOORD8;
					fixed4 color : COLOR;
				};

				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = TRANSFORM_TEX(v.texcoord, _Diffuse);
					o.texcoord1 = v.texcoord1;
					o.worldPos = worldPos;
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);
					
					 o.lightMapUv = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;

					TRANSFER_WTANGENT(o)
					TRANSFER_TOP_DOWN(o);
					TRANSFER_SHADOW(o);

					return o;
				}


				float4 frag(v2f o) : COLOR
				{
					float2 uv = o.texcoord.xy;

					#if _qc_Rtx_MOBILE

							float4 mobTex = tex2D(_Diffuse, uv);

						#if LIGHTMAP_ON
							mobTex.rgb *= DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
						#else 

							float oobMob;
							mobTex.rgb *= SampleVolume(o.worldPos, oobMob).rgb;

						#endif

						return mobTex;

					#endif

					float3 viewDir = normalize(o.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, o.normal.xyz));

				

					float4 bumpMap;
					float3 tnormal;
					SampleBumpMap(_Map, bumpMap, tnormal, uv);

					float4 tex = tex2D(_Diffuse, uv - tnormal.rg  *  _Diffuse_TexelSize.xy);// * o.color;
				
					float3 normal = o.normal.xyz;

					ApplyTangent(normal, tnormal, o.wTangent);

					float fresnel = saturate(dot(normal,viewDir));

					float smoothness = 
					#if _BUMP_COMBINED
					bumpMap.b;
					#else 
					0.1;
					#endif

					float ambient = 
					#if _BUMP_COMBINED
					 bumpMap.a;
					#else 
					1;
					#endif

					float overlayMask = tex2Dlod(_Overlay, float4(o.texcoord,0,0)).r;
					
					float overlayShadow = (4 - overlayMask) * 0.25;

					float shadow = SHADOW_ATTENUATION(o) * overlayShadow;

					ambient *= overlayShadow;

					float direct = shadow * smoothstep(1 - ambient, 1.5 - ambient * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));
					
					float3 lightColor =GetDirectional() * direct;

					// LIGHTING

					#if _SURFACE_NONMETAL  

					float4 normalAndDist = SdfNormalAndDistance(o.worldPos);
					
					float3 volumePos = o.worldPos + (normal + normalAndDist.xyz * saturate(normalAndDist.w)) 
						* lerp(0.5, 1 - fresnel, smoothness) * 0.5
						* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

					float outOfBounds;
					float4 bakeRaw = SampleVolume(volumePos, outOfBounds);

					float gotVolume = bakeRaw.a * (1- outOfBounds);
					outOfBounds = 1 - gotVolume;

					#if LIGHTMAP_ON
						float3 lightMap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
						bakeRaw.rgb = lightMap; 
					#else 
						bakeRaw.rgb = lerp(bakeRaw.rgb, GetAvarageAmbient(normal), outOfBounds);
					#endif

					float4 bake = bakeRaw;

					ApplyTopDownLightAndShadow(o.topdownUv,  normal,  bumpMap,  o.worldPos,  gotVolume, fresnel, bake);

#					if _SUB_SURFACE

					float2 damUv = o.texcoord1.xy;
					float4 mask = tex2D(_MainTex_ATL_UvTwo, damUv);

					float skin = tex2D(_SkinMask, damUv);
					float subSurface = _SubSurface.a * skin * (1-mask.g)  * (1+rawFresnel) * 0.5;
#					endif

					float3 col = lightColor * (1 + outOfBounds) 
					+ bake.rgb * ambient;
					
					col.rgb *=tex.rgb;

					AddGlossToCol(lightColor);

#					if _SUB_SURFACE
					col *= 1-subSurface;
					TopDownSample(o.worldPos, bakeRaw.rgb, outOfBounds);
					col.rgb += subSurface * _SubSurface.rgb * (_LightColor0.rgb * shadow + bakeRaw.rgb);
#					endif

#			elif _SURFACE_METAL

			
				float3 reflectionPos;
				float outOfBoundsRefl;
				float3 bakeReflected = SampleReflection(o.worldPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);

				TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);

				float3 col =  tex.rgb * bakeReflected;

#			elif _SURFACE_GLASS


				float3 reflectionPos;
				float outOfBoundsRefl;
				float3 bakeReflected = SampleReflection(o.worldPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);

				TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);

				float outOfBounds;
				float3 straightHit;
				float3 bakeStraight = SampleRay(o.worldPos, normalize(-viewDir - normal*0.5), shadow, straightHit, outOfBounds );

				TopDownSample(straightHit, bakeStraight, outOfBounds);

			//	return fresnel;

				float showReflected = 1 - fresnel;

				float3 col;

				col = lerp (bakeStraight,
				bakeReflected , showReflected);

			//	col.r = lerp(bakeStraight.r, bakeReflected.r, pow(showReflected,3));
			//	col.g = lerp(bakeStraight.g, bakeReflected.g, showReflected * showReflected);
			//	col.b = lerp(bakeStraight.b, bakeReflected.b, pow(showReflected,0.5));
#			endif


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
				Cull Off //Back
				ZWrite Off

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma shader_feature_local _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 
				
			
				#pragma shader_feature_local ___ _SHOWUVTWO

				//  sampler2D _CameraDepthTexture;

				struct v2f {
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float2 texcoord1	: TEXCOORD1;
					float2 texcoord2	: TEXCOORD2;
					float3 worldPos		: TEXCOORD3;
					float3 normal		: TEXCOORD4;
					float4 wTangent		: TEXCOORD5;
					float3 viewDir		: TEXCOORD6;
					SHADOW_COORDS(7)

					float2 topdownUv : TEXCOORD8;
					float4 screenPos : TEXCOORD9;
					float2 lightMapUv : TEXCOORD10;
					fixed4 color : COLOR;
				};

				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.texcoord = TRANSFORM_TEX(v.texcoord, _Diffuse);
					o.texcoord1 = TRANSFORM_TEX(v.texcoord, _OverlayTexture);
					o.texcoord2 = TRANSFORM_TEX(v.texcoord, _Overlay);
					float4 tex = tex2Dlod(_Overlay, float4(o.texcoord,0,0));

					 float toCamera = length(_WorldSpaceCameraPos - worldPos.xyz) - _ProjectionParams.y;

					worldPos.xyz += o.normal.xyz * smoothstep(0,1, 0.05 * ( tex.a * 3) * toCamera) * 0.15; 

					v.vertex = mul(unity_WorldToObject, float4(worldPos.xyz, v.vertex.w));
					o.pos = UnityObjectToClipPos(v.vertex); // don't forget
					
					o.worldPos = worldPos;
					
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);

					 o.screenPos = ComputeScreenPos(o.pos);
					  o.lightMapUv = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
					COMPUTE_EYEDEPTH(o.screenPos.z);

					TRANSFER_WTANGENT(o)
					TRANSFER_TOP_DOWN(o);
					TRANSFER_SHADOW(o);

					return o;
				}


				float4 frag(v2f o) : COLOR
				{
					float2 uv = o.texcoord.xy;

					#if _qc_Rtx_MOBILE

							float4 mobTex = tex2D(_OverlayTexture, o.texcoord1);

						#if LIGHTMAP_ON
							mobTex.rgb *= DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
						//	return 0;
						#else 

							float oobMob;
							mobTex.rgb *= SampleVolume(o.worldPos, oobMob).rgb;

						#endif

						return mobTex;

					#endif

					float2 screenUV = o.screenPos.xy / o.screenPos.w;
					float3 viewDir = normalize(o.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, o.normal.xyz));

					

					float4 mask = tex2D(_Overlay, o.texcoord2).r;
					float4 tex = tex2D(_OverlayTexture, o.texcoord1); 
					tex.a = mask * tex.a; //smoothstep(0, 0.5, tex.a) ;

					float3 normal = o.normal.xyz;
					float fresnel = saturate(dot(normal,viewDir));
					float smoothness = 0.5 * tex.a;
					float ambient = 1;

					float shadow = SHADOW_ATTENUATION(o) * SampleSkyShadow(o.worldPos);

					float direct = shadow * smoothstep(0.5, 1 , dot(normal, _WorldSpaceLightPos0.xyz));
					
					float3 lightColor = GetDirectional() * direct;

					// LIGHTING
					
					float4 normalAndDist = SdfNormalAndDistance(o.worldPos);
					
					float3 volumePos = o.worldPos + (normal + normalAndDist.xyz * saturate(normalAndDist.w)) 
						* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;


					//float3 avaragedAmbient = GetAvarageAmbient(normal);
				//	bakeRaw.rgb = lerp(bakeRaw.rgb, avaragedAmbient, outOfBounds); // Up 

					float4 bakeRaw = 0;

					#if LIGHTMAP_ON

						float outOfBounds = 0;
						float3 lightMap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
						bakeRaw.rgb = lightMap; 
						//return bakeRaw;
					#else 

						float outOfBounds;
						bakeRaw = SampleVolume(volumePos, outOfBounds);

						float gotVolume = bakeRaw.a * (1- outOfBounds);
						outOfBounds = 1 - gotVolume;
						bakeRaw.rgb = lerp(bakeRaw.rgb, GetAvarageAmbient(normal), outOfBounds);
					#endif

						float4 bake = bakeRaw;

					ApplyTopDownLightAndShadow(o.topdownUv,  normal,  float4(0.5,0.5,0.5,0.5),  o.worldPos,  1-outOfBounds, fresnel, bake);

					float3 col = lightColor * (1 + outOfBounds) + bake.rgb * ambient;
					
					col.rgb *=tex.rgb;

					AddGlossToCol(lightColor);

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