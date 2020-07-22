Shader "RayTracing/Geometry/Destructible Dynamic"
{
	Properties
	{
		[NoScaleOffset] _MainTex_ATL_UvTwo("_Main DAMAGE (_UV2) (_ATL) (RGB)", 2D) = "black" {}
		_Diffuse("Albedo (RGB)", 2D) = "white" {}
		[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_Map("Bump/Combined Map (or None)", 2D) = "gray" {}
		
		_DamDiffuse("Damaged Diffuse", 2D) = "white" {}
		[NoScaleOffset]_BumpD("Bump Damage", 2D) = "gray" {}

		_DamDiffuse2("Damaged Diffuse Deep", 2D) = "white" {}
		[NoScaleOffset]_BumpD2("Bump Damage 2", 2D) = "gray" {}

		_BloodPattern("Blood Pattern", 2D) = "gray" {}

		[Toggle(_USE_IMPACT)] useImpact("_USE_IMPACT", Float) = 0
		[Toggle(_DAMAGED)] isDamaged("_DAMAGED", Float) = 0
		[Toggle(_SHOWUVTWO)] thisDoesntMatter("Debug Uv 2", Float) = 0

		[Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
		_SubSurface("Sub Surface Scattering", Color) = (1,0.5,0,0)
		_SkinMask("Skin Mask (_UV2)", 2D) = "white" {}
	}


	SubShader
	{
		CGINCLUDE

		#pragma shader_feature_local ___ _USE_IMPACT
		#pragma shader_feature_local ___ _DAMAGED
		#pragma shader_feature_local ___ _SUB_SURFACE


		#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
		#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
		#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
		#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"

//#				if	_USE_IMPACT
					float _ImpactDisintegration;
					float _ImpactDeformation;
					float4 _ImpactPosition;
					float4 _qc_BloodColor;
//#				endif

			float4 _SubSurface;


			float3 DeformVertex(float3 worldPos, float3 normal, out float impact)
			{
				float3 vec = _ImpactPosition.xyz - worldPos;
				float dist = length(vec);

				float gyr = abs(sdGyroid(worldPos * 12, 1));

				gyr = pow(gyr, 3);

				float deDist = 1/(1+dist);

				impact = _ImpactDisintegration * (deDist + gyr * 0.5 + smoothstep(_ImpactDeformation, 0, dist)); //*lerp(1.5, 0.75, finalStage));
				
				// + min(_ImpactDeformation, _ImpactDeformation / (dist + 0.01));

				float expansion = smoothstep(0, 1, _ImpactDisintegration * deDist);

				return worldPos.xyz - ((normalize(vec) - normal) * 0.4 * gyr + _ImpactDisintegration * float3(0,6,0)) * expansion;
			}

			
			float GetDisintegration(float3 worldPos, float4 mask, float impact)
			{
				//float gyr = abs(sdGyroid(worldPos * 5, 1));
				float deInt = 1 - _ImpactDisintegration;
				float destruction = smoothstep(deInt, deInt + 0.001 , impact);
				return min(0.01 - destruction, 0.75f - mask.g);
			}

			float LightUpAmount(float3 worldPos)
			{
				float dist = length(_ImpactPosition.xyz - worldPos);
				return _ImpactDeformation //* smoothstep(0.1, 0, _ImpactDisintegration) 
				* smoothstep(0.35, 0, dist);
			}

			void AddSubSurface(inout float3 col, float4 mask, float lightUp)
			{

#				if _DAMAGED && _USE_IMPACT
					float3 litColor = lerp(col * 0.5 + float3(3, 0, 0), float3(2, 1, 0), mask.g*0.5);

					col = lerp(col, litColor, lightUp * mask.g) ;
#				endif


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
			#pragma shader_feature_local ___ _SHOWUVTWO

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

#				if _USE_IMPACT
					float2 impact : TEXCOORD7;
#				endif

				float2 topdownUv : TEXCOORD8;
				fixed4 color : COLOR;
			};

			sampler2D _MainTex_ATL_UvTwo;
			float4 _MainTex_ATL_UvTwo_TexelSize;

			sampler2D _Diffuse;
			sampler2D _SkinMask;
			float4 _Diffuse_ST;
			float4 _Diffuse_TexelSize;
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
				UNITY_SETUP_INSTANCE_ID(v);

				float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

				o.normal.xyz = UnityObjectToWorldNormal(v.normal);

#				if _USE_IMPACT
					v.vertex = mul(unity_WorldToObject, float4(DeformVertex(worldPos,o.normal.xyz,  o.impact.x), v.vertex.w));
					o.impact.y = LightUpAmount(worldPos);
#				endif

				o.pos = UnityObjectToClipPos(v.vertex);
				o.texcoord = TRANSFORM_TEX(v.texcoord, _Diffuse);
				o.texcoord1 = v.texcoord1;
				o.worldPos = worldPos;
				
				o.color = v.color;
				o.viewDir = WorldSpaceViewDir(v.vertex);

				TRANSFER_WTANGENT(o)
				TRANSFER_TOP_DOWN(o);
				TRANSFER_SHADOW(o);

				return o;
			}

			
			sampler2D _BloodPattern;

			float4 frag(v2f o) : COLOR
			{

				o.viewDir.xyz = normalize(o.viewDir.xyz);
				float2 damUv = o.texcoord1.xy;
				float4 mask = tex2D(_MainTex_ATL_UvTwo, damUv);
			

				// R - Blood
				// G - Damage

				float rawFresnel = smoothstep(1,0, dot(o.viewDir.xyz, o.normal.xyz));

#				if _USE_IMPACT
					//float gyr = sdGyroid(o.worldPos * 20, 0.2);
					float deInt = 1 - _ImpactDisintegration;

					float redness = smoothstep( deInt * 0.75, deInt, o.impact.x);
					mask.g = lerp(mask.g, 1, redness);
					//float destruction = smoothstep(deInt, deInt + 0.001 + gyr , o.impact );

					//clip(min(0.01 - destruction, 0.9f - mask.g));

					clip(GetDisintegration(o.worldPos, mask, o.impact.x));
#				endif

			

				// Get Layers					
				float2 uv = o.texcoord.xy;

				float4 bumpMap;
				float3 tnormal;
				SampleBumpMap(_Map, bumpMap, tnormal, uv);
				float4 tex = tex2D(_Diffuse, uv - tnormal.rg  * _Diffuse_TexelSize.xy) * o.color;

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

#				endif

				// BUMP
				
#				if _SHOWUVTWO
					float2 pixelEdge = (_MainTex_ATL_UvTwo_TexelSize.zw * damUv);
					float dist = length(o.worldPos.xyz - _WorldSpaceCameraPos.xyz);
					float2 awpos = abs(pixelEdge);
					float2 iwpos = floor(awpos);
					float2 smooth = abs(awpos - iwpos - 0.5);
					float smoothingEdge = max(smooth.x, smooth.y);
					int ind = (iwpos.x + iwpos.y);
					int op = ind * 0.5f;
					float fade = op * 
						_MainTex_ATL_UvTwo_TexelSize.w * 0.03;
					smoothingEdge = smoothstep( 0, fade, 0.5 - smoothingEdge);
					float4 val = (0.25 + mask) * 0.5  + float4(lerp(0.25, abs(ind - op * 2) * 0.5, smoothingEdge), damUv.x, damUv.y, 0);
					return  val;
#				endif

				float3 normal = o.normal.xyz;

#				if _DAMAGED
					tnormal -= float3(-dentNorm.x, dentNorm.y, 0) * damAlpha;
#				endif

				ApplyTangent(normal, tnormal, o.wTangent);

				float fresnel = saturate(dot(normal, o.viewDir.xyz));

#				if _DAMAGED

					float showBlood = smoothstep(bumpMap.a*0.5, bumpMap.a, mask.r * (1 + tex2D(_BloodPattern, uv).r)); // bumpMap.a * max(0, normal.y) * (1 - bumpMap.b);

					float showBloodWave = normal.y * showBlood * damAlpha2;

					// BLOODY FLOOR
					float3 bloodGyrPos = o.worldPos.xyz*3 + float3(0,_Time.y - mask.g,0)  ;
					//abs(dot(sin(pos), cos(pos.zxy)))
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

				float3 volumePos = o.worldPos 
				+ normal 
					* lerp(0.5, 1 - fresnel, smoothness) * 0.5
					* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

				float outOfBounds;
				float4 bakeRaw = SampleVolume(volumePos, outOfBounds);

				float gotVolume = bakeRaw.a * (1- outOfBounds);
				outOfBounds = 1 - gotVolume;
				float3 avaragedAmbient = GetAvarageAmbient(normal);
				bakeRaw.rgb = lerp(bakeRaw.rgb, avaragedAmbient, outOfBounds); // Up 

				float4 bake = bakeRaw;

				float shadow = SHADOW_ATTENUATION(o) * SampleSkyShadow(o.worldPos);

				ApplyTopDownLightAndShadow(o.topdownUv,  normal,  bumpMap,  o.worldPos,  gotVolume, fresnel, bake);

		

				float ambient = bumpMap.a * smoothstep(-0.5, 0.25, o.color.a);

				// Mix Reflected and direct

				float direct = shadow * smoothstep(1 - ambient, 1.5 - ambient * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));
					
				float3 sunColor =  GetDirectional();

				float3 lightColor =sunColor * direct;



				float3 col = lightColor * (1 + outOfBounds) + bake.rgb * ambient;
					
				ColorCorrect(tex.rgb);

				col *=tex.rgb;

				AddGlossToCol(lightColor);

#				if _SUB_SURFACE
					float skin = tex2D(_SkinMask, damUv);
					float subSurface = _SubSurface.a * skin * (1-mask.g) * (1+rawFresnel) * 0.5;
					col *= 1-subSurface;
					TopDownSample(o.worldPos, bakeRaw.rgb, outOfBounds);
					col.rgb += subSurface * _SubSurface.rgb * (sunColor * shadow + bakeRaw.rgb);
					mask *= skin;
				#endif

				#if _USE_IMPACT
					AddSubSurface(col, mask, o.impact.y);
				#endif

				ApplyBottomFog(col, o.worldPos.xyz, o.viewDir.y);

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
			fixed4 _MainColor;
			sampler2D _MainTex_ATL_UvTwo;
			sampler2D _DamDiffuse;


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
			};

			v2f vert(appdata_full v)
			{
				v2f o;

				o.uv = v.texcoord;
				UNITY_SETUP_INSTANCE_ID(v);
				float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
				o.texcoord1 = v.texcoord1;

				o.worldPos = worldPos;

				float3 normal = UnityObjectToWorldNormal(v.normal);

				v.vertex = mul(unity_WorldToObject, float4(DeformVertex(worldPos, normal,  o.impact.x), v.vertex.w));

				o.impact.y = LightUpAmount(worldPos);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.viewDir = WorldSpaceViewDir(v.vertex);
				TRANSFER_SHADOW(o);

				return o;
			}

			fixed4 frag(v2f o) : SV_Target
			{

				float2 damUv = o.texcoord1.xy;
				float4 mask = tex2D(_MainTex_ATL_UvTwo, damUv);

				// R - Blood
				// G - Damage

				float4 col =1;

				#if _USE_IMPACT

					float disintegrate = GetDisintegration(o.worldPos, mask, o.impact.x);


					col = lerp(col, 4, smoothstep(0.01, 0, disintegrate));

					clip(disintegrate);
				#endif

				float shadow = SHADOW_ATTENUATION(o) * SampleSkyShadow(o.worldPos);

				PrimitiveLight(lightColor, ambientCol, outOfBounds, o.worldPos, float3(0,-1,0));
				TopDownSample(o.worldPos, ambientCol, outOfBounds);

				
				col.rgb *= (ambientCol + lightColor * shadow);

				col.rgb *= tex2D(_DamDiffuse, o.uv);

				AddSubSurface(col.rgb, mask, o.impact.y);

				ApplyBottomFog(col.rgb, o.worldPos.xyz, o.viewDir.y);

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

			sampler2D _MainTex_ATL_UvTwo;


			float4 frag(v2f o) : SV_Target
			{
				float2 damUv = o.texcoord1.xy;
				float4 mask = tex2D(_MainTex_ATL_UvTwo, damUv);

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