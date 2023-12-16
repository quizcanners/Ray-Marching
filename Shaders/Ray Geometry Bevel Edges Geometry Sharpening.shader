Shader "RayTracing/Geometry/Beveled Edges Geometry Sharpner "
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		[Toggle(_DEBUG_EDGES)] thisDoesntMatter("Debug Edges", Float) = 0
		_EdgeColor("Edge Color Tint", Color) = (0.5,0.5,0.5,0)
	}

	Category{
		SubShader{

			// Color.a is used for Ambient SHadow + Edge visibility

			Tags{
				"Queue" = "Geometry"
				"RenderType" = "Opaque"
				"LightMode" = "ForwardBase"
				"Solution" = "Bevel With Seam"
			}

			ColorMask RGBA
			Cull Back

			Pass{

				CGPROGRAM

				#pragma multi_compile ___ _qc_IGNORE_SKY

				#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Sampler.cginc"
				#include "Assets/Qc_Rendering/Shaders/Signed_Distance_Functions.cginc"
				#include "Assets/Qc_Rendering/Shaders/RayMarching_Forward_Integration.cginc"
				#include "Assets/Qc_Rendering/Shaders/Sampler_TopDownLight.cginc"

				#pragma vertex vert
				#pragma geometry geom
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				#pragma shader_feature_local _BUMP_NONE // _BUMP_REGULAR _BUMP_COMBINED 
				#pragma shader_feature_local ___ _DEBUG_EDGES

				struct v2g {
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float3 worldPos		: TEXCOORD1;
					float3 normal		: TEXCOORD2;
					float4 wTangent		: TEXCOORD3;
					float3 viewDir		: TEXCOORD4;
					float4 edge			: TEXCOORD6;
					float3 edgeNorm0	: TEXCOORD8;
					float3 edgeNorm1	: TEXCOORD9;
					float3 edgeNorm2	: TEXCOORD10;
					float2 topdownUv	: TEXCOORD11;
					fixed4 color : COLOR;
				};

				sampler2D _MainTex;
				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				float4 _EdgeColor;

				sampler2D _Map;
				float4 _Map_ST;


				v2g vert(appdata_full v) {
					v2g o;
					UNITY_SETUP_INSTANCE_ID(v);

					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.worldPos = mul(unity_ObjectToWorld, v.vertex);
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);

					o.wTangent.xyz = UnityObjectToWorldDir(v.tangent.xyz);
					o.wTangent.w = v.tangent.w * unity_WorldTransformParams.w;

					o.edge = float4(v.texcoord1.w, v.texcoord2.w, v.texcoord3.w, v.texcoord.w);
	
					o.edgeNorm0 = UnityObjectToWorldNormal(v.texcoord1.xyz);
					o.edgeNorm1 = UnityObjectToWorldNormal(v.texcoord2.xyz);
					o.edgeNorm2 = UnityObjectToWorldNormal(v.texcoord3.xyz);
		
					o.topdownUv = (o.worldPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;

					return o;
				}


				struct g2f
				{
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float3 worldPos		: TEXCOORD1;
					float3 normal		: TEXCOORD2;
					float4 wTangent		: TEXCOORD3;
					float3 viewDir		: TEXCOORD4;
					SHADOW_COORDS(5)
					float4 edge			: TEXCOORD6;
					float3 snormal		: TEXCOORD7;
					float3 edgeNorm0	: TEXCOORD8;
					float3 edgeNorm1	: TEXCOORD9;
					float3 edgeNorm2	: TEXCOORD10;
					float2 topdownUv	: TEXCOORD11;
					fixed4 color : COLOR;
				};


				[maxvertexcount(3)]
				void geom(triangle v2g input[3], inout TriangleStream<g2f> triStream)
				{
					g2f o;

					float3 sharpNormal = normalize(cross(input[1].worldPos - input[0].worldPos, input[2].worldPos - input[0].worldPos));

					for (int i = 0; i < 3; i++)
					{
						v2g el = input[i];

						o.pos = el.pos;
						o.texcoord = el.texcoord;
						o.worldPos = el.worldPos;
						o.normal = el.normal;
						o.wTangent = el.wTangent;
						o.viewDir = el.viewDir;
						o.edge = el.edge; 
						o.snormal = sharpNormal; 
						o.edgeNorm0 = el.edgeNorm0;
						o.edgeNorm1 = el.edgeNorm1;
						o.edgeNorm2 = el.edgeNorm2;
						o.topdownUv	 = el.topdownUv;
						o.color = el.color;

						TRANSFER_SHADOW(o);

						triStream.Append(o);
					}
					triStream.RestartStrip();
				}
		
				inline float3 DetectSmoothEdgeBySeam(float4 seam, float4 edge, float3 junkNorm, float3 sharpNorm, float3 edge0, float3 edge1, float3 edge2, out float weight)
				{
					float width = length(fwidth(edge.rgb));// *2; // *30;
					edge = smoothstep(1 - width, 1, edge);
					seam = smoothstep(1 - width, 1, seam);

					float border = smoothstep(0,1, edge.r + edge.g + edge.b);
					float3 edgeN = edge0 * edge.r + edge1 * edge.g + edge2 * edge.b;

					weight =  smoothstep(0, 2, (seam.r + seam.g + seam.b + seam.a) * border);

					return normalize(

						//lerp(
							lerp(sharpNorm, edgeN, border)
							//,junkNorm,	junk)

					);

				}


				float4 frag(g2f o) : COLOR
				{

					float3 viewDir = normalize(o.viewDir.xyz);

					float4 seam = o.color;
					float3 normal;
					float weight;
					normal = DetectSmoothEdgeBySeam(seam, o.edge, o.normal.xyz, o.snormal.xyz, o.edgeNorm0, o.edgeNorm1, o.edgeNorm2, weight);

					float edgeColorVisibility =  weight;


					float3 preNorm = normal;

					float2 uv = o.texcoord.xy;

					smoothedPixelsSampling(uv, _MainTex_TexelSize);

					float4 bumpMap;
					float3 tnormal;
					SampleBumpMap(_Map, bumpMap, tnormal, uv);

					float4 tex = tex2D(_MainTex, uv) * o.color;

					tex = lerp(tex, _EdgeColor, edgeColorVisibility * _EdgeColor.a);

					ApplyTangent(normal, tnormal, o.wTangent);

					float fresnel = smoothstep(0,1,dot(normal, viewDir));

					//return float4(normal,1);
				
					float shadow = SHADOW_ATTENUATION(o);

					
#if _DEBUG_EDGES

					return edgeColorVisibility;
#endif


#if !_BUMP_COMBINED
					bumpMap.b = 0.1;
					bumpMap.a = 1;
#endif

					float smoothness = bumpMap.b;
					float ambient =	bumpMap.a;

					float direct = shadow * smoothstep(1 - ambient, 1.5 - ambient * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));

					float3 lightColor = GetDirectional() * direct;

					float3 volumePos = o.worldPos;

					float outOfBounds;
					float4 bake = SampleVolume(volumePos, outOfBounds);

					bake.rgb = lerp(bake.rgb, GetAvarageAmbient(normal), outOfBounds); // Up 

					//ApplyTopDownLightAndShadow(o.topdownUv, normal, bumpMap, o.worldPos, 1- outOfBounds, fresnel, bake);

					//ColorCorrect(tex.rgb);
				
					float3 col = tex.rgb * (lightColor + bake.rgb * ambient) + lightColor * 0.02 * (1 - fresnel);

					//return tex;

					ApplyBottomFog(col, o.worldPos.xyz, viewDir.y);

					return float4(col,1);

				}
				ENDCG
			}
			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
		}
		Fallback "Diffuse"
	}
}