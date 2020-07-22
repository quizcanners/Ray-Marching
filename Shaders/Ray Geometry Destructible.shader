Shader "RayTracing/Geometry/Destructible"
{
	Properties
	{
		[NoScaleOffset] _MainTex_ATL_UvTwo("_Main DAMAGE (_UV2) (_ATL) (RGB)", 2D) = "black" {}
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_Map("Bump/Combined Map (or None)", 2D) = "gray" {}
		
		_DamDiffuse("Damaged Diffuse", 2D) = "white" {}
		[NoScaleOffset]_BumpD("Bump Damage", 2D) = "gray" {}

		_DamDiffuse2("Damaged Diffuse Deep", 2D) = "white" {}
		[NoScaleOffset]_BumpD2("Bump Damage 2", 2D) = "gray" {}

		_BloodPattern("Blood Pattern", 2D) = "gray" {}

		[Toggle(_DAMAGED)] isDamaged("_DAMAGED", Float) = 0
	}


	SubShader
	{
		CGINCLUDE

		#pragma shader_feature_local ___ _DAMAGED


		#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
		#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
		#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
		#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"

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
			#pragma multi_compile_fwdbase

			#pragma shader_feature_local _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 

			#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
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

				float2 topdownUv : TEXCOORD8;
				float2 lightMapUv : TEXCOORD9;
				fixed4 color : COLOR;
			};

			sampler2D _MainTex_ATL_UvTwo;
			float4 _MainTex_ATL_UvTwo_TexelSize;

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;
			sampler2D _Bump;

#				if _DAMAGED
				sampler2D _DamDiffuse;
				float4 _DamDiffuse_TexelSize;

				sampler2D _DamDiffuse2;
				float4 _DamDiffuse2_TexelSize;

				sampler2D _BumpD;
				sampler2D _BumpD2;
#				endif
				
			sampler2D _Map;
			float4 _Map_ST;
		
	

			v2f vert(appdata_full v) 
			{
				v2f o;
				//UNITY_SETUP_INSTANCE_ID(v);

				float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

				o.normal.xyz = UnityObjectToWorldNormal(v.normal);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.texcoord1 = v.texcoord1;
				 o.lightMapUv = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;

				o.worldPos = worldPos;
				
				o.color = v.color;
				o.viewDir = WorldSpaceViewDir(v.vertex);

				TRANSFER_WTANGENT(o)
				TRANSFER_TOP_DOWN(o);
				TRANSFER_SHADOW(o);

				return o;
			}

			
			// sampler2D unity_Lightmap;
			// float4 unity_LightmapST;


			sampler2D _BloodPattern;
			float4 _qc_BloodColor;

			float4 frag(v2f o) : COLOR
			{
			
			
				float2 uv = o.texcoord.xy;

#				if _DAMAGED
				float2 damUv = o.texcoord1.xy;
				float4 mask = tex2D(_MainTex_ATL_UvTwo, damUv);
#endif


				#if _qc_Rtx_MOBILE

				float4 mobTex = tex2D(_MainTex, uv);

				ColorCorrect(mobTex.rgb);

					#if LIGHTMAP_ON
						mobTex.rgb *= DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
					#else 

						float oobMob;
						mobTex.rgb *= SampleVolume(o.worldPos, oobMob).rgb;

					#endif

#if _DAMAGED
						mobTex *= (1- mask.g);
						mobTex = lerp(mobTex, _qc_BloodColor, mask.r);
#endif

					return mobTex;

				#endif


				o.viewDir.xyz = normalize(o.viewDir.xyz);



				// R - Blood
				// G - Damage

				float rawFresnel = smoothstep(1,0, dot(o.viewDir.xyz, o.normal.xyz));
		

				// Get Layers					
			

				float4 bumpMap;
				float3 tnormal;
				SampleBumpMap(_Map, bumpMap, tnormal, uv);
				float4 tex = tex2D(_MainTex, uv - tnormal.rg  * _MainTex_TexelSize.xy) * o.color;

#				if _DAMAGED
					float2 terUv = uv*1.9;

					float4 bumpd;
					float3 tnormald;
					SampleBumpMap(_BumpD, bumpd, tnormald, terUv);
					float4 dam = tex2D(_DamDiffuse, terUv + tnormald.rg  * _DamDiffuse_TexelSize.xy);

					terUv *= 0.3;

					float4 bumpd2;
					float3 tnormald2;
					SampleBumpMap(_BumpD2, bumpd2, tnormald2, terUv);
					float4 dam2 = tex2D(_DamDiffuse2, terUv + tnormald2.rg  * _DamDiffuse2_TexelSize.xy);

					float2 offset = _MainTex_ATL_UvTwo_TexelSize.xy * 0.33;

					float maskUp = tex2D(_MainTex_ATL_UvTwo, float2(damUv.x, damUv.y + offset.y)).r - mask.g;
					float maskRight = tex2D(_MainTex_ATL_UvTwo, float2(damUv.x + offset.x, damUv.y)).r - mask.g;

					float3 dentNorm = float3(-maskRight, maskUp, 0);

					// MIX LAYERS
					float fw = min(0.2, length(fwidth(uv)) * 100);

					float tHoldDam = (1.01 + bumpd.a - bumpd2.a) * 0.5;
					float damAlpha2 = smoothstep(max(0, tHoldDam  - fw), tHoldDam + fw, mask.g);
					dam = lerp(dam, dam2, damAlpha2);
					bumpd = lerp(bumpd, bumpd2, damAlpha2);

#					if !_BUMP_NONE
						tnormald = lerp(tnormald, tnormald2, damAlpha2);
#					endif

					float tHold = (1.01 - bumpd.a + bumpMap.a) * 0.1;
					float damAlpha = smoothstep(max(0, tHold - fw), tHold + fw, mask.g);

					tex = lerp(tex, dam, damAlpha);
					bumpMap = lerp(bumpMap, bumpd, damAlpha);

#					if !_BUMP_NONE
						tnormal = lerp(tnormal, tnormald, damAlpha);
#					endif

					tnormal -= float3(-dentNorm.x, dentNorm.y, 0) * damAlpha;
#				endif

				float3 normal = o.normal.xyz;

				ApplyTangent(normal, tnormal, o.wTangent);

				float fresnel = saturate(dot(normal, o.viewDir.xyz));

				
#				if _DAMAGED

					float showBlood = smoothstep(bumpMap.a*0.5, bumpMap.a, mask.r * (1 + tex2D(_BloodPattern, uv).r)); // bumpMap.a * max(0, normal.y) * (1 - bumpMap.b);

					float showBloodWave = normal.y * showBlood * damAlpha2;

					// BLOODY FLOOR
					float3 bloodGyrPos = o.worldPos.xyz*3 + float3(0,_Time.y - mask.g,0)  ;
					float3 boodNormal = normalize (float3(
						(abs(dot(sin(bloodGyrPos), cos(bloodGyrPos.zxy)))), 1 + (1-mask.r)*4,
						abs(dot(sin(bloodGyrPos.yzx), cos(bloodGyrPos.xzy)))));

					normal = normalize(lerp(normal, boodNormal, smoothstep(0.1,0.4, showBloodWave)));

					float3 bloodColor = _qc_BloodColor.rgb * (1 - mask.r*0.75);

					tex.rgb = lerp(tex.rgb, bloodColor, showBlood );
					bumpMap = lerp(bumpMap, float4(0.5, 0.5, 0.8, 0.8), showBloodWave);

#				endif

				float smoothness = bumpMap.b;// lerp(bumpMap.b, 0.8, isBlood);

				// LIGHTING
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

					float3 volumePos = o.worldPos
						+ normal
						* lerp(0.5, 1 - fresnel, smoothness) * 0.5
						* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

					bake = SampleVolume(volumePos, outOfBounds);
					gotVolume = bake.a * (1 - outOfBounds);
					outOfBounds = 1 - gotVolume;

					bake.rgb = lerp(bake.rgb, GetAvarageAmbient(normal), outOfBounds);
				#endif
				
				
				float shadow = SHADOW_ATTENUATION(o) * SampleSkyShadow(o.worldPos);


				ApplyTopDownLightAndShadow(o.topdownUv,  normal,  bumpMap,  o.worldPos,  gotVolume, fresnel, bake);


				float ambient = bumpMap.a * smoothstep(-0.5, 0.25, o.color.a);

				float direct = shadow * smoothstep(1 - ambient, 1.5 - ambient * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));
					
				float3 sunColor = GetDirectional();

				float3 lightColor = sunColor * direct;

				float3 col = bake.rgb * ambient + lightColor;
					
				ColorCorrect(tex.rgb);

				col *= tex.rgb;

				AddGlossToCol(lightColor);

				ApplyBottomFog(col, o.worldPos.xyz, o.viewDir.y);

				return float4(col,1);

			}
			ENDCG
		}


		/*
		 Pass
        {
            Name "META"
            Tags {"LightMode"="Meta"}
            Cull Off
            CGPROGRAM

            #include"UnityStandardMeta.cginc"

            float4 frag_meta2 (v2f_meta i): SV_Target
            {
                // We're interested in diffuse & specular colors
                // and surface roughness to produce final albedo.

                FragmentCommonData data = UNITY_SETUP_BRDF_INPUT (i.uv);
                UnityMetaInput o;
                UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);
                fixed4 c = tex2D (_MainTex, i.uv);
                o.Albedo = fixed3(c.rgb);
                o.Emission = 0; // Emission(i.uv.xy);
                return UnityMetaFragment(o);
            }

            #pragma vertex vert_meta
            #pragma fragment frag_meta2
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature ___ _DETAIL_MULX2
            ENDCG
        }*/

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

			sampler2D _MainTex_ATL_UvTwo;


			float4 frag(v2f o) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(o)
			}
			ENDCG
		}

	}
	Fallback "Diffuse"
	
}