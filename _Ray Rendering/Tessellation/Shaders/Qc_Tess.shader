// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Tessellation/Qc_Tess_Standard_Specular"
{
	Properties
	{
		_Tess ("Tessellation", Range(1,32)) = 4
		_maxDist ("Tess Fade Distance", Range(0, 500.0)) = 25.0
        _ShadowLOD ("Shadow Gen LOD", Range(0, 1.0)) = 0
        _Displacement ("Displacement", Range(0, 10.0)) = 0.3
        _DispOffset ("Disp Offset", Range(0, 1)) = 0.5
        _Phong  ("Phong Smoothing Factor", Range(0, 0.5)) = 0
     //   [Enum(Distance Based,0,Edge Length,1)] _TessMode ("Tessellation Mode", Float) = 1

		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo", 2D) = "white" {}
		
		_BumpScale("Scale", Float) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}

		_Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
		_ParallaxMap ("MADS Map", 2D) = "black" {}

		[KeywordEnum(OFF, PLASTIC, METAL, LAYER, MIXED_METAL, PAINTED_METAL)] _REFLECTIVITY("Reflective Material Type", Float) = 0
		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0

		_OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
		_OcclusionMap("Occlusion", 2D) = "white" {}

		// Blending state
		[HideInInspector] _Mode ("__mode", Float) = 0.0
		[HideInInspector] _SrcBlend ("__src", Float) = 1.0
		[HideInInspector] _DstBlend ("__dst", Float) = 0.0
		[HideInInspector] _ZWrite ("__zw", Float) = 1.0
	}


	SubShader
	{
		Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
		LOD 400
	

	
		CGINCLUDE



		
		ENDCG

		// ------------------------------------------------------------------
		//  Base forward pass (directional light, emission, lightmaps, ...)
		Pass
		{
			Name "FORWARD" 
			Tags { "LightMode" = "ForwardBase" }

			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]

			CGPROGRAM
			#pragma target gl4.1

			// -------------------------------------

			#pragma shader_feature _NORMALMAP
			#pragma shader_feature _ FT_EDGE_TESS

			#pragma multi_compile_fwdbase
			#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING


			#pragma vertex vert
			#pragma fragment frag
			#pragma hull hs_tess
    		#pragma domain ds_tess


							#pragma multi_compile ___ _qc_USE_RAIN 
				#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
				#pragma multi_compile ___ _qc_IGNORE_SKY 


				#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
				#pragma shader_feature_local _REFLECTIVITY_OFF _REFLECTIVITY_PLASTIC _REFLECTIVITY_METAL _REFLECTIVITY_LAYER  _REFLECTIVITY_MIXED_METAL  _REFLECTIVITY_PAINTED_METAL



			#include "Tess_Standard_Core.cginc"

			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Debug.cginc"

		//	#define _TANGENT_TO_WORLD

			struct VertexOutputForwardBase
			{
				UNITY_POSITION(pos);
				float4 tex                            : TEXCOORD0;
				float4 eyeVec                         : TEXCOORD1;    // eyeVec.xyz | fogCoord
				float4 tangentToWorldAndPackedData[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
				half4 ambientOrLightmapUV             : TEXCOORD5;    // SH or Lightmap UV
			//	UNITY_LIGHTING_COORDS(6,7)
				SHADOW_COORDS(6)
				// next ones would not fit into SM2.0 limits, but they are always for SM3.0+
			//#if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
				float3 posWorld                     : TEXCOORD8;
		//	#endif

				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			sampler2D   _MainTex;
			float4      _MainTex_ST;

			sampler2D   _ParallaxMap;
			half        _Parallax;
			
			#ifdef FT_EDGE_TESS
				float4 tessIt (float4 v0, float4 v1, float4 v2)
				{
					float outTess = max(2.0, _Tess);
					return FTSphereProjectionTess (v0, v1, v2, _Displacement, outTess);
				}

				float4 disp (float4 pos, float2 uv, float3 norm)
				{
					float d = tex2Dlod(_ParallaxMap, float4(uv, 0, 2)).b * _Displacement;
					d = d * 0.5 - 0.5 + _DispOffset;
					return  UnityObjectToClipPos(float4(pos.xyz +  norm * d, pos.w)); 
				}

				float3 disp2 (float3 pos, float2 uv, float3 norm, float dist)
				{
					float d = tex2Dlod(_ParallaxMap, float4(uv, 0, 2)).b * _Displacement;
					d = d * 0.5 - 0.5 + _DispOffset;
					return pos + norm * d; 
				}
			#else
				float4 tessIt (float4 v0, float4 v1, float4 v2) 
				{
					return FTDistanceBasedTess(v0, v1, v2, _maxDist * 0.2f, _maxDist * 1.2f, _Tess);
				}

				float4 disp (float4 pos, float2 uv, float3 norm)
				{
					float fadeOut = saturate((_maxDist - distance(mul(unity_ObjectToWorld, pos.xyz), _WorldSpaceCameraPos)) / (_maxDist * 0.7f));
					float d = tex2Dlod(_ParallaxMap, float4(uv, 0, 2)).b * _Displacement;
					d = d * 0.5 - 0.5 + _DispOffset;
					return UnityObjectToClipPos(float4(pos.xyz +  norm  * d * fadeOut, pos.w));
				}

				float3 disp2 (float3 pos, float2 uv, float3 norm, float dist)
				{
					float fadeOut = saturate((_maxDist - dist) / (_maxDist * 0.7f));
					float d = tex2Dlod(_ParallaxMap, float4(uv, 0, 2)).b * _Displacement;
					d = d * 0.5 - 0.5 + _DispOffset;
					return pos + norm * d * fadeOut;
				}
			#endif
			

			[UNITY_domain("tri")]
			[UNITY_partitioning("fractional_odd")]
			[UNITY_outputtopology("triangle_cw")]
			[UNITY_patchconstantfunc("hs_const")]
			[UNITY_outputcontrolpoints(3)]
			VertexOutputForwardBase hs_tess(InputPatch<VertexOutputForwardBase, 3> v, uint cpID : SV_OutputControlPointID)
			{
				VertexOutputForwardBase o = (VertexOutputForwardBase) v[cpID];
				return o;
			}

			[domain("tri")]
			VertexOutputForwardBase ds_tess(TessFactors hs_data, const OutputPatch<VertexOutputForwardBase, 3> v, float3 bary : SV_DomainLocation)
			{
				VertexOutputForwardBase o = (VertexOutputForwardBase)0;

				float fU = bary.x;
				float fV = bary.y;
				float fW = bary.z;

				float4 pos = v[0].pos * fU + v[1].pos * fV + v[2].pos * fW;
				float4 tex = v[0].tex * fU + v[1].tex * fV + v[2].tex * fW;

    			float4 eyeVec = v[0].eyeVec * fU + v[1].eyeVec * fV + v[2].eyeVec * fW;

				o.tex = tex;
				o.eyeVec = eyeVec;

				half4 tangentToWorldAndPackedData0 = v[0].tangentToWorldAndPackedData[0] * fU + v[1].tangentToWorldAndPackedData[0] * fV + v[2].tangentToWorldAndPackedData[0] * fW;
				half4 tangentToWorldAndPackedData1 = v[0].tangentToWorldAndPackedData[1] * fU + v[1].tangentToWorldAndPackedData[1] * fV + v[2].tangentToWorldAndPackedData[1] * fW;
				half4 tangentToWorldAndPackedData2 = v[0].tangentToWorldAndPackedData[2] * fU + v[1].tangentToWorldAndPackedData[2] * fV + v[2].tangentToWorldAndPackedData[2] * fW;
				half4 ambientOrLightmapUV = v[0].ambientOrLightmapUV * fU + v[1].ambientOrLightmapUV * fV + v[2].ambientOrLightmapUV * fW;
				o.ambientOrLightmapUV = ambientOrLightmapUV;

				o.tangentToWorldAndPackedData[0] = tangentToWorldAndPackedData0;
				o.tangentToWorldAndPackedData[1] = tangentToWorldAndPackedData1;
				o.tangentToWorldAndPackedData[2] = tangentToWorldAndPackedData2;

				phongIt4 (pos, v[0].pos, v[1].pos, v[2].pos, v[0].tangentToWorldAndPackedData[2] , v[1].tangentToWorldAndPackedData[2] , v[2].tangentToWorldAndPackedData[2] , bary);
				
				//#if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
					float3 posWorld = v[0].posWorld * fU + v[1].posWorld * fV + v[2].posWorld * fW;
					phongIt3 (posWorld, v[0].posWorld, v[1].posWorld, v[2].posWorld, v[0].tangentToWorldAndPackedData[2].xyz, v[1].tangentToWorldAndPackedData[2].xyz, v[2].tangentToWorldAndPackedData[2].xyz, bary);
					float dist = distance(mul(unity_ObjectToWorld, pos.xyz), _WorldSpaceCameraPos);
					o.posWorld = disp2(posWorld, tex.xy, tangentToWorldAndPackedData2.xyz, dist);
				//#endif
				
				o.pos = disp(pos, tex.xy, tangentToWorldAndPackedData2.xyz);

				TRANSFER_SHADOW(o);

				return o;
			}


			TessFactors hs_const(InputPatch<VertexOutputForwardBase, 3> v )
			{
				 TessFactors o;
				 float4 factors = tessIt(v[0].pos, v[1].pos, v[2].pos);
				 o.edge[0] = factors.x;
				 o.edge[1] = factors.y;
				 o.edge[2] = factors.z;
				 o.inside = factors.w;    
				 return o;
			}

			VertexOutputForwardBase vert (VertexInput v)
			{
				UNITY_SETUP_INSTANCE_ID(v);
				VertexOutputForwardBase o;
				UNITY_INITIALIZE_OUTPUT(VertexOutputForwardBase, o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
				o.posWorld = posWorld.xyz;

				#if UNITY_REQUIRE_FRAG_WORLDPOS
					#if UNITY_PACK_WORLDPOS_WITH_TANGENT
						o.tangentToWorldAndPackedData[0].w = posWorld.x;
						o.tangentToWorldAndPackedData[1].w = posWorld.y;
						o.tangentToWorldAndPackedData[2].w = posWorld.z;
						
					#endif
				#endif
				o.pos = v.vertex;

				o.tex = float4(v.uv0 * _MainTex_ST.xy + _MainTex_ST.zw,0,0);// TexCoords(v);
				o.eyeVec.xyz = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
				float3 normalWorld = UnityObjectToWorldNormal(v.normal);
				#ifdef _TANGENT_TO_WORLD
					float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

					float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
					o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
					o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
					o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];
				#else
					o.tangentToWorldAndPackedData[0].xyz = 0;
					o.tangentToWorldAndPackedData[1].xyz = 0;
					o.tangentToWorldAndPackedData[2].xyz = normalWorld;
				#endif

				//We need this for shadow receving
				UNITY_TRANSFER_LIGHTING(o, v.uv1);

				o.ambientOrLightmapUV = 0 ;//VertexGIForward(v, posWorld, normalWorld);

				#ifdef _PARALLAXMAP
					TANGENT_SPACE_ROTATION;
					half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
					o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
					o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
					o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
				#endif

				UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o,o.pos);
				return o;
			}







			half4 frag (VertexOutputForwardBase i) : SV_Target
			{ 
				UNITY_SETUP_INSTANCE_ID(i);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

				float4 i_tex =i.tex ; 

				float3 normalWorld = PerPixelWorldNormal(i_tex, i.tangentToWorldAndPackedData);
				float3 viewDir = normalize(i.eyeVec.xyz);
	
				float shadow = SHADOW_ATTENUATION(i);
				float4 tex = tex2D(_MainTex, i.tex.xy);
				float4 madsMap = tex2D(_ParallaxMap, i.tex.xy);


				float fresnel = saturate(1 - dot(viewDir, normalWorld));
				float metal = madsMap.r;
				float ao = madsMap.g;
				float specular = GetSpecular(madsMap.a, fresnel , metal);
				float _Reflectivity = 0.5;

				MaterialParameters precomp;
					
				precomp.shadow = shadow;
				precomp.ao = ao;
				precomp.fresnel = fresnel;
				precomp.tex = tex;
				
				precomp.reflectivity = _Reflectivity;
				precomp.metal = metal;
				precomp.traced = 0; //i.traced;
				precomp.water = 0;
				precomp.smoothsness = specular;

				precomp.microdetail = 0;
				precomp.metalColor = tex; //lerp(tex, _MetalColor, _MetalColor.a);

				/*
				#if !_MICRODETAIL_NONE && !_DAMAGED && !_SECOND_LAYER
					precomp.microdetail.a *= microdetSample;
				#else
					precomp.microdetail.a = 0;
				#endif*/

				float3 col = GetReflection_ByMaterialType(precomp, normalWorld, normalWorld, viewDir, i.posWorld);





				ApplyBottomFog(col, i.posWorld.xyz, viewDir.y);

				return float4(col,1); 
			}


			ENDCG
		}


		// ------------------------------------------------------------------
		//  Shadow rendering pass
		Pass {
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			ZWrite On ZTest LEqual

			CGPROGRAM
			#pragma target gl4.1

			// -------------------------------------


		//	#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
		//	#pragma shader_feature _SPECGLOSSMAP
			#pragma multi_compile_shadowcaster

			#pragma shader_feature _ FT_EDGE_TESS

			#pragma skip_variants _PARALLAXMAP 
			#define TESS_SHADOW

			#pragma vertex vs_tess
			#pragma fragment fragShadowCaster
			#pragma hull hs_tess
    		#pragma domain ds_tess

			#include "Tess_Standard_Shadow.cginc"

			ENDCG
		}
	}

	FallBack "VertexLit"
}
