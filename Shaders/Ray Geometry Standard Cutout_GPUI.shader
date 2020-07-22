Shader "GPUInstancer/RayTracing/Geometry/Standard Cutout"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}

		[KeywordEnum(Nonmetal, Metal, Glass)] _SURFACE("Surface", Float) = 0

		[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_BumpMap("Bump/Combined Map (or None)", 2D) = "gray" {}
	
		[Toggle(_AMBIENT)] useAmbient("Use Ambient Map", Float) = 0
		_Ambient("Ambient Map", 2D) = "white" {}

		[Toggle(_SHOWUVTWO)] thisDoesntMatter("Debug Uv 2", Float) = 0

		[Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
		_SubSurface("Sub Surface Color", Color) = (1,0.5,0,0)
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

				#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
				#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
				#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
				#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"



				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fwdbase
				#pragma shader_feature_local _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 
				#pragma shader_feature_local _SURFACE_NONMETAL _SURFACE_METAL _SURFACE_GLASS  

				#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON

				#pragma shader_feature_local ___ _SUB_SURFACE
				#pragma shader_feature_local ___ _AMBIENT
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

					float2 topdownUv : TEXCOORD7;
					float2 lightMapUv : TEXCOORD8;
					fixed4 color : COLOR;
				};

				sampler2D _MainTex_ATL_UvTwo;
				float4 _MainTex_ATL_UvTwo_TexelSize;

				sampler2D _MainTex;
				#if _AMBIENT
				sampler2D _Ambient;
				#endif
				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				sampler2D _Bump;
				sampler2D _SkinMask;
				float4 _SubSurface;

				sampler2D _BumpMap;
				float4 _BumpMap_ST;
				
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


					TRANSFER_WTANGENT(o)
					TRANSFER_TOP_DOWN(o);
					TRANSFER_SHADOW(o);

					return o;
				}


				float4 frag(v2f o) : COLOR
				{


					#if _qc_Rtx_MOBILE

						float4 mobTex = tex2D(_MainTex, o.texcoord);

						clip(mobTex.a - 0.5);

						ColorCorrect(mobTex.rgb);

						#if LIGHTMAP_ON
							mobTex.rgb *= DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, o.lightMapUv));
						#else 

							float oobMob;
							mobTex.rgb *= SampleVolume(o.worldPos, oobMob).rgb;

						#endif

						return mobTex;

					#endif

					float3 viewDir = normalize(o.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, o.normal.xyz));

					
					float2 uv = o.texcoord.xy;

					float4 bumpMap;
					float3 tnormal;
					SampleBumpMap(_BumpMap, bumpMap, tnormal, uv);

					uv -= tnormal.rg  *  _MainTex_TexelSize.xy;

					float4 tex = tex2D(_MainTex, uv);// * o.color;

					clip(tex.a - 0.5);
				
					float3 normal = o.normal.xyz;

					ApplyTangent(normal, tnormal, o.wTangent);

					float fresnel = saturate(dot(normal,viewDir));

					//return fresnel;

					float smoothness = 
					#if _BUMP_COMBINED
					bumpMap.b;
					#else 
					0.1;
					#endif

					float ambient = 
					#if _BUMP_COMBINED
					 bumpMap.a;
					#else 

					#if _AMBIENT
						tex2D(_Ambient, uv).r;// * o.color;
					#else 
						1;
					#endif
					#endif

					float shadow = SHADOW_ATTENUATION(o);

					float direct = shadow * smoothstep(1 - ambient, 1.5 - ambient * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));
					
					float3 lightColor = GetDirectional() * direct;

					// LIGHTING

					#if _SURFACE_NONMETAL  


					float4 normalAndDist = SdfNormalAndDistance(o.worldPos);
					
					float3 volumePos = o.worldPos + (normal + normalAndDist.xyz * saturate(normalAndDist.w)) 
						* lerp(0.5, 1 - fresnel, smoothness) * 0.5
						* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

					float outOfBounds;
					float4 bakeRaw = SampleVolume(volumePos, outOfBounds);

					float gotVolume = bakeRaw.a * (1- outOfBounds);
					outOfBounds = 1 - gotVolume;
					float3 avaragedAmbient = GetAvarageAmbient(normal);
					bakeRaw.rgb = lerp(bakeRaw.rgb, avaragedAmbient, outOfBounds); // Up 

					float4 bake = bakeRaw;

					ApplyTopDownLightAndShadow(o.topdownUv,  normal,  bumpMap,  o.worldPos,  gotVolume, fresnel, bake);

#					if _SUB_SURFACE

					float2 damUv = o.texcoord1.xy;
					float4 mask = tex2D(_MainTex_ATL_UvTwo, damUv);

					float skin = tex2D(_SkinMask, damUv);
					float subSurface = _SubSurface.a * skin * (1-mask.g)  * (1+rawFresnel) * 0.5;
#					endif

					float3 col = lightColor * (1 + outOfBounds) 
						+ bake.rgb * ambient
						;
					
					ColorCorrect(tex.rgb);

					col.rgb *=tex.rgb;

					AddGlossToCol(lightColor);

			
#					if _SUB_SURFACE
					col *= 1-subSurface;
					TopDownSample(o.worldPos, bakeRaw.rgb, outOfBounds);
					col.rgb += subSurface * _SubSurface.rgb * (_LightColor0.rgb * shadow + bakeRaw.rgb);
#					endif

#			elif _SURFACE_METAL

			
				float3 reflectionPos;
				float outOfBoundsRefl;
				float3 bakeReflected = SampleReflection(o.worldPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);

				TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);

				ColorCorrect(tex.rgb);
				float3 col =  tex.rgb * bakeReflected;

#			elif _SURFACE_GLASS


				float3 reflectionPos;
				float outOfBoundsRefl;
				float3 bakeReflected = SampleReflection(o.worldPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);

				TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);

				float outOfBounds;
				float3 straightHit;
				float3 bakeStraight = SampleRay(o.worldPos, normalize(-viewDir - normal*0.5), shadow, straightHit, outOfBounds );

				TopDownSample(straightHit, bakeStraight, outOfBounds);

			//	return fresnel;

				float showReflected = 1 - fresnel;

				float3 col;

				col = lerp (bakeStraight,
				bakeReflected , showReflected);

			//	col.r = lerp(bakeStraight.r, bakeReflected.r, pow(showReflected,3));
			//	col.g = lerp(bakeStraight.g, bakeReflected.g, showReflected * showReflected);
			//	col.b = lerp(bakeStraight.b, bakeReflected.b, pow(showReflected,0.5));
#				endif


					ApplyBottomFog(col, o.worldPos.xyz, viewDir.y);

					return float4(col,1);

				}
				ENDCG
			}


			  Pass {
        Name "Caster"
        Tags { "LightMode" = "ShadowCaster" }
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
#include "UnityCG.cginc"

struct v2f {
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
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
    TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    return o;
}

uniform fixed _Cutoff;
uniform fixed4 _Color;

float4 frag( v2f i ) : SV_Target
{
    fixed4 texcol = tex2D( _MainTex, i.uv );
    clip( texcol.a - 0.5 );

    SHADOW_CASTER_FRAGMENT(i)
}
ENDCG

    }

		}
		Fallback "Diffuse"
	}
}
