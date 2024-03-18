Shader "QcRendering/Geometry/Destructible Dynamic"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}

		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0

		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		_BumpMap("Normal Map", 2D) = "bump" {}

		[KeywordEnum(MADS, None, Separate)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}

		[Toggle(_AMBIENT_IN_UV2)] ambInuv2("Ambient mapped to UV2", Float) = 0
		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0

		_GorificationForce("Gorification", Range(0,1)) = 0

		[Toggle(_PARALLAX)] parallax("Parallax", Float) = 0
		_ParallaxForce("Parallax Amount", Range(0.001,0.3)) = 0.01

		[NoScaleOffset] _Damage_Tex("_Main DAMAGE (_UV2) (_ATL) (RGB)", 2D) = "black" {}

		_DamDiffuse("Damaged Diffuse", 2D) = "red" {}

		[Toggle(_USE_IMPACT)] useImpact("_USE_IMPACT", Float) = 0
		[Toggle(_DAMAGED)] isDamaged("_DAMAGED", Float) = 0

		[Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
		_SubSurface("Sub Surface Scattering", Color) = (1,0.5,0,0)
		_SkinMask("Skin Mask (_UV2)", 2D) = "white" {}


		_BloodNoise("Blood Noise", 2D) = "white" {}

		_Overlay("Overlay (RGBA)", 2D) = "white" {}
		_OverlayTiling("Overlay Tiling", float) = 1
	}


	SubShader
	{
		CGINCLUDE

		#pragma shader_feature_local ___ _USE_IMPACT
		#pragma shader_feature_local ___ _DAMAGED
		#pragma shader_feature_local ___ _SUB_SURFACE
		#pragma shader_feature_local ___ _PARALLAX

	
		#pragma shader_feature_local ___ _AMBIENT_IN_UV2
		#pragma shader_feature_local _AO_MADS  _AO_NONE   _AO_SEPARATE
		#pragma shader_feature_local ___ _COLOR_R_AMBIENT

		#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
	

		#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
		#pragma multi_compile __ _qc_IGNORE_SKY 

		#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"
		#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Transparent.cginc"
		#include "Assets/Qc_Rendering/Shaders/Signed_Distance_Functions.cginc"

		float _ImpactDisintegration;
		float _ImpactDeformation;
		float4 _ImpactPosition;
			

		float4 _SubSurface;

		float3 DeformVertex(float3 worldPos, float3 normal, out float impact)
		{
			float3 vec = _ImpactPosition.xyz - worldPos;
			float dist = length(vec);

			float gyr = abs(sdGyroid(worldPos * 12, 1));

			gyr = pow(gyr, 3);

			float deDist = 1/(1+dist);

			//float offset = ;

			float explode = _ImpactDisintegration * _ImpactDeformation;

			impact = smoothstep(0,2, (_ImpactDeformation * 0.1 + _ImpactDisintegration) *
				(deDist + gyr * 0.5 + smoothstep(_ImpactDeformation, 0, dist))); //*lerp(1.5, 0.75, finalStage));
				
			worldPos.xyz -= impact * explode * normalize(vec) * 0.25 * smoothstep(0.5,0, dist);

			float expansion = smoothstep(0, 1, explode * deDist);

			return worldPos.xyz -
				normalize(vec) * (expansion + explode) +
				normal * 0.1 * gyr * expansion ;
		}

		float GetDisintegration(float3 worldPos, float4 mask, float impact)
		{
			//float gyr = abs(sdGyroid(worldPos * 5, 1));
			float deInt = 1 - _ImpactDisintegration;
			float destruction = smoothstep(deInt, deInt + 0.1 , impact);
			return min(0.01 - destruction, 0.75f - mask.g);
		}

		float LightUpAmount(float3 worldPos)
		{
			float dist = length(_ImpactPosition.xyz - worldPos);
			return _ImpactDeformation * smoothstep(0.6, 0, dist);
		}

		void AddSubSurface(inout float3 col, float4 mask, float lightUp)
		{
#			if _DAMAGED && _USE_IMPACT
			float3 litColor = lerp(col * 0.5 + float3(3, 0, 0), float3(2, 1, 0), mask.g*0.5);

			col = lerp(col, litColor, lightUp * mask.g) ;
#			endif
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

#				if _USE_IMPACT
					float2 impact : TEXCOORD7;
#				endif

#if _PARALLAX || _DAMAGED
				float3 tangentViewDir : TEXCOORD8; // 5 or whichever is free
#endif
				float4 traced : TEXCOORD9;
				float4 screenPos : TEXCOORD10;
				fixed4 color : COLOR;
			};

			sampler2D _Damage_Tex;
			float4 _Damage_Tex_TexelSize;

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;

			sampler2D _SkinMask;
			float _ParallaxForce;

			sampler2D _BumpMap;
			sampler2D _SpecularMap;

			float4 _BloodNoise_ST;
			sampler2D _BloodNoise;

#if _AO_SEPARATE
			sampler2D _OcclusionMap;
#endif

#			if _DAMAGED
				sampler2D _DamDiffuse;
				float4 _DamDiffuse_TexelSize;
#			endif
						
			v2f vert(appdata_full v) 
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

				o.normal.xyz = UnityObjectToWorldNormal(v.normal);

#				if _USE_IMPACT
					v.vertex = mul(unity_WorldToObject, float4(DeformVertex(worldPos,o.normal.xyz,  o.impact.x), v.vertex.w));
					o.impact.y = LightUpAmount(worldPos);
#				endif

				o.pos = UnityObjectToClipPos(v.vertex);
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.texcoord1 = v.texcoord1;
				o.worldPos = worldPos;
				
				o.viewDir = WorldSpaceViewDir(v.vertex);

#				if _PARALLAX || _DAMAGED
					TRANSFER_TANGENT_VIEW_DIR(o);
#				endif

				o.traced = GetTraced_Mirror_Vert(o.worldPos, normalize(o.viewDir.xyz), o.normal.xyz);

				 o.screenPos = ComputeScreenPos(o.pos);

				TRANSFER_WTANGENT(o)
				TRANSFER_SHADOW(o);
				o.color = v.color;
				return o;
			}

			float _GorificationForce;

			float4 frag(v2f i) : COLOR
			{
				float2 damUv = i.texcoord1.xy;
				float4 mask = tex2D(_Damage_Tex, damUv);
				float4 noise = tex2D(_BloodNoise, damUv * _BloodNoise_ST.xy);
				 float2 screenUV = i.screenPos.xy / i.screenPos.w;
				//return mask;

#				if _USE_IMPACT

					//i.impact.x *= (1+noise.x)*0.5;

					i.impact.xy *= (0.5+noise.r);
					//float gyr = sdGyroid(i.worldPos * 20, 0.2);
					//float deInt = 1 - _ImpactDisintegration;

					//float redness = smoothstep(deInt * 0.75, deInt, i.impact.x);
					//mask.g = lerp(mask.g, 1, redness);
					//float destruction = smoothstep(deInt, deInt + 0.001 + gyr , i.impact );

					//clip(min(0.01 - destruction, 0.9f - mask.g));

					

					clip(GetDisintegration(i.worldPos, mask, i.impact.x));

					mask.r = lerp(mask.r, 1, i.impact.x);
					
					//return i.impact.y;
#				endif

mask *= (0.5+noise.r);

				float2 uv = i.texcoord.xy;
				float3 viewDir = normalize(i.viewDir.xyz);
				float rawFresnel = saturate(1 - dot(viewDir, i.normal.xyz));
				float offsetAmount = (1 + rawFresnel * rawFresnel * 4);
				float4 madsMap = tex2D(_SpecularMap, uv);
				float displacement = madsMap.b;
			


#if _PARALLAX || _DAMAGED
				i.tangentViewDir = normalize(i.tangentViewDir);
				i.tangentViewDir.xy /= i.tangentViewDir.z; // abs(o.tangentViewDir.z + 0.42);
				float deOff = _ParallaxForce / offsetAmount;

				CheckParallax(uv, madsMap, _SpecularMap, i.tangentViewDir, deOff, displacement);
#endif

				float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));
				uv -= tnormal.rg * _MainTex_TexelSize.xy;
				float3 normal = i.normal.xyz;

			

				float ao = SampleSSAO(screenUV);

