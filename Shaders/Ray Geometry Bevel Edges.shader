Shader "RayTracing/Geometry/Beveled Edges "
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		[KeywordEnum(OFF, PLASTIC, METAL, LAYER, MIXED_METAL, PAINTED_METAL)] _REFLECTIVITY("Reflective Material Type", Float) = 0
		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0

		_BumpMap("Normal Map", 2D) = "bump" {}

		[KeywordEnum(MADS, None, Separate)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}
		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0

		_EdgeColor("Edge Color Tint", Color) = (0.5,0.5,0.5,0)
		_EdgeMads("Edge (Metal, AO, Displacement, Smoothness)", Vector) = (0,1,1,0)

		[Toggle(_OFFSET_BY_HEIGHT)] heightOffset("Offset By Height", Float) = 0

		_Reflectivity("Added Reflectiveness (Mat)", Range(0,1)) = 0.33
			_MetalColor("Metal Color", Color) = (0.5, 0.5, 0.5, 0)

	}

	Category{
		SubShader{

			// Color.a is used for Ambient SHadow + Edge visibility

			Tags{
				"Queue" = "Geometry"
				"RenderType" = "Opaque"
				"LightMode" = "ForwardBase"
				"Solution" = "Bevel With Seam"

			}

			ColorMask RGBA
			Cull Back

			Pass{

				CGPROGRAM


			
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				#pragma shader_feature_local ___ _OFFSET_BY_HEIGHT
				#pragma shader_feature_local ___ _COLOR_R_AMBIENT
				#pragma shader_feature_local _AO_NONE _AO_MADS _AO_SEPARATE
				#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
				#pragma shader_feature_local _REFLECTIVITY_OFF _REFLECTIVITY_PLASTIC _REFLECTIVITY_METAL _REFLECTIVITY_LAYER  _REFLECTIVITY_MIXED_METAL  _REFLECTIVITY_PAINTED_METAL


				#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
				#pragma multi_compile __ _qc_IGNORE_SKY 

				#include "Assets/Ray-Marching/Shaders/Savage_Sampler_Debug.cginc"


				struct v2f {
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float3 worldPos		: TEXCOORD1;
					float3 normal		: TEXCOORD2;
					float4 wTangent		: TEXCOORD3;
					float3 viewDir		: TEXCOORD4;
					SHADOW_COORDS(5)
					float4 edge			: TEXCOORD6;
					float3 snormal		: TEXCOORD7;
					float3 edgeNorm0	: TEXCOORD8;
					float3 edgeNorm1	: TEXCOORD9;
					float3 edgeNorm2	: TEXCOORD10;
					float4 traced : TEXCOORD11;
					fixed4 color : COLOR;
				};

				sampler2D _MainTex;
				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				float4 _EdgeColor;
				sampler2D _Map;
				float4 _Map_ST;
				

				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.worldPos = mul(unity_ObjectToWorld, v.vertex);
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);

				
					o.edge = float4(v.texcoord1.w, v.texcoord2.w, v.texcoord3.w, v.texcoord.w);
					o.edgeNorm0 = UnityObjectToWorldNormal(v.texcoord1.xyz);
					o.edgeNorm1 = UnityObjectToWorldNormal(v.texcoord2.xyz);
					o.edgeNorm2 = UnityObjectToWorldNormal(v.texcoord3.xyz);

					float3 deEdge = 1 - o.edge.xyz;

					// This one is inconsistent with Batching
					o.snormal.xyz = normalize(o.edgeNorm0 * deEdge.x + o.edgeNorm1 * deEdge.y + o.edgeNorm2 * deEdge.z);
					
					o.traced = GetTraced_Mirror_Vert(o.worldPos, normalize(o.viewDir.xyz), o.normal.xyz);


					TRANSFER_SHADOW(o);
					TRANSFER_WTANGENT(o)

					return o;
				}


				sampler2D _SpecularMap;
				sampler2D _BumpMap;
				float4 _EdgeMads;
				float _HeightOffset;
				float _Reflectivity;
				float4 _MetalColor;

				#if _AO_SEPARATE
				sampler2D _OcclusionMap;
#endif

#if _OFFSET_BY_HEIGHT
				FragColDepth frag(v2f i)
#else 
				float4 frag(v2f i) : COLOR
#endif
				{


					float3 viewDir = normalize(i.viewDir.xyz);

					float4 seam = i.color;
					float edgeColorVisibility;
					float3 preNormal = GetBeveledNormal_AndSeam(seam, i.edge,viewDir, i.normal.xyz, i.snormal.xyz, i.edgeNorm0, i.edgeNorm1, i.edgeNorm2, edgeColorVisibility);
	
					edgeColorVisibility *= _EdgeColor.a;

					float3 distanceToCamera = length(_WorldSpaceCameraPos - i.worldPos);

					float3 normal = preNormal;

					float rawFresnel = dot(viewDir, normal);

					rawFresnel = smoothstep(1, 0, rawFresnel);

					float offsetAmount = (1 + rawFresnel * rawFresnel * 4);

					float2 uv = i.texcoord.xy;

					float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));
					uv -= tnormal.rg * _MainTex_TexelSize.xy;
				
					float4 madsMap = tex2D(_SpecularMap, uv);

					madsMap = lerp(madsMap, _EdgeMads, edgeColorVisibility);

					float displacement = madsMap.b;

					float ao;

