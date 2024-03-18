Shader "QcRendering/Geometry/Cloth"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		_BumpMap("Normal Map", 2D) = "bump" {}

		[KeywordEnum(MADS, None, Separate)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}


		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0

		[Toggle(_PARALLAX)] parallax("Parallax", Float) = 0
		_ParallaxForce("Parallax Amount", Range(0.001,0.3)) = 0.01

		[Toggle(_OFFSET_BY_HEIGHT)] heightOffset("Offset By Height", Float) = 0
		_HeightOffset("Height Offset", Range(0.01,0.3)) = 0.2


		[Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
		_SubSurface("Sub Surface Scattering", Color) = (1,0.5,0,0)
		_SkinMask("Skin Mask (_UV2)", 2D) = "white" {}
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
				Cull Off
			
				CGPROGRAM

				#pragma shader_feature_local ___ _OFFSET_BY_HEIGHT
				#pragma shader_feature_local _AO_MADS  _AO_NONE   _AO_SEPARATE
				#pragma shader_feature_local ___ _SUB_SURFACE
				#pragma shader_feature_local ___ _COLOR_R_AMBIENT
				#pragma shader_feature_local ___ _PARALLAX

				
				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"

				#pragma vertex vert
				#pragma fragment frag		
				#pragma multi_compile_instancing

			#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				

			

				struct v2f {
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float2 texcoord1	: TEXCOORD1;
					float3 worldPos		: TEXCOORD2;
					float3 normal		: TEXCOORD3;
					float4 wTangent		: TEXCOORD4;
					float3 viewDir		: TEXCOORD5;
					SHADOW_COORDS(6)
#if _PARALLAX 
					float3 tangentViewDir : TEXCOORD8; // 5 or whichever is free
#endif
					fixed4 color : COLOR;
				};

	float4 _MainTex_ST;
	float4 _MainTex_TexelSize;
	sampler2D _MainTex;

				sampler2D _SkinMask;
				float4 _SubSurface;
			
				
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

#if _PARALLAX || _DAMAGED
					TRANSFER_TANGENT_VIEW_DIR(o);
#endif

					TRANSFER_WTANGENT(o);
					TRANSFER_SHADOW(o);

					return o;
				}


			
#if _AO_SEPARATE
				sampler2D _OcclusionMap;
#endif


				sampler2D _BumpMap;
				sampler2D _SpecularMap;
				float _HeightOffset;
				float _ParallaxForce;

#if _OFFSET_BY_HEIGHT
				FragColDepth frag(v2f o)
#else 
				float4 frag(v2f o) : COLOR
#endif
				{

					float2 uv = o.texcoord.xy;

					float4 tex = tex2D(_MainTex, uv);

					clip(tex.a - 0.1);


					float3 viewDir = normalize(o.viewDir.xyz);
					float rawFresnel = smoothstep(1, 0, dot(viewDir, o.normal.xyz));
					float offsetAmount = (1 + rawFresnel * rawFresnel * 4);
					
					
					float4 madsMap = tex2D(_SpecularMap, uv);
					float displacement = madsMap.b;

#if _PARALLAX || _DAMAGED
					o.tangentViewDir = normalize(o.tangentViewDir);
					o.tangentViewDir.xy /= o.tangentViewDir.z; // abs(o.tangentViewDir.z + 0.42);
					float deOff = _ParallaxForce / offsetAmount;

					CheckParallax(uv, madsMap, _SpecularMap, o.tangentViewDir, deOff, displacement);
#endif

					float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));

					uv -= tnormal.rg * _MainTex_TexelSize.xy;

					tex = tex2D(_MainTex, uv);


					float3 normal = o.normal.xyz;

					float ao;

#if _AO_SEPARATE
#	if _AMBIENT_IN_UV2
					ao = tex2D(_OcclusionMap, o.texcoord1.xy).r;
#	else
					ao = tex2D(_OcclusionMap, uv).r;
#	endif
#elif _AO_MADS
					ao = madsMap.g;
#else 
					ao = 1;
#endif


#if _COLOR_R_AMBIENT
					ao *= (0.25 + o.color.r * 0.75);
#endif

					ApplyTangent(normal, tnormal, o.wTangent);

					float metal = madsMap.r;
					float fresnel = 1 - saturate(dot(normal, viewDir)); 
					//float specular = lerp(SpecualFromFresnel(madsMap.a, fresnel), madsMap.a, metal);
					float specular = GetSpecular(madsMap.a, fresnel, metal);//lerp(SpecualFromFresnel(madsMap.a, fresnel), 1-pow(1-madsMap.a,2), metal);


					float toCamera = smoothstep(QC_NATIVE_SHADOW_DISTANCE - 5, QC_NATIVE_SHADOW_DISTANCE, length(_WorldSpaceCameraPos - o.worldPos));

					float shadow = lerp(SHADOW_ATTENUATION(o), SampleRayShadow(o.worldPos + o.normal.xyz * 0.01), toCamera);// *SampleSkyShadow(o.worldPos);
					float direct = shadow * smoothstep(1 - ao, 1.5 - ao * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));
					float3 lightColor = GetDirectional() * direct;

					// LIGHTING
					float3 bake;

					float3 volumeSamplePosition = o.worldPos + o.normal.xyz * _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 0.5;

					bake = SampleVolume_CubeMap(volumeSamplePosition, normal);


					TOP_DOWN_SETUP_UV(topdownUv, o.worldPos);
					float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, o.worldPos);
					ao *= topDownAmbient.a;
					bake.rgb += topDownAmbient.rgb;

					float3 col = tex.rgb * (lightColor + bake * ao);

					float3 reflectedRay = reflect(-viewDir, normal);

					float4 topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, o.worldPos, o.normal.xyz, specular);

					float3 reflectedBake = GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular);

					float specularReflection = GetDirectionalSpecular(normal, viewDir, specular);// pow(dott, power) * brightness;

					float3 reflectionColor =
						specularReflection * lightColor
						+ topDownAmbientSpec.rgb * ao + reflectedBake
						
						;

					MixInSpecular(col, reflectionColor, tex, metal, specular, fresnel);

					ApplyBottomFog(col, o.worldPos.xyz, viewDir.y);

#if _OFFSET_BY_HEIGHT
					FragColDepth result;
					result.depth = calculateFragmentDepth(o.worldPos + (displacement - 0.5) * offsetAmount * viewDir * _HeightOffset);
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
				Name "ShadowCaster"
				Tags { "LightMode" = "ShadowCaster" }

				ZWrite On ZTest LEqual Cull Off

				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma target 2.0
				#pragma multi_compile_instancing
				#pragma multi_compile_shadowcaster

				#include "UnityCG.cginc"

				struct v2f 
				{
					float2 texcoord : TEXCOORD2;
					V2F_SHADOW_CASTER;
					UNITY_VERTEX_OUTPUT_STEREO

				};

			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;
			sampler2D _MainTex;

				v2f vert(appdata_full v)
				{
					v2f o;

					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
					o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);

					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
					TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)

					return o;
				}


				float4 frag(v2f o) : SV_Target
				{
					float4 tex = tex2D(_MainTex, o.texcoord);
					clip(tex.a - 0.1);

					SHADOW_CASTER_FRAGMENT(o)

					
				}
				ENDCG
			}

		}
		Fallback "Diffuse"
	}
}