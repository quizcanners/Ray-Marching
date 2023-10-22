Shader "RayTracing/Geometry/Transparent Emissive Decal"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}

		_SpecularMap("R-Metalic G-Smoothness _ A-Opacity", 2D) = "black" {}
		_Reflectivity("Added Reflectiveness (Mat)", Range(0,1)) = 0.33


		_BumpMap("Normal Map", 2D) = "bump" {}

		[Toggle(_EMISSIVE)] emissiveTexture("Emissive Texture", Float) = 0
		_Emissive("Emissive", 2D) = "clear" {}

		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0
	}

	Category
	{

			


		SubShader
		{
			Tags
					{
					"Queue" = "Transparent"
					"RenderType" = "Opaque"
					"LightMode" = "ForwardBase"
				}
			CGINCLUDE

			
				#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
				#define RENDER_DYNAMICS

				#pragma multi_compile ___ _qc_USE_RAIN
				#pragma multi_compile ___ _qc_IGNORE_SKY
				#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 

				#include "Assets/Ray-Marching/Shaders/Savage_Sampler_Debug.cginc"

			
			ENDCG

			Pass
			{
				

				Blend SrcAlpha OneMinusSrcAlpha
				ColorMask RGBA
				Cull Off//Back

				CGPROGRAM

				#define RENDER_DYNAMICS

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING
				#pragma shader_feature_local ___ _EMISSIVE

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
					float4 traced : TEXCOORD7;
					fixed4 color : COLOR;
				};

				sampler2D _MainTex_ATL_UvTwo;
				float4 _MainTex_ATL_UvTwo_TexelSize;

				sampler2D _MainTex;
				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;

				sampler2D _BumpMap;
				float4 _BumpMap_ST;
				
				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

#if _WIND_SHAKE
					float topDownShadow = TopDownSample_Shadow(worldPos.xyz);
					v.vertex = mul(unity_WorldToObject, float4(WindShakeWorldPos(worldPos.xyz, topDownShadow), v.vertex.w));
					worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
#endif

					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.texcoord1 = v.texcoord1;
					o.worldPos = worldPos;
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);

					o.traced = GetTraced_Mirror_Vert(o.worldPos, normalize(o.viewDir.xyz), o.normal.xyz);

					TRANSFER_WTANGENT(o);
					TRANSFER_SHADOW(o);

					return o;
				}

				sampler2D _SpecularMap;
				float _Reflectivity;
					#if _EMISSIVE
				sampler2D _Emissive;
	#endif

				float4 frag(v2f i) : COLOR
				{
					float3 viewDir = normalize(i.viewDir.xyz);
					float2 uv = i.texcoord.xy;
					float4 tex = tex2D(_MainTex, uv);

					float4 mstMap = tex2D(_SpecularMap, uv);

					float dott = dot(viewDir, i.normal.xyz);

					float rawFresnel = smoothstep(1, 0, abs(dott));
					float offsetAmount = (1 + rawFresnel * rawFresnel * 4);

					float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));
					uv -= tnormal.rg * _MainTex_TexelSize.xy;
					float3 normal = i.normal.xyz;

					ApplyTangent(normal, tnormal, i.wTangent);

					float shadow = getShadowAttenuation(i.worldPos);

					float ao = 1;
					// ********************** WATER

					float water = 0;

					float3 worldPosAdjusted = i.worldPos;
					ao *= SampleContactAO_OffsetWorld(worldPosAdjusted, normal);

					float metal = mstMap.r;
					float smoothness = mstMap.g;
					float fresnel = GetFresnel_FixNormal(normal, i.normal.xyz, viewDir) * ao;//GetFresnel(normal, viewDir) * ao;

					float specular = GetSpecular(smoothness, fresnel * _Reflectivity , metal);
					
					//tex.a = mstMap.b;

					//tex.a *= smoothstep(0.5,0.6, tex.a);

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

					precomp.microdetail = 0; // _MudColor;
					precomp.metalColor = tex;//lerp(tex, tex, _MetalColor.a);

					precomp.microdetail.a = 0;
			
					float3 col = GetReflection_ByMaterialType(precomp, normal, i.normal.xyz, viewDir, worldPosAdjusted);

				

					#if _EMISSIVE
						col.rgb += tex2D(_Emissive, uv).rgb;
					#endif

					ApplyBottomFog(col.rgb, i.worldPos.xyz, viewDir.y);

					return float4(col, tex.a);

				}
				ENDCG
			}

		}
		Fallback "Diffuse"
	}
}