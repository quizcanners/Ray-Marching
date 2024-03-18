Shader "QcRendering/Geometry/Beveled Edges/Cell Shaded"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		[HDR]_Color("Color", Color) =  (1,1,1,1)
	//	[Toggle(_REFLECTIVITY)] reflectivity("Any Reflectivity", Float) = 0
		[KeywordEnum(OFF, PLASTIC, METAL, LAYER)] _REFLECTIVITY("Reflective Material Type", Float) = 0
		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0

		_Reflectivity("Refectivity", Range(0,1)) = 0.33
		_Smoothness("Smoothness", Range(0,1)) = 0.33
		//_Metal("Metal", Range(0,1)) = 0.33

		[KeywordEnum(None, Separate)] _AO("AO Source", Float) = 0
		_OcclusionMap("Ambient Map", 2D) = "white" {}
		[Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0

		_EdgeColor("Edge Color Tint", Color) = (0.5,0.5,0.5,0)
		_MetalColor("Metal Color", Color) = (0.5, 0.5, 0.5, 0)
	
		
		[Toggle(_DEBUG_EDGES)] debugEdges("Debug Edges", Float) = 0

		[Toggle(_DYNAMIC_OBJECT)] dynamic("Dynamic Object", Float) = 0
		[Toggle(_INDIRECT_INSTANCING)] indirectInst("Indirect Instancing", Float) = 0

	}

	Category
	{
		SubShader
		{

			// Color.a is used for Ambient SHadow + Edge visibility

			Tags
			{
				"Queue" = "Geometry"
				"RenderType" = "Opaque"
				"LightMode" = "ForwardBase"
				"Solution" = "Bevel With Seam"

			}

			ColorMask RGB
			Cull Back

			Pass
			{

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				#pragma shader_feature_local ___ _COLOR_R_AMBIENT
				#pragma shader_feature_local _AO_NONE _AO_SEPARATE
				#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
				#pragma shader_feature_local __ _DEBUG_EDGES
				#pragma shader_feature_local ___ _DYNAMIC_OBJECT
				#pragma shader_feature_local _REFLECTIVITY_OFF _REFLECTIVITY_PLASTIC _REFLECTIVITY_METAL _REFLECTIVITY_LAYER
				#pragma shader_feature_local ___ _INDIRECT_INSTANCING

				#pragma multi_compile ___ _qc_USE_RAIN
				#pragma multi_compile ___ _qc_IGNORE_SKY
				#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 

				  #include "UnityCG.cginc"
				#include "AutoLight.cginc"
				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"

				#if _INDIRECT_INSTANCING
					#define UNITY_INDIRECT_DRAW_ARGS IndirectDrawIndexedArgs
				    #include "UnityIndirect.cginc"
				#endif

				

				struct v2f 
				{
					float4 pos			: SV_POSITION;
					float2 texcoord		: TEXCOORD0;
					float3 worldPos		: TEXCOORD1;
					float3 normal		: TEXCOORD2;
					float3 viewDir		: TEXCOORD4;
					SHADOW_COORDS(5)
					float4 edge			: TEXCOORD6;
					float3 snormal		: TEXCOORD7;
					float3 edgeNorm0	: TEXCOORD8;
					float3 edgeNorm1	: TEXCOORD9;
					float3 edgeNorm2	: TEXCOORD10;
					float4 traced : TEXCOORD11;
					float4 screenPos :		TEXCOORD12;
					fixed4 color : COLOR;
				};

				#if _INDIRECT_INSTANCING
					StructuredBuffer<float4x4> _Matrices;
				#endif

				sampler2D _MainTex;
				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				float4 _EdgeColor;
				sampler2D _Map;
				float4 _Map_ST;


				#if _INDIRECT_INSTANCING
					v2f vert(appdata_full v, uint svInstanceID : SV_InstanceID)
				#else
					v2f vert(appdata_full v) 
				#endif
				{
					v2f o;

					float3 worldPos;

					#if _INDIRECT_INSTANCING
					   InitIndirectDrawArgs(0);
						uint cmdID = GetCommandID(0);
						uint instanceID = GetIndirectInstanceID(svInstanceID);
						//worldPos = v.vertex.xyz + cmdID * 3 + _Positions[instanceID].xyz;
						worldPos = mul(_Matrices[instanceID], v.vertex).xyz;
						o.pos = mul(UNITY_MATRIX_VP,  float4(worldPos.xyz, v.vertex.w));
					#else
						UNITY_SETUP_INSTANCE_ID(v);
						worldPos = mul(unity_ObjectToWorld, v.vertex);
						o.pos = UnityObjectToClipPos(v.vertex);
					#endif

					o.screenPos = ComputeScreenPos(o.pos);

					o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.worldPos = worldPos;
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);

					#if _DEBUG_EDGES
						o.color = 1;
					#endif

					o.edge = float4(v.texcoord1.w, v.texcoord2.w, v.texcoord3.w, v.texcoord.w);
					o.edgeNorm0 = UnityObjectToWorldNormal(v.texcoord1.xyz);
					o.edgeNorm1 = UnityObjectToWorldNormal(v.texcoord2.xyz);
					o.edgeNorm2 = UnityObjectToWorldNormal(v.texcoord3.xyz);

					float3 deEdge = 1 - o.edge.xyz;

					o.snormal.xyz = normalize(o.edgeNorm0 * deEdge.x + o.edgeNorm1 * deEdge.y + o.edgeNorm2 * deEdge.z);
					
					#if !_REFLECTIVITY_OFF
						o.traced = GetTraced_Mirror_Vert(o.worldPos, normalize(o.viewDir.xyz), o.normal.xyz);
					#else 
						o.traced = 0;
					#endif

					TRANSFER_SHADOW(o);

					return o;
				}

			float _Reflectivity;
			float _Smoothness;

			#if _AO_SEPARATE
				sampler2D _OcclusionMap;
			#endif

			

			
			float4 _Color;

			float4 _MetalColor;

				float4 frag(v2f i) : COLOR
				{
					float2 screenUv = i.screenPos.xy / i.screenPos.w;

	
						float3 viewDir = normalize(i.viewDir.xyz);
						float4 seam = 
						#if _COLOR_R_AMBIENT
							0;
						#else 
							i.color;
						#endif

						float hideSeam;
						float3 normal = GetBeveledNormal_AndSeam(seam, i.edge,viewDir, i.normal.xyz, i.snormal.xyz, i.edgeNorm0, i.edgeNorm1, i.edgeNorm2, hideSeam);	
						hideSeam *= _EdgeColor.a;

						float2 uv = i.texcoord.xy;

						float ao = SampleSSAO(screenUv);// UNITY_SAMPLE_SCREENSPACE_TEXTURE(_HBAOTex, screenUv).a;


	#if _AO_SEPARATE
						ao* = tex2D(_OcclusionMap, uv).r;
	#endif

	#if _COLOR_R_AMBIENT
						ao *= (0.25 + i.color.r * 0.75);
	#endif

						float4 tex = tex2D(_MainTex, uv) * _Color;

						#if _DEBUG_EDGES
							tex.rgb = normal;
						#endif

						tex = lerp(tex, _EdgeColor, hideSeam);
				float shadow = SHADOW_ATTENUATION(i);
			float water = 0;


								// ********************** Contact Shadow



	#		if _qc_USE_RAIN 
				water += GetRain(i.worldPos, normal, i.normal, shadow);
				float makeSmooth = smoothstep(0.25, 0.3, water * max(0, normal.y + 0.1));
				_Smoothness = lerp(_Smoothness, 0.95, makeSmooth);
	#		endif


				float fresnel = GetFresnel_FixNormal(normal,  i.snormal.xyz, viewDir);

					float3 worldPosAdjusted = i.worldPos;

					float mixMetal = 0;

					MaterialParameters precomp;
					
					precomp.shadow = shadow;
					precomp.ao = ao;
					precomp.fresnel = fresnel;
					precomp.tex = tex;
					precomp.smoothsness= _Smoothness;
					precomp.reflectivity= _Reflectivity;
					precomp.metal= mixMetal;
					precomp.traced= i.traced;
					precomp.water = water;
					precomp.microdetail = 0;
					precomp.metalColor = lerp(tex, _MetalColor, _MetalColor.a);

					float3 col = GetReflection_ByMaterialType(precomp, normal, i.normal.xyz, viewDir, worldPosAdjusted);

					ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

					return float4(col, 1);

				}
				ENDCG
			}
			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
		}
		Fallback "Diffuse"
	}
}