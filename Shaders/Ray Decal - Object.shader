Shader "RayTracing/Geometry/Standard Smooth 3D (Transparent)"
{
	Properties
	{
		[NoScaleOffset] _MainTex("Texture", 2D) = "white" {}
		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		[KeywordEnum(OFF, PLASTIC, LAYER)] _REFLECTIVITY("Reflective Material Type", Float) = 0
		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0
		_BumpMap("Normal Map", 2D) = "bump" {}
		[KeywordEnum(None, MADS, Separate)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}
		[Toggle(_AMBIENT_IN_UV2)] ambInuv2("Ambient mapped to UV2", Float) = 0
		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0

		[Toggle(_PARALLAX)] parallax("Parallax", Float) = 0
		_ParallaxForce("Parallax Amount", Range(0.001,0.01)) = 0.01

		_InvFade("Soft Particles Factor", Range(0,3)) = 1.0

		_MergeHeight("MADS Height Impact", Range(0.1,5)) = 0.5

		_OffsetFade("Fade When Far", Range(0.1,50)) = 1

		_MudColor("Water Color", Color) = (0.5, 0.5, 0.5, 0.5)

		_Reflectivity("Added Reflectiveness (Mat)", Range(0,1)) = 0.33
	}

		Category
		{
			Tags
			{
				"Queue" = "AlphaTest+50"
				"IgnoreProjector" = "True"
				"RenderType" = "Opaque"
			}

			SubShader
			{
				Pass
				{
					Blend SrcAlpha OneMinusSrcAlpha
					ColorMask RGBA
					Cull Back
					ZWrite On
					//ZTest Off

					CGPROGRAM

					#pragma vertex vert
					#pragma fragment frag
					#pragma multi_compile_instancing

					#pragma multi_compile_fwdbase
					#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING
					
					#pragma multi_compile ___ _qc_USE_RAIN 
					#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
					#pragma multi_compile ___ _qc_IGNORE_SKY 

					#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
					#pragma shader_feature_local _REFLECTIVITY_OFF _REFLECTIVITY_PLASTIC  _REFLECTIVITY_LAYER
					#pragma shader_feature_local ___ _PARALLAX

					#pragma shader_feature_local ___ _AMBIENT_IN_UV2
					#pragma shader_feature_local _AO_NONE _AO_MADS _AO_SEPARATE
					#pragma shader_feature_local ___ _COLOR_R_AMBIENT
					//#define RENDER_DYNAMICS

					#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Debug.cginc"
					#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"

					struct v2f
					{
						float4 pos : POSITION;
						UNITY_VERTEX_INPUT_INSTANCE_ID // use this to access instanced properties in the fragment shader.
						float2 texcoord: TEXCOORD0;
						float2 texcoord1	: TEXCOORD1;
						float4 screenPos : TEXCOORD2;
						float3 viewDir	: TEXCOORD3;
						float3 worldPos : TEXCOORD4;
						float4 wTangent		: TEXCOORD5;
						float3 normal		: TEXCOORD6;
						SHADOW_COORDS(7)
						float4 traced : TEXCOORD8;
#if _PARALLAX 
						float3 tangentViewDir : TEXCOORD9; // 5 or whichever is free
#endif
						fixed4 color : COLOR;

					};


		float4 _Color;

					v2f vert(appdata_full v)
					{
						v2f o;

						UNITY_SETUP_INSTANCE_ID(v);
						UNITY_TRANSFER_INSTANCE_ID(v, o);

						o.pos = UnityObjectToClipPos(v.vertex);
						o.worldPos = mul(unity_ObjectToWorld, v.vertex);
						o.screenPos = ComputeScreenPos(o.pos);
						o.texcoord = v.texcoord;
						o.texcoord1 = v.texcoord1;
						o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
						o.color = v.color * _Color;
						o.normal.xyz = UnityObjectToWorldNormal(v.normal);

						o.traced = GetTraced_Mirror_Vert(o.worldPos, normalize(o.viewDir.xyz), o.normal.xyz);


#					if _PARALLAX || _DAMAGED
						TRANSFER_TANGENT_VIEW_DIR(o);
#					endif
						TRANSFER_WTANGENT(o)
						TRANSFER_SHADOW(o);
						COMPUTE_EYEDEPTH(o.screenPos.z);
						return o;
					}


#if _AO_SEPARATE
					sampler2D _OcclusionMap;
#endif


					sampler2D _BumpMap;
					sampler2D _SpecularMap;
					sampler2D _MicrodetailMap;
					float _ParallaxForce;
					sampler2D _MainTex;
					float4 _MainTex_ST;
					float4 _MainTex_TexelSize;
					float _InvFade;
					float _MergeHeight;
					float _Reflectivity;
					float4 _MudColor;
					float _OffsetFade;

					float4 frag(v2f i) : COLOR
					{
						float2 screenUV = i.screenPos.xy / i.screenPos.w;
						float3 viewDir = normalize(i.viewDir.xyz);

						float rawFresnel = saturate(1 - dot(viewDir, i.normal.xyz));
						float offsetAmount = (1 + rawFresnel * rawFresnel * 4);

						float2 uv = i.texcoord.xy;
						float4 madsMap = tex2D(_SpecularMap, uv);

						//	return madsMap.g;

						float displacement = madsMap.b;


						float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
						float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
						float partZ = i.screenPos.z;

						float differ = sceneZ - partZ;
						
						differ *= 1+ displacement*offsetAmount * _MergeHeight;

						//return differ;

						float alpha = smoothstep(0,  _InvFade, differ) // / (0.01 * 5 * length(fwidth(i.worldPos))))
							* smoothstep (0.2 + _MergeHeight * 10, 0.1 + _MergeHeight * 4 ,differ / _OffsetFade) 						
						;

					//	return alpha;

						clip(alpha-0.01);


#if _PARALLAX
						i.tangentViewDir = normalize(i.tangentViewDir);
						i.tangentViewDir.xy /= i.tangentViewDir.z; // abs(i.tangentViewDir.z + 0.42);
						_ParallaxForce /= offsetAmount;

						CheckParallax(uv, madsMap, _SpecularMap, i.tangentViewDir, _ParallaxForce, displacement);
#endif


						float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));

						#if _PARALLAX
							uv -= tnormal.rg * _MainTex_TexelSize.xy;
						#endif
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

						float4 tex = tex2D(_MainTex, uv);

						ApplyTangent(normal, tnormal, i.wTangent);




// ********************** WATER

float water = 0;
float glossLayer = 0;

	float shadow = getShadowAttenuation(i.worldPos);

#if _qc_USE_RAIN

					float rain = GetRain(i.worldPos, normal, i.normal, shadow);
					glossLayer = ApplyWater(water, rain, ao, displacement, madsMap, tnormal, i.worldPos, i.normal.y);

					//normal = i.normal.xyz;
				//	ApplyTangent(normal, tnormal, i.wTangent);

					//shadow = lerp(shadow, 1, glossLayer);
#endif

					// **************** light

						float metal = madsMap.r;
						float fresnel = GetFresnel(normal, viewDir) * ao;// (1 - saturate(dot(normal, viewDir))) * ao;
						float specular = GetSpecular(madsMap.a, fresnel* _Reflectivity, metal);

					


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

					precomp.microdetail = _MudColor;
					precomp.metalColor = _MudColor; //lerp(tex, _MetalColor, _MetalColor.a);

					precomp.microdetail.a = 0;
				
					float3 col = GetReflection_ByMaterialType(precomp, normal, i.normal.xyz, viewDir, i.worldPos);

					ApplyBottomFog(col.rgb, i.worldPos.xyz, i.viewDir.y);

					
					//col = ao;
				//	return alpha;


						return float4(col,alpha);

					}
					ENDCG
				}
				//UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
			}
			//Fallback "Diffuse"
		}
}