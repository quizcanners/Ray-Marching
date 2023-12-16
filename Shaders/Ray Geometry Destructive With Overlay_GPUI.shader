Shader "GPUInstancer/RayTracing/Geometry/Destructive With Overlay"
{
	Properties
	{
		_MainTex("Main Albedo (RGB)", 2D) = "white" {}
		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		[KeywordEnum(OFF, PLASTIC, LAYER)] _REFLECTIVITY("Reflective Material Type", Float) = 0
		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0
		_Reflectivity("Added Reflectiveness (Mat)", Range(0,1)) = 0.33

		_BumpMap("Normal Map", 2D) = "bump" {}

		[KeywordEnum(MADS, None, Separate, Displacement)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}
		

		_Overlay("Overlay Mask (RGB)", 2D) = "white" {}
		_OverlayTiling("Overlay Tiling", float) = 1
		_OverlayTexture("Overlay Texture (RGB)", 2D) = "black" {}


		[Toggle(_DAMAGED)] isDamaged("_DAMAGED", Float) = 0
		[NoScaleOffset] _Damage_Tex("DAMAGE (_UV1 for Beveled)", 2D) = "black" {}
		_DamDiffuse("Damaged Diffuse", 2D) = "white" {}
		[NoScaleOffset]_BumpD("Bump Damage", 2D) = "gray" {}
		_DamDiffuse2("Damaged Diffuse Deep", 2D) = "white" {}
		[NoScaleOffset]_BumpD2("Bump Damage 2", 2D) = "gray" {}
		_BloodPattern("Blood Pattern", 2D) = "gray" {}


		[Toggle(_MERGE_WITH_TERRAIN)] mergeWithTerrain("Merge With Terrain", Float) = 0
		_MergeHeight("Merge Height", Range(0,5)) = 1
        _BlendSharpness("Blend Sharpness", Range(0,1)) = 0

		[Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
		_SubSurface("Sub Surface Scattering", Color) = (1,0.5,0,0)
		_SkinMask("Skin Mask (_UV2)", 2D) = "white" {}
	}


	SubShader
	{
		CGINCLUDE

		#pragma shader_feature_local ___ _DAMAGED
		#pragma shader_feature_local ___ _SUB_SURFACE

		#pragma shader_feature_local ___ _AMBIENT_IN_UV2
		#pragma shader_feature_local _AO_NONE _AO_MADS _AO_SEPARATE
		#pragma shader_feature_local ___ _COLOR_R_AMBIENT

		#pragma shader_feature_local ___ _MERGE_WITH_TERRAIN
		#pragma multi_compile ___ QC_MERGING_TERRAIN

		#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
		#pragma multi_compile __ _qc_IGNORE_SKY 
		#pragma multi_compile __ _qc_USE_RAIN 

		#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
		#pragma shader_feature_local _REFLECTIVITY_OFF _REFLECTIVITY_PLASTIC  _REFLECTIVITY_LAYER   

		#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Debug.cginc"
		#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"

		#include "Assets\The-Fire-Below\Common\Shaders\qc_terrain_cg.cginc"

		sampler2D _Damage_Tex;
		float4 _SubSurface;
			
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
#include "UnityCG.cginc"
#include "./../../GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
#pragma instancing_options procedural:setupGPUI
#pragma multi_compile_instancing

			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_fwdbase
			#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

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

			sampler2D _MainTex;
		
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;
			
			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

				o.normal.xyz = UnityObjectToWorldNormal(v.normal);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.texcoord1 = v.texcoord1;
				o.worldPos = worldPos;
				
				o.color = v.color;
				o.viewDir = WorldSpaceViewDir(v.vertex);

				o.traced = GetTraced_Mirror_Vert(o.worldPos, normalize(o.viewDir.xyz), o.normal.xyz);


				TRANSFER_WTANGENT(o);
				TRANSFER_SHADOW(o);

				return o;
			}

			sampler2D _SkinMask;
			sampler2D _SpecularMap;

			sampler2D _BumpMap;

#if _AO_SEPARATE
			sampler2D _OcclusionMap;
#endif

#			if _DAMAGED
			sampler2D _DamDiffuse;
			float4 _DamDiffuse_TexelSize;

			sampler2D _DamDiffuse2;
			float4 _DamDiffuse2_TexelSize;

			sampler2D _BumpD;
			sampler2D _BumpD2;
#			endif

			sampler2D _Overlay;
			float _MergeHeight;
			float _BlendSharpness;
			float _Reflectivity;

			float4 frag(v2f i) : COLOR
			{

				float3 viewDir = normalize(i.viewDir.xyz);
				float3 normal = i.normal.xyz;
				float rawFresnel = smoothstep(1,0, dot(viewDir, normal));
				float2 uv = i.texcoord.xy;
				float offsetAmount = (1 + rawFresnel * rawFresnel * 4);
				float4 madsMap = tex2D(_SpecularMap, uv);
				float displacement = madsMap.b;

				float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));
				uv -= tnormal.rg * _MainTex_TexelSize.xy;


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

				float overlay = (2 - tex2D(_Overlay, i.texcoord1).r * smoothstep(0.85, 1, normal.y)) * 0.5;

				ao *= overlay;

				float4 tex = tex2D(_MainTex, uv);//TODO: Mose this down

				float water = 0;

#				if _DAMAGED

				// R - Blood
				// G - Damage

				float2 damUV = i.texcoord;

				float2 damPix = _Damage_Tex_TexelSize.xy;

				//float2 maskUv = i.texcoord1 + i.tangentViewDir.xy * (-damDepth) * 2 * deOff;

				float4 mask = tex2D(_Damage_Tex, i.texcoord1);// .r;// -mask.g;
				float4 maskY = tex2D(_Damage_Tex, i.texcoord1 + float2(0, damPix.y));
				float4 maskX = tex2D(_Damage_Tex, i.texcoord1 + float2(damPix.x, 0));

				float noise = tex2D(_BloodPattern, damUV * 4.56).r;

				float3 damBump = normalize(float3(maskX.g - mask.g, maskY.g - mask.g, 0.1));

				float damDepth = mask.g * 2 - displacement;

				damUV += i.tangentViewDir.xy * (-damDepth) * 2 * deOff;

				damDepth += mask.g - noise;

				float damAlpha = smoothstep(0, 0.5, damDepth);
				float damAlpha2 = smoothstep(1, 1.5, damDepth);

				float4 dam = tex2D(_DamDiffuse, damUV * 4);
				float4 dam2 = tex2D(_DamDiffuse2, damUV);

				float3 damTnormal = UnpackNormal(tex2D(_BumpD, damUV * 4));
				float3 damTnormal2 = UnpackNormal(tex2D(_BumpD2, damUV));

				dam = lerp(dam, dam2, damAlpha2);
				damTnormal = lerp(damTnormal, damTnormal2, damAlpha2);

				tnormal = lerp(tnormal, damBump + damTnormal, damAlpha);
				tex = lerp(tex, dam, damAlpha);

				float damHole = smoothstep(4, 0, damDepth);

				ao = lerp(ao, damHole, damAlpha);
				water = lerp(water, 0, damAlpha);
				displacement = lerp(displacement, 0.2 * (1 - damAlpha2), damAlpha);
				madsMap = lerp(madsMap, float4(0.3, 0, 0, 0), damAlpha);

				mask *= smoothstep(0, 1, (2 - damHole + noise));

				float showRed = ApplyBlood(mask, water, tex.rgb, madsMap, displacement);

#				endif


			
				ApplyTangent(normal, tnormal, i.wTangent);

	// ***************** Microdetail	

#if _MICRODETAIL
				//_MicrodetailMap
				float microdetSample = tex2D(_MicrodetailMap, TRANSFORM_TEX(uv, _MicrodetailMap)).a;

				float microOffset = microdetSample - 0.5;

				float microdet = abs(microOffset);

				microOffset = step(0, microdetSample);

#				if _DAMAGED
				microdet *= (1 - damAlpha);
#endif

				microdet *= smoothstep(0.2, 0, water);

				tex.rgb = lerp(tex.rgb, microOffset, microdet);
#endif

				
				// ***************** Terrain

#if _MERGE_WITH_TERRAIN && QC_MERGING_TERRAIN
				madsMap.g = ao;
				MergeWithTerrain(i.worldPos, normal, madsMap, tex.rgb, _MergeHeight, _BlendSharpness);
				ao = madsMap.g;
				displacement = madsMap.b;
#endif


				// ********************** WATER
					float shadow = SHADOW_ATTENUATION(i) * overlay * i.traced.a;

#if _qc_USE_RAIN

				float rain = GetRain(i.worldPos, normal, i.normal, shadow);

				water *= 0.5; // For Terrain only

				float flatten = ApplyWater(water, rain, ao, displacement, madsMap, tnormal, i.worldPos, normal.y);

				normal = lerp(normal, i.normal.xyz, flatten);
#endif


	
		float3 worldPosAdjusted = i.worldPos;
		ao *= SampleContactAO_OffsetWorld(worldPosAdjusted, normal);


				// **************** light
				float metal = madsMap.r;
				float fresnel = GetFresnel(normal, viewDir);
				ao += fresnel * (1-ao); 
				fresnel *= ao;

				float specular = madsMap.a * madsMap.a;


#if _MICRODETAIL
				specular = lerp(specular, 1 - microOffset, microdet);
#endif

#if _DAMAGED
				specular *= (6 - showRed) / 6;
#endif

				//return specular;

			

			/*
#if _qc_USE_RAIN || _DAMAGED
					ModifyColorByWetness(tex.rgb, water,madsMap.a, _MudColor);
#endif
*/

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

					precomp.microdetail = 0; //_MudColor;
					precomp.metalColor = tex; //lerp(tex, _MetalColor, _MetalColor.a);

					precomp.microdetail.a = 0;


					float3 col = GetReflection_ByMaterialType(precomp, normal, i.normal.xyz, viewDir, worldPosAdjusted);


		



				ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

				return float4(col,1);

			}
			ENDCG
		}

		/*
		Pass
		{
			Cull Front

			CGPROGRAM
#include "UnityCG.cginc"
#include "./../../GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
#pragma instancing_options procedural:setupGPUI
#pragma multi_compile_instancing
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"


			struct v2f
			{
				float4 pos			: SV_POSITION;
				float2 texcoord:	TEXCOORD0;
				float2 texcoord1 : TEXCOORD1;
				float3 worldPos		: TEXCOORD2;
				float3 normal		: TEXCOORD3;
				float4 wTangent		: TEXCOORD4;
				float3 viewDir		: TEXCOORD5;
				float3 tc_Control : TEXCOORD6;
				SHADOW_COORDS(4)

				fixed4 color : COLOR;
			};

		float4 _MainTex_ST;

			v2f vert(appdata_full v)
			{
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

				o.tc_Control = WORLD_POS_TO_TERRAIN_UV_3D(worldPos);

				TRANSFER_WTANGENT(o)
				TRANSFER_SHADOW(o);

				return o;
			}

			float4 frag(v2f o) : SV_Target
			{

				float2 damUv = o.texcoord1.xy;
				float4 mask = tex2D(_Damage_Tex, damUv);

				// R - Blood
				// G - Damage

				float4 col =1;

				float shadow = SHADOW_ATTENUATION(o);

				PrimitiveLight(lightColor, ambientCol, outOfBounds, o.worldPos, float3(0,-1,0));
				TopDownSample(o.worldPos, ambientCol);

				col.rgb *= (ambientCol + lightColor * shadow);

			//	col.rgb *= tex2D(_DamDiffuse, o.uv);


				ApplyBottomFog(col.rgb, o.worldPos.xyz, o.viewDir.y);

				col = 1;

				return col;
			}
			ENDCG
		}*/

		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			ZWrite On ZTest LEqual Cull Off

			CGPROGRAM