#if _AO_SEPARATE
#	if _AMBIENT_IN_UV2
				ao *= tex2D(_OcclusionMap, i.texcoord1.xy).r;
#	else
				ao *= tex2D(_OcclusionMap, uv).r;
#	endif

#elif _AO_MADS
				ao *= madsMap.g;
#else 
				//ao = 1;
#endif

	

#if _COLOR_R_AMBIENT
				ao *= (0.25 + i.color.r * 0.75);
#endif

				float4 tex = tex2D(_MainTex, uv);

				float water = 0;

#				if _DAMAGED

					//float noise = tex2D(_MainTex, uv * 4.56).r;

					float damDepth = mask.g *3 - noise - displacement;
					float damAlpha = smoothstep(0, 0.5, damDepth);
					float damAlpha2 = smoothstep(1, 1.5, damDepth);

					mask.r += damAlpha2;

					//float2 offset = _Damage_Tex.xy;
					float2 damPix = _Damage_Tex_TexelSize.xy;
					float4 maskY = tex2D(_Damage_Tex, damUv + float2(0, damPix.y));
					float4 maskX = tex2D(_Damage_Tex, damUv + float2(damPix.x, 0));
					float3 damBump = normalize(float3(maskX.g - mask.g, maskY.g - mask.g, 0.1));

					float2 terUv = uv * 1.9;
					float4 dam = tex2D(_DamDiffuse, terUv);
				//	float4 dam2 = tex2D(_DamDiffuse2, terUv * 0.3);



				//	dam = lerp(dam, dam2, damAlpha2);
					tnormal = lerp(tnormal, damBump, damAlpha);

					float damHole = smoothstep(4, 0, damDepth);

					tex = lerp(tex, dam, damAlpha);

