Shader "RayTracing/Terrain/Blanket"
{
Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}

		[KeywordEnum(Nonmetal, Metal, Glass)] _SURFACE("Surface", Float) = 0

		[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_BumpMap("Bump/Combined Map (or None)", 2D) = "gray" {}
	}

Category
	{
		SubShader
		{

				CGINCLUDE

				#include "Assets/Ray-Marching/Shaders/Savage_Sampler.cginc"
				//#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
				//#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
				//#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"
				#include "Assets\The-Fire-Below\Common\Shaders\qc_terrain_cg.cginc"

				float3 ModifyPosition(float3 worldPos)
				{
					float3 terrainUV = WORLD_POS_TO_TERRAIN_UV_3D(worldPos.xyz);
					float4 terrain = tex2Dlod(_qcPp_mergeTerrainHeight, float4(terrainUV.xz,0,0));
					worldPos.y = _qcPp_mergeTeraPosition.y + terrain.a * _qcPp_mergeTerrainScale.y+ 0.5f + abs(worldPos.y*0.01) ;
					return worldPos;
				}
				ENDCG

			Pass
			{
				Tags
				{
					"Queue" = "AlphaTest"
					"RenderType" = "Opaque"
					"LightMode" = "ForwardBase"
				}

				ColorMask RGBA
				Cull Off

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma shader_feature_local _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 
				#pragma shader_feature_local _SURFACE_NONMETAL _SURFACE_METAL _SURFACE_GLASS  
				#pragma multi_compile ___ QC_MERGING_TERRAIN

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

#if QC_MERGING_TERRAIN
					worldPos.xyz = ModifyPosition(worldPos.xyz);

					v.vertex = mul(unity_WorldToObject, float4(worldPos.xyz, v.vertex.w));
#endif

					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.texcoord1 = v.texcoord1;
					o.worldPos = worldPos;
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);

					TRANSFER_WTANGENT(o)
					TRANSFER_TOP_DOWN(o);
					TRANSFER_SHADOW(o);

					return o;
				}


				float4 frag(v2f o) : COLOR
				{
					float3 viewDir = normalize(o.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, o.normal.xyz));

					
					float2 uv = o.texcoord.xy;

					float4 bumpMap;
					float3 tnormal;
					SampleBumpMap(_BumpMap, bumpMap, tnormal, uv);

					uv -= tnormal.rg  *  _MainTex_TexelSize.xy;

					float4 tex = tex2D(_MainTex, uv);// * o.color;

					clip(tex.a - 0.5);
				
					ColorCorrect(tex.rgb);

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

						1;
					#endif

					float shadow = SHADOW_ATTENUATION(o);

					float direct = shadow * smoothstep(1 - ambient, 1.5 - ambient * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));
					
					float3 lightColor = GetDirectional() * direct;

					// LIGHTING

					#if _SURFACE_NONMETAL  

					float3 volumePos = o.worldPos + normal
						* lerp(0.5, 1 - fresnel, smoothness) * 0.5
						* _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

					float outOfBounds;
					float4 bakeRaw = SampleVolume(volumePos, outOfBounds);

		
					float3 avaragedAmbient = GetAvarageAmbient(normal);
					bakeRaw.rgb = lerp(bakeRaw.rgb, avaragedAmbient, outOfBounds); // Up 

					float4 bake = bakeRaw;

					ApplyTopDownLightAndShadow(o.topdownUv,  normal,  bumpMap,  o.worldPos,  1- outOfBounds, fresnel, bake);

					float3 col = lightColor 
					+ bake.rgb * ambient;
					
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

				float showReflected = 1 - fresnel;

				float3 col;

				col = lerp (bakeStraight,
				bakeReflected , showReflected);
#				endif


					ApplyBottomFog(col, o.worldPos.xyz, viewDir.y);

					return float4(col,1);

				}
				ENDCG
			}


			  Pass 
			  {
				Name "Caster"
				Tags { "LightMode" = "ShadowCaster" }

				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma target 2.0
				#pragma multi_compile_shadowcaster
				#pragma multi_compile_instancing // allow instanced shadow pass for most of the shaders
				#include "UnityCG.cginc"

				struct v2f 
				{
					V2F_SHADOW_CASTER;
					float2  uv : TEXCOORD1;
					UNITY_VERTEX_OUTPUT_STEREO
				};


				uniform sampler2D _MainTex;
				float4 _MainTex_ST;

				v2f vert( appdata_base v )
				{
					v2f o;

						float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));


#if QC_MERGING_TERRAIN
					worldPos.xyz = ModifyPosition(worldPos.xyz);
					v.vertex = mul(unity_WorldToObject, float4(worldPos.xyz, v.vertex.w));
#endif


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