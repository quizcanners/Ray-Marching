Shader "RayTracing/Geometry/Standard Transparent"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "clear" {}

		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		_BumpMap("Normal Map", 2D) = "bump" {}
		[KeywordEnum(None, MADS, Separate)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}
		[Toggle(_AMBIENT_IN_UV2)] ambInuv2("Ambient mapped to UV2", Float) = 0
		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0


		[Toggle(_WIND_SHAKE)] windShake("Wind Shaking", Float) = 0

		[Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
		_SubSurface("Sub Surface Color", Color) = (1,0.5,0,0)
		_SkinMask("Skin Mask (_UV2)", 2D) = "white" {}
	}

	Category
	{
			Tags
				{
					"Queue" = "Transparent"
					 "RenderType" = "Transparent"
					"LightMode" = "ForwardBase"
				}

		SubShader
		{
			CGINCLUDE

				#define RENDER_DYNAMICS

				#pragma multi_compile ___ _qc_IGNORE_SKY

				#include "Assets/Ray-Marching/Shaders/Savage_Sampler_Debug.cginc"

				float3 ShakeWorldPos(float3 worldPos, float topDownShadow)
				{
			
					float outOfBounds;
					float4 sdfWorld = SampleSDF(worldPos, outOfBounds);
					//float useSdf = smoothstep(0, -0.05 * coef, sdfWorld.w);

					float offGround = smoothstep(0.25,1, worldPos.y);

					float offset = smoothstep(0.25, -0.25, sdfWorld.w);
					worldPos.xyz += offset * sdfWorld.xyz * (1-outOfBounds);

					float distance = smoothstep(0,3,sdfWorld.w);

					float3 gyrPos = worldPos * 0.2f;
					gyrPos.y += _Time.x * 20;
					float gyr = abs(sdGyroid(gyrPos, 1));

					float3 shake = float3(sin(gyrPos.x + _Time.z), gyr, sin(gyrPos.z + _Time.z));// *gyr;
				
					float len = dot(shake, shake);

					shake.y = gyr * 0.1;

					worldPos.xyz += shake * len * 0.1 * lerp(distance, 1, outOfBounds); // *(gyr - 0.5);
					return worldPos;
				}

			ENDCG

			Pass
			{
			

				Blend SrcAlpha OneMinusSrcAlpha
				ColorMask RGBA
				Cull Back
				ZWrite Off

				CGPROGRAM

				#define RENDER_DYNAMICS

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				#pragma shader_feature_local ___ _WIND_SHAKE

				#pragma shader_feature_local ___ _AMBIENT_IN_UV2
				#pragma shader_feature_local _AO_NONE _AO_MADS _AO_SEPARATE
				#pragma shader_feature_local ___ _COLOR_R_AMBIENT

				#pragma shader_feature_local ___ _SUB_SURFACE
				
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

					float tracedShadows : TEXCOORD7;
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
					v.vertex = mul(unity_WorldToObject, float4(ShakeWorldPos(worldPos.xyz, topDownShadow), v.vertex.w));
					worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
#endif

					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.texcoord1 = v.texcoord1;
					o.worldPos = worldPos;
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);

					TRANSFER_WTANGENT(o);
					TRANSFER_SHADOW(o);

					o.tracedShadows = SampleRayShadow(o.worldPos) * SampleSkyShadow(o.worldPos);


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

				

					float4 madsMap = tex2D(_SpecularMap, uv);
					float displacement = madsMap.b;

					float dott = dot(viewDir, i.normal.xyz);

				//	float isBackface = smoothstep( 0, -0.001, dott);

				//	i.normal.xyz = lerp(i.normal.xyz, -i.normal.xyz, isBackface);

					float rawFresnel = smoothstep(1, 0, abs(dott));
					float offsetAmount = (1 + rawFresnel * rawFresnel * 4);

				//	return rawFresnel;

					float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));
					uv -= tnormal.rg * _MainTex_TexelSize.xy;
					float3 normal = i.normal.xyz;

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

					float metal = madsMap.r;
					float fresnel = (1 - saturate(dot(normal, viewDir))) * ao;
					float specular = GetSpecular(madsMap.a, fresnel, metal);

					float shadow = getShadowAttenuation(i.worldPos) * i.tracedShadows;

					float3 lightColor = Savage_GetDirectional_Opaque(shadow, ao, normal, i.worldPos);


					// LIGHTING
					float3 bake;

					float3 volumeSamplePosition;
					bake = Savage_GetVolumeBake(i.worldPos, normal, i.normal, volumeSamplePosition);

					TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
					float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, i.worldPos);
					ao *= topDownAmbient.a;
					bake += topDownAmbient.rgb;


					float4 tex = tex2D(_MainTex, uv) * i.color;
					
					float3 col = tex.rgb * (lightColor + bake * ao);

					float3 reflectedRay;

					reflectedRay = reflect(-viewDir, normal);

					float4 topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, i.worldPos, i.normal.xyz, specular);

					ao *= topDownAmbientSpec.a;

					float3 reflectedBake = GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular, ao);

					float specularReflection = GetDirectionalSpecular(normal, viewDir, specular * 0.95);// pow(dott, power) * brightness;

					float3 reflectionColor = specularReflection * lightColor
						+ topDownAmbientSpec.rgb* ao + reflectedBake
						;

					MixInSpecular(col, reflectionColor, tex, metal, specular, fresnel);

#				if _SUB_SURFACE
					float4 skin = tex2D(_SkinMask, i.texcoord.xy);

					float subSurface = _SubSurface.a * skin.a;// *(2 - rawFresnel) * 0.5;

					float3 refractedRay = refract(-viewDir, normal, 0.9);

					float3 forwardBake = GetBakedAndTracedReflection(volumeSamplePosition, refractedRay, specular, ao);

					float sun = 10/(0.1 + 1000 * smoothstep(1,0,dot(_WorldSpaceLightPos0.xyz, refractedRay)));


					float3 subSurfaceColor = skin.rgb * _SubSurface.rgb * (forwardBake.rgb
						+ GetDirectional() * sun * shadow);

				//	return float4(forwardBake.rgb, 1);

					col = lerp(col, subSurfaceColor, subSurface);
#				endif

					ApplyBottomFog(col.rgb, i.worldPos.xyz, i.viewDir.y);

					return float4(col, tex.a);

				}
				ENDCG
			}

		}
		Fallback "Diffuse"
	}
}