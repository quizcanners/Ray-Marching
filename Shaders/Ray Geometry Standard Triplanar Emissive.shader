Shader "RayTracing/Geometry/Emissive Triplanar"
{
	Properties
	{
		_HorizontalTiling("Tiling", Range(0.01,10)) = 1

		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		_BumpMap("Normal Map", 2D) = "bump" {}

		[Toggle(_TRIPLANAR)] isTriplanar("Triplanar", Float) = 1
		[Toggle(_BEVELED)] isBeveled("Beveled", Float) = 0

		[HDR] _EmissionColor("Emission Color", Color) = (1, 1, 1, 0)
	
		_Multiply("Multiply", Range(0,1)) = 0.5

		 _EdgeColor("Edge Color", Color) = (0.5,0.5,0.5,0)
		 _EdgeMads ("Edge Mads", Color) = (1, 1, 1, 0)

		[Toggle(_OFFSET_BY_HEIGHT)] heightOffset("Offset By Height", Float) = 0

		[Toggle(_SIMPLIFY_SHADER)] simplifyShader("Simplify Shader", Float) = 0
	}

	Category
	{
		SubShader
		{
	

			Tags
			{
				"Queue" = "Geometry"
				"RenderType" = "Opaque"
				"LightMode" = "ForwardBase"
				"DisableBatching" = "True"
				"Solution" = "Bevel With Seam"
			}

			Pass
			{
				ColorMask RGBA
				Cull Back

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING
					
				#define RENDER_DYNAMICS

				#pragma shader_feature_local ___ _BEVELED
				#pragma shader_feature_local ___ _OFFSET_BY_HEIGHT
				#pragma shader_feature_local ___ _SIMPLIFY_SHADER
				#pragma shader_feature_local ___ _TRIPLANAR

				#pragma multi_compile ___ _qc_USE_RAIN

				#include "Assets/Ray-Marching/Shaders/Savage_Sampler_Debug.cginc"

				struct v2f
				{
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float3 worldPos		: TEXCOORD1;
					float3 normal		: TEXCOORD2;
					float4 wTangent		: TEXCOORD3;
					float3 viewDir		: TEXCOORD4;

#if _BEVELED

					float4 edge			: TEXCOORD6;
					float3 snormal		: TEXCOORD7;
					float3 edgeNorm0	: TEXCOORD8;
					float3 edgeNorm1	: TEXCOORD9;
					float3 edgeNorm2	: TEXCOORD10;
#else
					float2 texcoord1	: TEXCOORD6;
#endif

					fixed4 color : COLOR;
				};

				v2f vert(appdata_full v)
				{
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = v.texcoord;
					
					o.worldPos = worldPos;
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);
					
#if _BEVELED
					o.edge = float4(v.texcoord1.w, v.texcoord2.w, v.texcoord3.w, v.texcoord.w);
					o.edgeNorm0 = UnityObjectToWorldNormal(v.texcoord1.xyz);
					o.edgeNorm1 = UnityObjectToWorldNormal(v.texcoord2.xyz);
					o.edgeNorm2 = UnityObjectToWorldNormal(v.texcoord3.xyz);

					float3 deEdge = 1 - o.edge.xyz;

					// This one is inconsistent with Batching
					o.snormal.xyz = normalize(o.edgeNorm0 * deEdge.x + o.edgeNorm1 * deEdge.y + o.edgeNorm2 * deEdge.z);
#else
					o.texcoord1 = v.texcoord1;
#endif


					TRANSFER_WTANGENT(o)
					return o;
				}

				sampler2D _MainTex;
				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				sampler2D _BumpMap;
				sampler2D _SpecularMap;
				float4 _EdgeColor;
				float _HorizontalTiling;
				float4 _EmissionColor;
				float4 _EdgeMads;

				float GetShowNext(float currentHeight, float newHeight, float dotNormal)
				{
					return smoothstep(0, 0.2, newHeight * dotNormal - currentHeight * (1-dotNormal));
				}

				void CombineMaps(inout float currentHeight, inout float4 madsMap, out float3 tnormal, out float showNew, float dotNormal, float2 uv)
				{
					tnormal = UnpackNormal(tex2D(_BumpMap, uv));
					float4 newMadspMap = tex2D(_SpecularMap, uv);
					float newHeight = 0.5 + newMadspMap.b*0.5;  

					showNew = GetShowNext(currentHeight, newHeight, dotNormal);
					currentHeight = lerp(currentHeight,newHeight ,showNew);
					madsMap = lerp(madsMap, newMadspMap, showNew);
				}


				float _Multiply;

#if _OFFSET_BY_HEIGHT
				FragColDepth frag(v2f i)
#else 
				float4 frag(v2f i) : COLOR
#endif
				{
					float3 viewDir = normalize(i.viewDir.xyz);
					float3 preNormal;
#if _BEVELED

					float4 seam = i.color;

					//return seam;
					float edgeColorVisibility;
					preNormal = GetBeveledNormal_AndSeam(seam, i.edge,viewDir, i.normal.xyz, i.snormal.xyz, i.edgeNorm0, i.edgeNorm1, i.edgeNorm2, edgeColorVisibility);
					
				

#else
					preNormal = i.normal.xyz;
#endif

					float3 distanceToCamera = length(_WorldSpaceCameraPos - i.worldPos);

									
					float3 normal = preNormal;


				#if _TRIPLANAR 
					float3 uvHor = i.worldPos * _HorizontalTiling;
					float2 tiling = _MainTex_ST.xy;
					// Horizontal Sampling X
					float3 tnormalX = UnpackNormal(tex2D(_BumpMap, uvHor.zy * tiling));
					float4 madsMap = tex2D(_SpecularMap, uvHor.zy * tiling);
					float horHeight = madsMap.b;
					
					float4 tex = tex2D(_MainTex, uvHor.zy * tiling);

					float3 horNorm = float3( 0 , tnormalX.y, tnormalX.x);

					// Horixontal Sampling Z
					float3 tnormalZ;
					float showZ;
					CombineMaps(horHeight, madsMap, tnormalZ, showZ, abs(normal.z) , uvHor.xy * tiling);

					float4 texZ = tex2Dlod(_MainTex, float4(uvHor.xy * tiling, 0, 0));

					//return texZ;
					tex = lerp(tex,texZ ,showZ);

					horNorm = lerp(horNorm, float3(tnormalZ.x, tnormalZ.y, 0), showZ);

					// Update normal
					float horBumpVaidity = 1-abs(normal.y);
					normal = normalize(normal + horNorm * horBumpVaidity);
					
					// Vertial Sampling
					float4 texTop = tex2Dlod(_MainTex, float4(uvHor.xz * tiling, 0, 0));

					float3 tnormalTop = UnpackNormal(tex2D(_BumpMap, uvHor.xz * tiling ));
					float3 topNorm = float3(tnormalTop.x, 0, tnormalTop.y);

					float4 madsMapTop = tex2D(_SpecularMap, uvHor.xz * tiling);
					float topHeight = 0.5 + madsMapTop.b * 0.5;

				

					// Combine

					float showTop = GetShowNext(horHeight, topHeight, pow(abs(normal.y),2));
					
					float height = lerp(horHeight,topHeight ,showTop);
					tex = lerp(tex, texTop ,showTop);


					madsMap = lerp(madsMap, madsMapTop, showTop);
					float3 triplanarNorm = lerp(horNorm, topNorm, showTop);
					normal = normalize(preNormal.xyz + triplanarNorm * 3);

					#else
						float4 tex = tex2D(_MainTex, i.texcoord);
						float3 tnormal = UnpackNormal(tex2D(_BumpMap, i.texcoord));
						float4 madsMap = tex2D(_SpecularMap, i.texcoord);
						ApplyTangent(normal, tnormal, i.wTangent);
					#endif



#if _BEVELED

	float disAndAo = 1-(1-madsMap.g)* (1-madsMap.b);

					edgeColorVisibility = smoothstep((1 - disAndAo)*0.75,1, edgeColorVisibility);

					tex = lerp(tex, _EdgeColor, edgeColorVisibility * _EdgeColor.a);
					madsMap = lerp(madsMap, _EdgeMads, edgeColorVisibility);
					normal = normalize(lerp(normal, preNormal, edgeColorVisibility));
#endif

					float ao = madsMap.g ;

					float water = 0;
					float displacement = madsMap.b;


					// ********************** WATER


#if _qc_USE_RAIN
					float shadow = 0;
					float rain = GetRain(i.worldPos, normal, i.normal, shadow);

					float glossLayer = ApplyWater(water, rain, ao, displacement, madsMap, normal, i.worldPos, i.normal.y);

					float3 tmpNormal = preNormal;
					ApplyTangent(tmpNormal, normal, i.wTangent);

					normal = lerp(normal, tmpNormal, glossLayer);
#endif



// ********************* LIGHT

					float fresnel = GetFresnel_FixNormal(normal, i.normal.xyz, viewDir) * ao;//GetFresnel(normal, viewDir) * ao;

					float metal = madsMap.r;
					float specular = madsMap.a; // GetSpecular(madsMap.a, fresnel * _Reflectivity, metal);

					float ambAo;
					float3 ambientLight = SampleAmbientLight(i.worldPos, ambAo);
					ao *= ambAo;


					float smoothFresnel = smoothstep(0,1, dot(viewDir, i.normal.xyz));

					_EmissionColor.rgb *= _EmissionColor.a * smoothFresnel * lerp(1, tex.rgb, _Multiply);

				
					float overlay = ao; // + ao)*smoothFresnel;

					/*
							#if  _BEVELED
						tex.rgb = lerp(tex.rgb, _EdgeColor.rgb, edgeColorVisibility);
					#endif*/

					float3 col =  lerp(_EmissionColor.rgb, tex.rgb * ambientLight, overlay);

				
			

					//edgeColorVisibility = lerp(edgeColorVisibility, 1, useSdf);
					//_EdgeColor.a = lerp(_EdgeColor.a, 1, useSdf);


					ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);



#if _OFFSET_BY_HEIGHT
					FragColDepth mobres;
					//edgeColorVisibility
					float depthOffset = (1- edgeColorVisibility) * (height - 0.5) * (1 + rawFresnel * rawFresnel * 4) * 0.2;

					mobres.depth = calculateFragmentDepth(i.worldPos + depthOffset * viewDir);
					mobres.col = float4(col, 1);

					return mobres;
#else 
					return float4(col, 1);
#endif

					//return float4(col,1);

				}
				ENDCG
			}

			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

		}
		Fallback "Diffuse"
	}
}