#include "UnityCG.cginc"
#include "./../../GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
#pragma instancing_options procedural:setupGPUI
#pragma multi_compile_instancing
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile_shadowcaster
			
			#include "UnityCG.cginc"

			struct v2f 
			{
				float2 texcoord1 : TEXCOORD2;
				V2F_SHADOW_CASTER;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert(appdata_full v)
			{
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);

				float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
				o.texcoord1 = v.texcoord1;

				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)

				return o;
			}



			float4 frag(v2f o) : SV_Target
			{
				//float2 damUv = o.texcoord1.xy;
				//float4 mask = tex2D(_Damage_Tex, damUv);

				// R - Blood
				// G - Damage
			
				SHADOW_CASTER_FRAGMENT(o)
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
#include "UnityCG.cginc"
#include "./../../GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
#pragma instancing_options procedural:setupGPUI
#pragma multi_compile_instancing

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fwdbase
				#pragma shader_feature_local _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 
				
				#pragma shader_feature_local ___ _SHOWUVTWO

				//  sampler2D _CameraDepthTexture;

				struct v2f {
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float2 texcoord1	: TEXCOORD1;
					float2 texcoord2	: TEXCOORD2;
					float2 texcoordDam	: TEXCOORD3;
					float3 worldPos		: TEXCOORD4;
					float3 normal		: TEXCOORD5;
					float4 wTangent		: TEXCOORD6;
					float3 viewDir		: TEXCOORD7;
					SHADOW_COORDS(8)

					float4 screenPos : TEXCOORD10;
					fixed4 color : COLOR;
				};

			float4 _MainTex_ST;
			sampler2D _Overlay;
			float4 _OverlayTexture_ST;
			float _OverlayTiling;
			float4 _Overlay_ST;

				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.texcoord1 = TRANSFORM_TEX(v.texcoord, _OverlayTexture);
					o.texcoord2 = TRANSFORM_TEX(v.texcoord, _Overlay);
					o.texcoordDam = v.texcoord1;

					float toCamera = length(_WorldSpaceCameraPos - worldPos.xyz) - _ProjectionParams.y;

					//worldPos.xyz += o.normal.xyz * smoothstep(0,1, 0.05 * ( tex.a * 3) * toCamera) * 0.15; 
					worldPos.xyz += o.normal.xyz * (0.05 + smoothstep(0, 20, smoothstep(0.8, 0.9, o.normal.y)));

					v.vertex = mul(unity_WorldToObject, float4(worldPos.xyz, v.vertex.w));
					o.pos = UnityObjectToClipPos(v.vertex); 
					
					
					o.worldPos = worldPos;
					
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);
					 o.screenPos = ComputeScreenPos(o.pos);
					COMPUTE_EYEDEPTH(o.screenPos.z);

					TRANSFER_WTANGENT(o);
					TRANSFER_SHADOW(o);

					return o;
				}



				sampler2D _OverlayTexture;

				float4 frag(v2f i) : COLOR
				{
					float3 normal = i.normal.xyz;

					float2 uv = i.worldPos.xz * _OverlayTiling;

					float4 damMask = tex2D(_Damage_Tex, i.texcoordDam);


					float4 tex = tex2D(_OverlayTexture, uv);

					float3 gyrPos = i.worldPos + float3(_SinTime.x, _Time.z, 0) * 0.5;
					float gyr = abs(dot(sin(gyrPos), cos(gyrPos.zxy)));
					float gyrY = abs(dot(sin(gyrPos.zyx * 1.23), cos(gyrPos.yzx * 0.869)));
					float strength = 0.001 * (1 + 2 * tex.a);
					gyr *= strength;
					gyrY *= strength;
					float2 gyrUV = float2(gyr, gyrY) * 2.234;


					float4 mask = tex2D(_Overlay, i.texcoordDam).r;
					tex = tex2D(_OverlayTexture, uv + gyrUV);
					tex.a = mask * smoothstep(0.8,0.9,normal.y) * tex.a * (1-damMask.r)* (1-damMask.g) ; //smoothstep(0, 0.5, tex.a) ;


			
					float3 terrainUV = WORLD_POS_TO_TERRAIN_UV_3D(i.worldPos);

					float4 terrainControl = tex2D(_qcPp_mergeControl, terrainUV.xz);
			
					float overlay = smoothstep(0.75, 0.5, terrainControl.g + terrainControl.b + terrainControl.a);
					tex.a *= overlay;

					clip(tex.a - 0.01);

					float3 viewDir = normalize(i.viewDir.xyz);
					float2 screenUV = i.screenPos.xy / i.screenPos.w;
				//	float deFresnel = abs(dot(normal, viewDir));

					float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
					float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));

					float fade = smoothstep(0, 0.1f, sceneZ - i.screenPos.z);

					tex.a *= fade;

					float smoothness = 0.5 * tex.a;
					float ambient = 1;

					float shadow = SHADOW_ATTENUATION(i);

					float3 lightColor = Savage_GetDirectional_Opaque(shadow, ambient, normal, i.worldPos);

					float3 volumeSamplePosition;
					float3 bake = Savage_GetVolumeBake(i.worldPos, normal, i.normal, volumeSamplePosition);

					TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
					float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, i.worldPos);
					ambient *= topDownAmbient.a;
					bake += topDownAmbient.rgb;

					float specular = 0.5;

					float3 reflectionColor = 0;
					float3 pointLight = GetPointLight(volumeSamplePosition, normal, ambient, viewDir, specular, reflectionColor);

					float3 col = tex.rgb * (pointLight + lightColor + reflectionColor * specular + bake * ambient);

					ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);
					return float4(col, tex.a);

				}
				ENDCG
			}

	}
	Fallback "Diffuse"
	
}
