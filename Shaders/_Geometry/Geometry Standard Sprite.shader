Shader "QcRendering/Geometry/Standard Sprite"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "clear" {}
		_BumpMap("Normal Map", 2D) = "bump" {}
		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "white" {}
		[HDR] _SubSurface("Sub Surface Color", Color) = (1,0.5,0,0)
		[Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
		_SkinMask("Skin Mask (_UV2)", 2D) = "white" {}
	}

	Category
	{
		Tags
		{
			"Queue" = "Transparent"
			"RenderType" = "Transparent"
			"LightMode" = "ForwardBase"
		}

		SubShader
		{
			CGINCLUDE

				#define RENDER_DYNAMICS

				#pragma multi_compile ___ _qc_IGNORE_SKY
				#pragma multi_compile ___ qc_LAYARED_FOG

				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Transparent.cginc"
				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"
				#include "Assets/Qc_Rendering/Shaders/RayMarching_Forward_Integration.cginc"

			ENDCG

			Pass
			{
				Blend SrcAlpha OneMinusSrcAlpha
				ColorMask RGBA
				Cull Off
				ZWrite On

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING
				#pragma shader_feature_local ___ _SUB_SURFACE
				
				struct v2f
				{
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float2 texcoord1	: TEXCOORD1;
					float3 worldPos		: TEXCOORD2;
					float3 normal		: TEXCOORD3;
					float4 wTangent		: TEXCOORD4;
					float3 viewDir		: TEXCOORD5;
					float4 screenPos	: TEXCOORD6;
					fixed4 color : COLOR;
				};

				sampler2D _MainTex;
				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;

				sampler2D _BumpMap;
				float4 _BumpMap_ST;
				
				sampler2D _SpecularMap;

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

					TRANSFER_WTANGENT(o);
					o.screenPos = ComputeScreenPos(o.pos);

					return o;
				}

				float4 _SubSurface;
				sampler2D _SkinMask;

				FragColDepth frag(v2f i)
				{

					float3 viewDir = normalize(i.viewDir.xyz);
					float2 uv = i.texcoord.xy;
					i.screenPos.xy/=i.screenPos.w;

					float dott = dot(viewDir, i.normal.xyz);
					float rawFresnel = pow(max(0, 1-abs(dott)), 4);

					float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));
					uv -= tnormal.rg * _MainTex_TexelSize.xy;

					float isBack = (dot(viewDir, i.normal.xyz) > 0) ? 1 : -1;
					tnormal *= isBack; 

					float3 normal =  i.normal.xyz;
			
					ApplyTangent(normal, tnormal, i.wTangent);


					float4 mohs = tex2D(_SpecularMap, uv);
					float ao = mohs.g;
					float metal = 0;
					float shadow = GetSunShadowsAttenuation(i.worldPos + _WorldSpaceLightPos0.xyz * 0.2, i.screenPos.z);
					float3 lightColor = GetDirectional() * shadow;

					// LIGHTING
					float3 bake;

					float3 volumeSamplePosition;
					bake = Savage_GetVolumeBake(i.worldPos, normal, i.normal, volumeSamplePosition);

					TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
					float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, i.worldPos);
					ao *= topDownAmbient.a;
					bake += topDownAmbient.rgb;


					float4 topDownBehind = SampleTopDown_Ambient(topdownUv, -viewDir, i.worldPos);

					float facingSun = dot(normal, _WorldSpaceLightPos0.xyz);

					float3 lightDiffuse = lightColor * smoothstep(0,0.25, facingSun);

			
					float4 tex = tex2D(_MainTex, uv);
					float3 col = tex.rgb * (lightDiffuse + bake * ao);

				//	col = ApplyStandardTransparentLighting(tex);

					#if _SUB_SURFACE
						float lookingAtSun = smoothstep(0,1, dot(-viewDir, _WorldSpaceLightPos0.xyz)); 
						col += 	tex2D(_SkinMask, uv).rgb * _SubSurface.rgb * _SubSurface.a *(((0.1 + lookingAtSun) *  lightColor)  + topDownBehind.rgb);		
					#endif

					ApplyBottomFog(col.rgb, i.worldPos.xyz, i.viewDir.y);

					float4 result = float4(col, tex.a);
					//float4 result =lerp(float4(reflectionColor * rawFresnel, 0), float4(col.rgb, tex.a), tex.a);
					ApplyLayeredFog_Transparent(result, i.screenPos.xy, i.worldPos);

					//result.rgb *= result.a;
					//result.rgb = lookingAtSun;

					FragColDepth output;
					output.depth =  smoothstep(0, 0.1, result.a) * calculateFragmentDepth(i.worldPos.xyz);
					output.col =
					//float4(bake, result.a);
					result;
					return output;
				}
				ENDCG
			}

			Pass 
			{
				Name "Caster"
				Tags 
				{ 
					"LightMode" = "ShadowCaster" 
				}

				Cull Off//Back
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

				v2f vert( appdata_full v )
				{
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
					TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
					o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
					return o;
				}



				float4 frag( v2f i ) : SV_Target
				{
					float4 texcol = tex2D( _MainTex, i.uv );

					clip(texcol.a - 0.5);

					SHADOW_CASTER_FRAGMENT(i)
				}
				ENDCG
			}
		}
		Fallback "Diffuse"
	}
}