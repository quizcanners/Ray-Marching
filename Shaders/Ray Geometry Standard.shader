Shader "RayTracing/Geometry/Standard"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}

		[KeywordEnum(Nonmetal, Metal, Glass)] _SURFACE("Surface", Float) = 0

		[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_Map("Bump/Combined Map (or None)", 2D) = "gray" {}
	
		[Toggle(_AMBIENT)] useAmbient("Use Ambient Map", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}

		
		[Toggle(_DISABLE_VOLUME)] noRtxVolume("Ignore Raytraced Volume", Float) = 0

		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0


		[Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
		_SubSurface("Sub Surface Scattering", Color) = (1,0.5,0,0)
		_SkinMask("Skin Mask (_UV2)", 2D) = "white" {}


		[Toggle(_SHOWUVTWO)] thisDoesntMatter("Debug Uv 2", Float) = 0
	}

	Category
	{
		SubShader
		{
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

				#define RENDER_DYNAMICS

				#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
				#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
				#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
				#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"



				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
				#pragma shader_feature_local _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 
				#pragma shader_feature_local _SURFACE_NONMETAL _SURFACE_METAL _SURFACE_GLASS  
				#pragma shader_feature_local ___ _DISABLE_VOLUME

				#pragma shader_feature_local ___ _SUB_SURFACE
				#pragma shader_feature_local ___ _AMBIENT
				#pragma shader_feature_local ___ _SHOWUVTWO

				#pragma shader_feature_local ___ _COLOR_R_AMBIENT


				#pragma multi_compile ___ _qc_Rtx_MOBILE
			

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

				sampler2D _MainTex_ATL_UvTwo;
				float4 _MainTex_ATL_UvTwo_TexelSize;

				sampler2D _MainTex;
				#if _AMBIENT
				sampler2D _OcclusionMap;
				#endif
				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				sampler2D _Bump;
				sampler2D _SkinMask;
				float4 _SubSurface;

				sampler2D _Map;
				float4 _Map_ST;
				
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
					o.lightMapUv = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;


					TRANSFER_WTANGENT(o)
					TRANSFER_TOP_DOWN(o);
					TRANSFER_SHADOW(o);

					return o;
				}


				float4 frag(v2f o) : COLOR
				{

					#if _qc_Rtx_MOBILE
						float oob;
						float4 vlm =  SampleVolume(o.worldPos, oob);
						return tex2D(_MainTex, o.texcoord.xy) * lerp(vlm,1,oob) * o.color;
					#endif


					float3 viewDir = normalize(o.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, o.normal.xyz));

					
					float2 uv = o.texcoord.xy;

					float4 bumpMap;
					float3 tnormal;
					SampleBumpMap(_Map, bumpMap, tnormal, uv);

					uv -= tnormal.rg  *  _MainTex_TexelSize.xy;

					float4 tex = tex2D(_MainTex, uv);// * o.color;
				
					float3 normal = o.normal.xyz;

					ApplyTangent(normal, tnormal, o.wTangent);

					float fresnel = saturate(dot(normal,viewDir));

					float showReflected = 1 - fresnel;
					//return fresnel;

					float smoothness = 
					#if _BUMP_COMBINED
					bumpMap.b;
					#else 
					0.1;
					#endif

					//smoothness = lerp(smoothness, 1, showReflected);

					//return smoothness;

					float ambient = 
#if _COLOR_R_AMBIENT
						o.color.r * 
#endif
						// For Mesh-Baked Ambient
					#if _BUMP_COMBINED
					 bumpMap.a;
					#else 

					#if _AMBIENT
						tex2D(_OcclusionMap, uv).r;// * o.color;
					#else 
						1;
					#endif
					#endif

					float shadow = SHADOW_ATTENUATION(o) * SampleSkyShadow(o.worldPos);


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


					float3 avaragedAmbient = GetAvarageAmbient(normal);

					#if !_DISABLE_VOLUME

					//	float4 normalAndDist = SdfNormalAndDistance(o.worldPos);
					
						float3 volumePos = o.worldPos + (normal //+ normalAndDist.xyz * saturate(normalAndDist.w)
							) 
							* lerp(0.5, showReflected, smoothness) * 0.5
							* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

						outOfBounds;
						bakeRaw = SampleVolume(volumePos, outOfBounds);

						gotVolume = bakeRaw.a * (1- outOfBounds);
						outOfBounds = 1 - gotVolume;
				
						bakeRaw.rgb = lerp(bakeRaw.rgb, avaragedAmbient, outOfBounds); // Up 

					#else 
						bakeRaw = float4(GetAvarageAmbient(normal),0);
						outOfBounds = 1;
						gotVolume = 0;
					#endif

#endif

					

						float4 bake = bakeRaw;

						ApplyTopDownLightAndShadow(o.topdownUv, normal, bumpMap, o.worldPos, gotVolume, fresnel, bake);


#					if _SUB_SURFACE

					float2 damUv = o.texcoord1.xy;
					float4 mask = tex2D(_MainTex_ATL_UvTwo, damUv);

					float skin = tex2D(_SkinMask, damUv);
					float subSurface = _SubSurface.a * skin * (1-mask.g)  * (1+rawFresnel) * 0.5;
#					endif

					float3 col = lightColor 
					+ bake.rgb * ambient;
					

					ColorCorrect(tex.rgb);
					col.rgb *=tex.rgb;

					//AddGlossToCol(lightColor);

			
#					if _SUB_SURFACE
						col *= 1-subSurface;

						#if !_DISABLE_VOLUME
							TopDownSample(o.worldPos, bakeRaw.rgb, outOfBounds);
						#endif

						col.rgb += subSurface * _SubSurface.rgb * (_LightColor0.rgb * shadow + bakeRaw.rgb);
#					endif

#			elif _SURFACE_METAL

			
				float3 reflectionPos;
				float outOfBoundsRefl;
				float3 bakeReflected = SampleReflection(o.worldPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);

				#if !_DISABLE_VOLUME
					TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);
				#endif

				float3 col = tex.rgb * (lightColor + bakeReflected);

#			elif _SURFACE_GLASS


				float3 reflectionPos;
				float outOfBoundsRefl;
				float3 bakeReflected = SampleReflection(o.worldPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);

				#if !_DISABLE_VOLUME
					TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);
				#endif

				float outOfBounds;
				float3 straightHit;
				float3 bakeStraight = SampleRay(o.worldPos, normalize(-viewDir - normal*0.5), shadow, straightHit, outOfBounds );

				#if !_DISABLE_VOLUME
					TopDownSample(straightHit, bakeStraight, outOfBounds);
				#endif

			//	return fresnel;

			

				float3 col;

				

				col = lerp (bakeStraight, bakeReflected , showReflected);


				ColorCorrect(col);

			//	col.r = lerp(bakeStraight.r, bakeReflected.r, pow(showReflected,3));
			//	col.g = lerp(bakeStraight.g, bakeReflected.g, showReflected * showReflected);
			//	col.b = lerp(bakeStraight.b, bakeReflected.b, pow(showReflected,0.5));
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