#				if _USE_IMPACT

					//float toBlood = smoothstep(0, 0.5, _ImpactDisintegration);

				

					//tex = lerp(tex, _qc_BloodColor * dam, toBlood);
						//tex = lerp(tex, _qc_BloodColor, _GorificationForce);

					//madsMap = lerp(madsMap, float4(1,1,1,1), toBlood);

#endif

					ApplyBlood(mask, water, tex.rgb, madsMap, displacement);

#				endif


				ApplyTangent(normal, tnormal, i.wTangent);


				// SDF Ambient

			/*	float outsideVolume;
				float4 scene = SampleSDF(i.worldPos , outsideVolume);

				float toSurface = saturate(dot(scene.xyz, -normal));

			

				ao *= 1 - toSurface * (1-outsideVolume) * saturate(1-scene.a);*/ //lerp(toSurface, 1, oobSDF);




					float shadow = SHADOW_ATTENUATION(i);
				// ********************** WATER


#if _qc_USE_RAIN || _DAMAGED

				float rain = GetRain(i.worldPos, normal, i.normal, shadow); //float GetRain(float3 worldPos, float3 normal, float3 rawNormal, float shadow)

				float4 rainNoise = GetRainNoise(i.worldPos, displacement, normal.y, rain);

				float flattenWater = ApplyWater(water, rain, ao, displacement, madsMap, rainNoise);

				normal = lerp(normal, i.normal.xyz, flattenWater);
				// normal = i.normal.xyz;
				// ApplyTangent(normal, tnormal, i.wTangent);
#endif


    float3 worldPosAdjusted = i.worldPos;



				// **************** light

				float metal = madsMap.r;
				float fresnel = 1 - saturate(dot(normal, viewDir)); 
				float specular = GetSpecular(madsMap.a, fresnel, metal);

			

				float3 lightColor = Savage_GetDirectional_Opaque(shadow, ao, normal, i.worldPos);

				float3 volumeSamplePosition;
				float3 bake = Savage_GetVolumeBake(worldPosAdjusted, normal, i.normal, volumeSamplePosition);

				TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
				float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, i.worldPos);
				ao *= topDownAmbient.a;
				bake.rgb += topDownAmbient.rgb;

				ModifyColorByWetness(tex.rgb, water, madsMap.a);


				float3 reflectionColor = 0;
				float3 pointLight = GetPointLight(volumeSamplePosition, normal, ao, viewDir, specular, reflectionColor);


				float3 col = tex.rgb * (pointLight + lightColor + bake * ao);

				//return water; // float4(col, 1);

#if RT_FROM_CUBEMAP || _SUB_SURFACE

				float3 reflectedRay = reflect(-viewDir, i.normal.xyz);

				float4 topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, i.worldPos, i.normal.xyz, specular);
				ao *= topDownAmbientSpec.a;
				reflectionColor += topDownAmbientSpec.rgb;

				reflectionColor += GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular, i.traced);
				reflectionColor *= ao;

				reflectionColor += GetDirectionalSpecular(normal, viewDir, specular * 0.9) * lightColor;

				MixInSpecular(col, reflectionColor, tex, metal, specular, fresnel);


#				if _SUB_SURFACE
				float4 skin = tex2D(_SkinMask, i.texcoord.xy) * _SubSurface;

				ApplySubSurface(col, skin, volumeSamplePosition, viewDir, specular, rawFresnel, shadow);


#				endif