#if _AO_SEPARATE
					ao = tex2D(_OcclusionMap, uv).r;
#elif _AO_MADS
					ao = madsMap.g;
#else 
					ao = 1;
#endif


					ao = lerp(ao,1, rawFresnel);

#if _COLOR_R_AMBIENT
					ao *= (0.25 + i.color.r * 0.75);
#endif


					float4 tex = tex2D(_MainTex, uv);

					tex = lerp(tex, _EdgeColor, edgeColorVisibility);
		

					ApplyTangent(normal, tnormal, i.wTangent);


					float metal = madsMap.r;
					float fresnel = GetFresnel_FixNormal(normal,  i.snormal.xyz, viewDir) * ao; //(1 - saturate(dot(normal, viewDir))) * ao;
					float specular = madsMap.a; // GetSpecular(madsMap.a, fresnel, metal);

					float shadow = SHADOW_ATTENUATION(i);



					MaterialParameters precomp;
					
					precomp.shadow = shadow;
					precomp.ao = ao;
					precomp.fresnel = fresnel;
					precomp.tex = tex;
				
					precomp.reflectivity = _Reflectivity;
					precomp.metal = step(0.5, metal);
					precomp.traced = i.traced;
					precomp.water = 0;
					precomp.smoothsness = specular;
					precomp.microdetail = _EdgeColor; //_MudColor;
					precomp.microdetail.a = 0;
					precomp.metalColor = lerp(tex, _MetalColor, _MetalColor.a);

					float3 col = GetReflection_ByMaterialType(precomp, normal, i.normal.xyz, viewDir, i.worldPos);


					/*
					float3 lightColor = Savage_GetDirectional_Opaque(shadow, ao, normal,  i.worldPos);

					// LIGHTING
					float3 bake;

					float3 volumeSamplePosition;
					bake = Savage_GetVolumeBake(i.worldPos, normal.xyz, normalize(i.normal + 0.01), volumeSamplePosition);

					TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
					float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, i.worldPos);
					ao *= topDownAmbient.a;
					bake += topDownAmbient.rgb;

					float3 reflectionColor = 0;
					float3 pointLight = GetPointLight(volumeSamplePosition, normal, ao, viewDir, specular, reflectionColor);

					float3 diffuseColor = (pointLight + lightColor + bake * ao);

					float3 col = tex.rgb * diffuseColor;


					// ********************* Reflection
					float3 reflectedRay = reflect(-viewDir, normal);

					float4 topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, i.worldPos, i.normal.xyz, specular);
					ao *= topDownAmbientSpec.a;
					reflectionColor += topDownAmbientSpec.rgb;
					reflectionColor = GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular, i.traced);

					reflectionColor *= ao;

					reflectionColor += GetDirectionalSpecular(normal, viewDir, specular) * lightColor;// pow(dott, power) * brightness;

					MixInSpecular(col, reflectionColor, tex, metal, lerp(specular,1,_Reflectivity*fresnel), fresnel);
					*/


			
					ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

#if _OFFSET_BY_HEIGHT
					FragColDepth result;
					result.depth = calculateFragmentDepth(i.worldPos + (displacement - 0.5) * offsetAmount * viewDir * _HeightOffset);
					result.col = float4(col, 1);

					return result;
#else 
					return float4(col, 1);
#endif

				}
				ENDCG
			}
			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
		}
		Fallback "Diffuse"
	}
}