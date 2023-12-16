Shader "GPUInstancer/RayTracing/Geometry/Standard Cutout"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}

		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		_BumpMap("Normal Map", 2D) = "bump" {}
		[KeywordEnum(None, MADS, Separate)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}
		[Toggle(_AMBIENT_IN_UV2)] ambInuv2("Ambient mapped to UV2", Float) = 0
		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0
		[Toggle(_SDF_AMBIENT)] sdfAmbient("SDF Ambient", Float) = 0

		[Toggle(_WIND_SHAKE)] windShake("Wind Shaking", Float) = 0

		[Toggle(_BACKFACE_FLIP)] fixBackface("Backface Flip", Float) = 0

		[Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
		[HDR] _SubSurface("Sub Surface Color", Color) = (1,0.5,0,0)
		_SkinMask("Skin Mask (_UV2)", 2D) = "white" {}

		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0
		[Toggle(_DYNAMIC_OBJECT)] dynamic("Dynamic Object", Float) = 0

	}

	Category
	{
		SubShader
		{
			CGINCLUDE

			
				#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
				#define RENDER_DYNAMICS

				#pragma multi_compile ___ _qc_USE_RAIN
				#pragma multi_compile ___ _qc_IGNORE_SKY
				#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 

				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Debug.cginc"

			
			ENDCG

			Pass
			{
				Tags
				{
					"Queue" = "AlphaTest"
					"RenderType" = "Opaque"
					"LightMode" = "ForwardBase"
				}

				ColorMask RGBA
				Cull Off//Back

				CGPROGRAM
#include "UnityCG.cginc"
#include "./../../GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
#pragma instancing_options procedural:setupGPUI
#pragma multi_compile_instancing

				#define RENDER_DYNAMICS

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				#pragma shader_feature_local ___ _WIND_SHAKE
				#pragma shader_feature_local ___ _BACKFACE_FLIP
				#pragma shader_feature_local ___ _AMBIENT_IN_UV2
				#pragma shader_feature_local _AO_NONE _AO_MADS _AO_SEPARATE
				#pragma shader_feature_local ___ _COLOR_R_AMBIENT
				#pragma shader_feature_local ___ _DYNAMIC_OBJECT
				#pragma shader_feature_local ___ _SUB_SURFACE
				#pragma shader_feature_local ___ _SDF_AMBIENT
		
				
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

				sampler2D _SkinMask;
				float4 _SubSurface;

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

#if _AO_SEPARATE
				sampler2D _OcclusionMap;
#endif

				sampler2D _SpecularMap;

				float4 frag(v2f i) : COLOR
				{
					float3 viewDir = normalize(i.viewDir.xyz);
					float2 uv = i.texcoord.xy;

					float4 tex = tex2D(_MainTex, uv);
					clip(tex.a-0.1);

					float4 madsMap = tex2D(_SpecularMap, uv);
					float displacement = madsMap.b;

					float dott = dot(viewDir, i.normal.xyz);

					#if _BACKFACE_FLIP
					float isBackface = smoothstep( 0, -0.001, dott);

					i.normal.xyz = lerp(i.normal.xyz, -i.normal.xyz, isBackface);

					//	return float4(i.normal.xyz,1);
					#endif
				

					float rawFresnel = smoothstep(1, 0, abs(dott));
					float offsetAmount = (1 + rawFresnel * rawFresnel * 4);

					float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));
					uv -= tnormal.rg * _MainTex_TexelSize.xy;
					float3 normal = i.normal.xyz;

					//return dott;

					float ao;

#if _AO_SEPARATE
#	if _AMBIENT_IN_UV2
					ao = tex2D(_OcclusionMap, i.texcoord1.xy).r;
#	else
					ao = tex2D(_OcclusionMap, uv).r;
#	endif
#elif _AO_MADS
					ao = madsMap.g;
#else 
					ao = 1;
#endif

#if _COLOR_R_AMBIENT
					ao *= (0.25 + i.color.r * 0.75);
#endif

				
					ApplyTangent(normal, tnormal, i.wTangent);

					float shadow = SHADOW_ATTENUATION(i);//getShadowAttenuation(i.worldPos);

					// ********************** Contact Shadow

#if _DYNAMIC_OBJECT


	ao *=SampleContactAO(i.worldPos, normal);
//	return ao;
#endif
					// ********************** WATER

					float water = 0;

#if _qc_USE_RAIN


					float rain = GetRain(i.worldPos, normal, i.normal, shadow);

					float flattenWater = ApplyWater(water, rain, ao, displacement, madsMap, tnormal, i.worldPos, i.normal.y);

					normal = i.normal.xyz;
					ApplyTangent(normal, tnormal, i.wTangent);

#endif

#if _SDF_AMBIENT

	ao *=SampleContactAO(i.worldPos, normal);
#endif

					float metal = madsMap.r;
					float fresnel = GetFresnel_FixNormal(normal,  i.normal, viewDir) * ao;
					float specular = GetSpecular(madsMap.a, fresnel, metal); 

				

					float3 lightColor = Savage_GetDirectional_Opaque(shadow, ao, normal,  i.worldPos);

					// LIGHTING
					float3 bake;
					float3 volumeSamplePosition;
					bake = Savage_GetVolumeBake(i.worldPos, normal, i.normal, volumeSamplePosition);

					TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
					float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, i.worldPos);
					ao *= topDownAmbient.a;
					bake += topDownAmbient.rgb;

					ModifyColorByWetness(tex.rgb, water, madsMap.a);

					float3 reflectionColor = 0;
					float3 pointLight = GetPointLight(volumeSamplePosition, normal, ao, viewDir, specular, reflectionColor);

					float3 col = tex.rgb * (pointLight + lightColor + bake * ao);

					// *********************** Reflections

					float3 reflectedRay = reflect(-viewDir, normal.xyz);

					float4 topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, i.worldPos, i.normal.xyz, specular);

					ao *= topDownAmbientSpec.a;

					float3 reflectedBake = GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular, i.traced);

					float specularReflection = GetDirectionalSpecular(normal, viewDir, specular);// pow(dott, power) * brightness;

					reflectionColor += specularReflection * lightColor
						+ (topDownAmbientSpec.rgb + reflectedBake) * ao;

					

					MixInSpecular(col, reflectionColor, tex, metal, specular, fresnel);