#endif

				//	return float4(col, 1);
				
				#if _USE_IMPACT
					AddSubSurface(col, mask, i.impact.y);
				#endif

				ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

				return float4(col,1);

			}
			ENDCG
		}

		Pass
		{
			Cull Front

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"
			//fixed4 _MainColor;
			sampler2D _Damage_Tex;
			sampler2D _DamDiffuse;
			#include "AutoLight.cginc"

			struct v2f
			{
				float4 pos			: SV_POSITION;
				float2 uv:TEXCOORD0;
				float2 texcoord1 : TEXCOORD1;
			//	#if _USE_IMPACT
					float2 impact : TEXCOORD2;
					float3 worldPos		: TEXCOORD3;
					SHADOW_COORDS(4)
			//	#endif
				float3 viewDir		: TEXCOORD5;
				float3 normal		: TEXCOORD6;

				float4 traced : TEXCOORD7;

			};

			v2f vert(appdata_full v)
			{
				v2f o;

				o.uv = v.texcoord;
				UNITY_SETUP_INSTANCE_ID(v);
				float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
				o.texcoord1 = v.texcoord1;

				o.worldPos = worldPos;

				o.normal = UnityObjectToWorldNormal(v.normal);


				v.vertex = mul(unity_WorldToObject, float4(DeformVertex(worldPos, o.normal, o.impact.x), v.vertex.w));

				o.impact.y = LightUpAmount(worldPos);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.viewDir = WorldSpaceViewDir(v.vertex);
				o.normal = -o.normal;

				o.traced = GetTraced_Mirror_Vert(worldPos, normalize(o.viewDir.xyz), o.normal.xyz);

				TRANSFER_SHADOW(o);

				return o;
			}

			sampler2D _SkinMask;

			float4 frag(v2f i) : SV_Target
			{

				float2 damUv = i.texcoord1.xy;
				float4 mask = tex2D(_Damage_Tex, damUv);

				float3 viewDir = normalize(i.viewDir.xyz);

				// R - Blood
				// G - Damage

				float3 tex =1;

				#if _USE_IMPACT

					float disintegrate = GetDisintegration(i.worldPos, mask, i.impact.x);


				//	tex = lerp(tex, 4, smoothstep(0.01, 0, disintegrate));

					clip(disintegrate);
				#endif
					 
				tex *= tex2D(_DamDiffuse, i.uv).rgb;

				

				float3 normal = i.normal;

				float ao = _ImpactDisintegration;

				float specular = 0.75 + _ImpactDisintegration * 0.2;

				float shadow = SHADOW_ATTENUATION(o); // *SampleSkyShadow(i.worldPos);

				float3 lightColor = Savage_GetDirectional_Opaque(shadow, ao, normal, i.worldPos);
					
				float3 volumeSamplePosition;
				float3 bake = Savage_GetVolumeBake(i.worldPos, normal, i.normal, volumeSamplePosition);

				TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
				float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, i.worldPos);
				ao *= topDownAmbient.a;
				bake += topDownAmbient.rgb;


				//tex *= _qc_BloodColor.rgb; // , fresnel);

				AddSubSurface(tex, mask, i.impact.y);

			

				float metal = 1;
				float water = 1;
				float fresnel =  saturate(1- dot(viewDir, normal));
				ModifyColorByWetness(tex.rgb, water, specular);

				float3 reflectionColor = 0;

				float3 pointLight = GetPointLight(volumeSamplePosition, normal, ao, viewDir, specular, reflectionColor);


				float3 col = tex * (pointLight + lightColor + bake*ao); 



					

	// *********************  Reflections

					float3 reflectedRay = reflect(-viewDir, normal);

					

					float4 topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, i.worldPos, i.normal.xyz, specular);
					ao *= topDownAmbientSpec.a;
					reflectionColor += topDownAmbientSpec.rgb;

					reflectionColor.rgb += GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular, i.traced);
					reflectionColor *= ao;

					reflectionColor += GetDirectionalSpecular(normal, viewDir, specular * 0.95) * lightColor;


				///	return float4(reflectionColor,1);

					MixInSpecular(col, reflectionColor, tex, metal, specular, fresnel);


#				if _SUB_SURFACE

				float4 skin = tex2D(_SkinMask, i.uv) * _SubSurface;

			//	return skin;

				ApplySubSurface(col, skin, volumeSamplePosition, viewDir, specular, fresnel, shadow);


