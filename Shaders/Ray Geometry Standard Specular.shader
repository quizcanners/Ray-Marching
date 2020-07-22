Shader "RayTracing/Geometry/Standard Specular"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}

		_SpecularMap("Specular", 2D) = "gray" {}

		[KeywordEnum(Nonmetal, Metal)] _SURFACE("Surface", Float) = 0

		_TintColor("Reflection Color", Color) = (1,1,1,1)

		[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_Map("Bump/Combined Map (or None)", 2D) = "gray" {}
	
		[Toggle(_AMBIENT)] useAmbient("Use Ambient Map", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}

		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0
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
				#pragma shader_feature_local _SURFACE_NONMETAL _SURFACE_METAL   

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

				sampler2D _Map;
				sampler2D _SpecularMap;
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


				float4 _TintColor;


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

					#if !_BUMP_COMBINED
						bumpMap.b = 0.1;
						bumpMap.a = 1;
					#endif

#if _AMBIENT
						bumpMap.a *= tex2D(_OcclusionMap, uv).r;
#endif

#if _COLOR_R_AMBIENT
						bumpMap.a *= o.color.r;
#endif

					uv -= tnormal.rg  *  _MainTex_TexelSize.xy;

					float4 tex = tex2D(_MainTex, uv);// * o.color;
				
					float3 normal = o.normal.xyz;

					ApplyTangent(normal, tnormal, o.wTangent);

					float fresnel = saturate(dot(normal,viewDir));

					float showReflected = 1 - fresnel;
					//return fresnel;

				

					float smoothness = bumpMap.b;
					//smoothness = lerp(smoothness, 1, showReflected);

					//return smoothness;



					float ambient = bumpMap.a;

					float shadow = SHADOW_ATTENUATION(o) * SampleSkyShadow(o.worldPos);


					float direct = shadow * smoothstep(1 - ambient, 1.5 - ambient * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));
					

					float3 lightColor = _LightColor0.rgb * direct;


					// LIGHTING

					float4 specularMap = tex2D(_SpecularMap, uv);

					float specular = specularMap.a;
					float metal = specularMap.r;

	

					float4 bake;
					float outOfBounds;
					float gotVolume;

#if LIGHTMAP_ON
					float3 lightMap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
					bake.rgb = lightMap;
					bake.a = 0;
					outOfBounds = 0;
					gotVolume = 1;
#else 


					float3 avaragedAmbient = GetAvarageAmbient(normal);

					float3 volumePos = o.worldPos + (normal) 
						* lerp(0.5, showReflected, smoothness) * 0.5
						* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

					outOfBounds;
					bake = SampleVolume(volumePos, outOfBounds);

					gotVolume = bake.a * (1- outOfBounds);
					outOfBounds = 1 - gotVolume;
				
					bake.rgb = lerp(bake.rgb, avaragedAmbient, outOfBounds); // Up 
#endif

				
					ApplyTopDownLightAndShadow(o.topdownUv, normal, bumpMap, o.worldPos, gotVolume, fresnel, bake);



					/*

					float3 col = lightColor + bake.rgb * ambient;
					

					ColorCorrect(tex.rgb);
					col.rgb *=tex.rgb;*/

					float showReflection = smoothstep(0.5, 1, specular);

					float3 bakeReflected;

					if (showReflection > 0.001) 
					{
						float3 reflectionPos;
						float outOfBoundsRefl;
						bakeReflected = SampleReflection(o.worldPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);
					}
					else
						bakeReflected = 0;

					float3 reflection = reflect(-_WorldSpaceLightPos0.xyz, normal);
					float dott = saturate(dot(reflection, viewDir));
					float power = 5/(1.001- specular);
					float specularReflection = pow(dott, power);

					float showGloss = specular * specular;// pow(specular, 2);

					ColorCorrect(tex.rgb);

					float3 reflectionColor = specularReflection * lightColor + bakeReflected * showReflection;

#if _SURFACE_METAL
					reflectionColor *= lerp(1, _TintColor, metal);
#endif

					float3 col = lerp(tex.rgb * (lightColor + bake), reflectionColor * ambient, showGloss);

#if _SURFACE_NONMETAL  

#else 
					//bakeReflected *= 
					//col = lerp(col, _TintColor * (lightColor * specularReflection * specularReflection * 10 + bakeReflected) * ambient, metal);
#endif


				

		//	#endif


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