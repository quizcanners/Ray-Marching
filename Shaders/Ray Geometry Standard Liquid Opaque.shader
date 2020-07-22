Shader "RayTracing/Geometry/Liquid Opaque"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
	}

	Category
	{
		SubShader
		{
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

				#define RENDER_DYNAMICS

				#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
				#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
				#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
				#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"



				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
			
				#pragma multi_compile ___ _qc_Rtx_MOBILE
			

				struct v2f {
					float4 pos			: SV_POSITION;
					float3 worldPos		: TEXCOORD2;
					float3 normal		: TEXCOORD3;
					float4 wTangent		: TEXCOORD4;
					float3 viewDir		: TEXCOORD5;
					SHADOW_COORDS(6)
					float2 topdownUv : TEXCOORD7;
					float2 lightMapUv : TEXCOORD8;
					fixed4 color : COLOR;
				};


				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.pos = UnityObjectToClipPos(v.vertex);
					
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


				float4 _Color;


				float4 frag(v2f o) : COLOR
				{

					#if _qc_Rtx_MOBILE
						float oob;
						float4 vlm =  SampleVolume(o.worldPos, oob);
						return vlm * _Color;
					#endif


					float3 viewDir = normalize(o.viewDir.xyz);
					float rawFresnel = smoothstep(1,0, dot(viewDir, o.normal.xyz));

					float3 normal = o.normal.xyz;

					float fresnel = saturate(dot(normal,viewDir));

					float showReflected = 1 - fresnel;
				
					float shadow = SHADOW_ATTENUATION(o);// *SampleSkyShadow(o.worldPos);

					float outOfBounds;
					float4 vol = SampleVolume(o.worldPos, outOfBounds);
					TopDownSample(o.worldPos, vol.rgb, outOfBounds);

					float3 ambientCol = lerp(vol, GetDirectional(), outOfBounds);

					float direct = saturate((dot(normal, _WorldSpaceLightPos0.xyz)));
					float3 lightColor = _LightColor0.rgb * direct;

					float world = SceneSdf(o.worldPos, 0.1);
					float farFromSurface = smoothstep(0.3, 1.2, world);

					float4 col = 1;

					col.rgb =
						(ambientCol * 0.5
							+ lightColor * shadow
							);

					float3 reflectionPos;
					float outOfBoundsRefl;
					float3 bakeReflected = SampleReflection(o.worldPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);
					TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);

					float outOfBoundsStraight;
					float3 straightHit;
					float3 bakeStraight = SampleRay(o.worldPos, normalize(-viewDir - normal * 0.2), shadow, straightHit, outOfBoundsStraight);
					TopDownSample(straightHit, bakeStraight, outOfBoundsStraight);

				

				//	return farFromSurface;

					
					float showStright = fresnel * fresnel;

					col.rgb = _Color.rgb * col.rgb * 0.25
						+ lerp(_Color.rgb * bakeReflected,  (_Color.rgb*0.75 + farFromSurface*0.25)  * bakeStraight, showStright);

					ApplyBottomFog(col.rgb, o.worldPos, viewDir.y);



					return col;

				}
				ENDCG
			}

			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

		}
		Fallback "Diffuse"
	}
}