#					if _SUB_SURFACE

					float4 skin = tex2D(_SkinMask, i.texcoord.xy) * _SubSurface;

					ApplySubSurface(col, skin, volumeSamplePosition, viewDir, specular, rawFresnel, shadow);

#					endif

					ApplyBottomFog(col.rgb, i.worldPos.xyz, viewDir.y);

					return float4(col, 1);

				}
				ENDCG
			}

			Pass 
			{
				Name "Caster"
				Tags 
				{ 
					"LightMode" = "ShadowCaster" 
				}

				Cull Off//Back
				CGPROGRAM
#include "UnityCG.cginc"
#include "./../../GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
#pragma instancing_options procedural:setupGPUI
#pragma multi_compile_instancing
				#pragma vertex vert
				#pragma fragment frag
				#pragma target 2.0
				#pragma multi_compile_shadowcaster
				#pragma shader_feature_local ___ _WIND_SHAKE
				#include "UnityCG.cginc"

				struct v2f 
				{
					V2F_SHADOW_CASTER;
					float2  uv : TEXCOORD1;
					UNITY_VERTEX_OUTPUT_STEREO
				};


				uniform sampler2D _MainTex;
				float4 _MainTex_ST;

				v2f vert( appdata_base v )
				{
					v2f o;

					UNITY_SETUP_INSTANCE_ID(v);

					#if _WIND_SHAKE
						float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
						float topDownShadow = TopDownSample_Shadow(worldPos.xyz);
						v.vertex = mul(unity_WorldToObject, float4(WindShakeWorldPos(worldPos.xyz, topDownShadow), v.vertex.w));
						//worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
					#endif

					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
					TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)

					o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
					return o;
				}

				uniform fixed _Cutoff;
				uniform fixed4 _Color;

				float4 frag( v2f i ) : SV_Target
				{
					float4 texcol = tex2D( _MainTex, i.uv );

					float fwid = length(fwidth(i.uv));

					clip(texcol.a - 0.1);

					//clip(texcol.a - 0.5 + smoothstep(0, 1, fwid * 100) * 0.45);

					SHADOW_CASTER_FRAGMENT(i)
				}
				ENDCG
			}
		}
		Fallback "Diffuse"
	}
}