#				endif


				ApplyBottomFog(col.rgb, i.worldPos.xyz, i.viewDir.y);

				return float4(col,1);
			}
			ENDCG
		}

		Pass
		{

			// Furry
			Tags
			{
				"LightMode" = "ForwardBase"
				"Queue" = "Transparent"
				"PreviewType" = "Plane"
				"IgnoreProjector" = "True"
				"RenderType" = "Transparent"
			}

			ZWrite Off
			Cull Front
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			
		

			sampler2D _Damage_Tex;



			struct v2f
			{
				float4 pos			: SV_POSITION;
				float2 uv:TEXCOORD0;
				float2 texcoord1 : TEXCOORD1;
				float2 impact : TEXCOORD2;
				float3 worldPos		: TEXCOORD3;
				SHADOW_COORDS(4)
				float3 viewDir		: TEXCOORD5;
				float3 normal		: TEXCOORD6;
				float4 screenPos : TEXCOORD7;
			};

			v2f vert(appdata_full v)
			{
				v2f o;

				o.uv = v.texcoord;
				UNITY_SETUP_INSTANCE_ID(v);
				float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
				o.texcoord1 = v.texcoord1;
				o.worldPos = worldPos;
				o.normal = UnityObjectToWorldNormal(v.normal);

				float toCum = (0.5 + smoothstep(0,10, length(_WorldSpaceCameraPos - o.worldPos)))*0.04;


				v.vertex = mul(unity_WorldToObject, float4(DeformVertex(worldPos, o.normal, o.impact.x) + o.normal*toCum, v.vertex.w));

				o.impact.y = LightUpAmount(worldPos);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.viewDir = WorldSpaceViewDir(v.vertex);
					o.screenPos = ComputeScreenPos(o.pos); 
					  COMPUTE_EYEDEPTH(o.screenPos.z);
				TRANSFER_SHADOW(o);

				return o;
			}

			sampler2D _SkinMask;
			sampler2D	_Overlay;
			float _OverlayTiling;

			float4 frag(v2f i) : SV_Target
			{

				i.normal = normalize(i.normal);

				float2 damUv = i.texcoord1.xy;
				float4 mask = tex2D(_Damage_Tex, damUv);

				#if _USE_IMPACT
					float disintegrate = GetDisintegration(i.worldPos, mask, i.impact.x);
					clip(disintegrate);
				#endif
					 
				float4 col = tex2D(_Overlay, i.uv * float2(1, 0.1) * _OverlayTiling);

				float3 viewDir = normalize(i.viewDir.xyz);
				float2 screenUV = i.screenPos.xy / i.screenPos.w;

				float3 normal = -viewDir;

				float fresnel =  saturate(dot(-viewDir, i.normal));
			
			    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
			    float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
			    float fade = smoothstep(2 ,3, (sceneZ - i.screenPos.z));
				col.a =  smoothstep(0.4,1, col.a * fresnel * fade);

				float shadow = GetShadowVolumetric(i.worldPos, i.screenPos.z, viewDir);  

				col.rgb = TransparentLightStandard(col, i.worldPos, normal, viewDir, shadow);

               

		
				ApplyBottomFog(col.rgb, i.worldPos.xyz, viewDir.y);

				

				return col;
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

			struct v2f {

				#if _USE_IMPACT
					float2 impact : TEXCOORD0;
					float3 worldPos		: TEXCOORD1;
				#endif
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
#if _USE_IMPACT



				//float3 vec = _ImpactPosition.xyz - worldPos;
				//float dist = length(vec);// *(0.9 + abs(sdGyroid(worldPos * 3, 0.1)) * 0.1);
				//float deformationAmount = smoothstep(_ImpactDeformation * 6, 0, dist) + min(_ImpactDeformation, _ImpactDeformation / (dist + 0.01));
				//float bulge = deformationAmount * (1 + sdGyroid(worldPos * 5, 1)) * 0.5;

				float3 normal = UnityObjectToWorldNormal(v.normal);

				v.vertex = mul(unity_WorldToObject, float4(DeformVertex(worldPos, normal,  o.impact.x), v.vertex.w));//mul(unity_WorldToObject, float4(worldPos.xyz - normalize(vec) * smoothstep(0, 1, bulge * _ImpactDeformation * 2), v.vertex.w));
				//o.impact = deformationAmount;
				o.impact.y = 0;
				o.worldPos = worldPos;
#endif

				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)

				return o;
			}

			sampler2D _Damage_Tex;


			float4 frag(v2f o) : SV_Target
			{
				float2 damUv = o.texcoord1.xy;

			

				float4 mask = tex2D(_Damage_Tex, damUv);

				// R - Blood
				// G - Damage
			

				#if _USE_IMPACT
					clip(GetDisintegration(o.worldPos, mask, o.impact.x));
				#endif

					

				SHADOW_CASTER_FRAGMENT(o)
			}
			ENDCG
		}

	}
	Fallback "Diffuse"
	
}