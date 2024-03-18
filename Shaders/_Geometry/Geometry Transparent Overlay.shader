Shader "QcRendering/Geometry/With Transparent Overlay"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}

		[KeywordEnum(OFF, PLASTIC, METAL, LAYER, MIXED_METAL, PAINTED_METAL)] _REFLECTIVITY("Reflective Material Type", Float) = 0
		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0

		_Reflectivity("Added Reflectiveness (Mat)", Range(0,1)) = 0.33

		_BumpMap("Normal Map", 2D) = "bump" {}

		_Overlay("Overlay Mask (RGB)", 2D) = "white" {}
		_OverlayTexture("Overlay Texture (RGB)", 2D) = "white" {}

		[Toggle(_SHOWUVTWO)] thisDoesntMatter("Debug Uv 2", Float) = 0

		[Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
		_SubSurface("Sub Surface Scattering", Color) = (1,0.5,0,0)
		_SkinMask("Skin Mask (_UV2)", 2D) = "white" {}

		_MudColor("Water Color", Color) = (0.5, 0.5, 0.5, 0.5)
	}

	Category
	{
		SubShader
		{
			CGINCLUDE

				#define RENDER_DYNAMICS

				#pragma multi_compile ___ _qc_IGNORE_SKY
				#pragma multi_compile __ _qc_USE_RAIN 

				#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
				#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
				#pragma shader_feature_local _REFLECTIVITY_OFF _REFLECTIVITY_PLASTIC _REFLECTIVITY_METAL _REFLECTIVITY_LAYER  _REFLECTIVITY_MIXED_METAL  _REFLECTIVITY_PAINTED_METAL

				  #include "UnityCG.cginc"
				#include "AutoLight.cginc"
				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"

				float4 _MudColor;

				sampler2D _MainTex_ATL_UvTwo;
				float4 _MainTex_ATL_UvTwo_TexelSize;

				sampler2D _MainTex;
				sampler2D _Bump;
				sampler2D _SkinMask;
				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				float4 _SubSurface;

				float4 _Overlay_ST;
				sampler2D _Overlay;

				float4 _OverlayTexture_ST;
				sampler2D _OverlayTexture;

				sampler2D _Map;
				float4 _Map_ST;

				float GetOverlayAlpha(float3 worldPos, float3 normal)
				{
					float2 uv = worldPos.xz;
					float2 uv2 = TRANSFORM_TEX(uv, _Overlay);

					float4 mask = tex2D(_Overlay, uv2).r;
					return mask * smoothstep(0.75, 1, normal.y);
				}

				float GetOverlayTexture(float3 worldPos, float3 normal)
				{
					float2 uv = worldPos.xz;
					float2 uv1 = TRANSFORM_TEX(uv, _OverlayTexture);
					float4 tex = tex2D(_OverlayTexture, uv1); 
					return tex.a;
				}

				float4 GetOverlay(float3 worldPos, float3 normal)
				{
					float2 uv = worldPos.xz;
					float2 uv1 = TRANSFORM_TEX(uv, _OverlayTexture);
					float2 uv2 = TRANSFORM_TEX(uv, _Overlay);

					float4 tex = tex2D(_OverlayTexture, uv1); 
					float4 mask = tex2D(_Overlay, uv2).r;
					tex.a = mask * tex.a * smoothstep(0.75, 1, normal.y);
					return tex;
				}

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

					float2 lightMapUv : TEXCOORD7;
					float4 traced : TEXCOORD8;
					float4 screenPos :		TEXCOORD9;
					fixed4 color : COLOR;
				};

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

					o.traced = GetTraced_Mirror_Vert(o.worldPos, normalize(o.viewDir.xyz), o.normal.xyz);
						o.screenPos = ComputeScreenPos(o.pos);
					TRANSFER_WTANGENT(o);
					TRANSFER_SHADOW(o);

					return o;
				}

				sampler2D _BumpMap;
				sampler2D _SpecularMap;

				float _Reflectivity;

				float4 frag(v2f i) : COLOR
				{
					float2 uv = i.texcoord.xy;
					float2 screenUv = i.screenPos.xy / i.screenPos.w;
					float3 viewDir = normalize(i.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, i.normal.xyz));

					float4 tex = tex2D(_MainTex, uv);
					float4 madsMap = tex2D(_SpecularMap, uv);
					float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));
					//uv -= tnormal.rg * _MainTex_TexelSize.xy;

					float water = 0;
				
					float3 normal = i.normal.xyz;

					ApplyTangent(normal, tnormal, i.wTangent);

					float ao = SampleSSAO(screenUv) * madsMap.g;
					float displacement = madsMap.b;

					float overlayAmbient = GetOverlayAlpha(i.worldPos, i.normal.xyz);

					float overlayMask =	GetOverlayTexture(i.worldPos, i.normal.xyz) * overlayAmbient;
		
					float overlayShadow = (1-overlayMask);// * 0.5;

					float shadow = SHADOW_ATTENUATION(i) * overlayShadow;


				#if _qc_USE_RAIN

					float rain = GetRain(i.worldPos, normal, i.normal, shadow);

					//glossLayer =  
					ApplyWater(water, rain, ao, displacement, madsMap, tnormal, i.worldPos, i.normal.y);

					normal = i.normal.xyz;
					ApplyTangent(normal, tnormal, i.wTangent);

				#endif

					float specular = madsMap.a; 
					

		

					#if _qc_USE_RAIN 
						ModifyColorByWetness(tex.rgb, water,madsMap.a, _MudColor);
					#endif

				

					ao *= (1 - overlayAmbient);// * 0.5;



					float fresnel = GetFresnel(normal, viewDir) * ao;

				//	return overlayShadow;

					// LIGHTING

					MaterialParameters precomp;
					
					precomp.shadow = shadow;
					precomp.ao = ao;
					precomp.fresnel = fresnel;
					precomp.tex = tex;
				
					precomp.reflectivity = _Reflectivity;
					precomp.metal = madsMap.r;
					precomp.traced = i.traced;
					precomp.water = water;
					precomp.smoothsness = specular;

					precomp.microdetail = _MudColor;

					precomp.microdetail.a = 0;
		
				//	return ao;

					float3 col = GetReflection_ByMaterialType(precomp, normal, i.normal.xyz, viewDir, i.worldPos);



					ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

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
					float3 worldPos		: TEXCOORD3;
					float3 normal		: TEXCOORD4;
					float4 wTangent		: TEXCOORD5;
					float3 viewDir		: TEXCOORD6;
					SHADOW_COORDS(7)

					float4 screenPos : TEXCOORD9;
					float2 lightMapUv : TEXCOORD10;
					fixed4 color : COLOR;
				};

				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.texcoord = v.texcoord;
				
					float2 texUv = TRANSFORM_TEX(v.texcoord, _Overlay);
					float4 tex = tex2Dlod(_Overlay, float4(texUv,0,0));

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
					TRANSFER_SHADOW(o);

					return o;
				}


				


				float4 frag(v2f o) : COLOR
				{
					float2 uv = o.texcoord.xy;

					float2 screenUV = o.screenPos.xy / o.screenPos.w;
					float3 viewDir = normalize(o.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, o.normal.xyz));

					
					float4 tex = GetOverlay(o.worldPos, o.normal.xyz); 
				

					float3 normal = o.normal.xyz;
					float fresnel = saturate(dot(normal,viewDir));
					float smoothness = 0.5 * tex.a;
					float ambient = 1;

					float shadow = SHADOW_ATTENUATION(o);// * SampleSkyShadow(o.worldPos);

					float direct = shadow * max(0, dot(normal, _WorldSpaceLightPos0.xyz));
					
					float3 lightColor = GetDirectional() * direct;

					// LIGHTING
					
					
					float3 volumePos = o.worldPos;

					float4 bakeRaw = 0;

						float outOfBounds;
						bakeRaw = SampleVolume(volumePos, outOfBounds);
						bakeRaw.rgb = lerp(bakeRaw.rgb, GetAvarageAmbient(normal), outOfBounds);
	
						float4 bake = bakeRaw;

		
					float3 col = lightColor + bake.rgb * ambient;
					
					col.rgb *=tex.rgb;

					//AddGlossToCol(lightColor);

					//return 0;

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