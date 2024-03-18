Shader "QcRendering/Tessellation/Qc_Tess_Standard_Specular"
{
	Properties
	{
		_Tess ("Tessellation", Range(1,128)) = 4
		_maxDist ("Tess Fade Distance", Range(0, 500.0)) = 25.0
        _ShadowLOD ("Shadow Gen LOD", Range(0, 1.0)) = 0
        _Displacement ("Displacement", Range(0, 10.0)) = 0.3
        _DispOffset ("Disp Offset", Range(-1, 1)) = 0
        _Phong  ("Phong Smoothing Factor", Range(0, 0.5)) = 0

		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo", 2D) = "white" {}
		
		_BumpScale("Scale", Float) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}
	

		_Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
		_ParallaxMap ("MADS Map", 2D) = "black" {}

		[KeywordEnum(OFF, PLASTIC, METAL, LAYER, MIXED_METAL, PAINTED_METAL)] _REFLECTIVITY("Reflective Material Type", Float) = 0
		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0

		_OcclusionMap("Occlusion", 2D) = "white" {}
		[Toggle(_NO_HB_AMBIENT)] noHbAmbient("Disable HBAO", Float) = 0


		[Toggle(_DAMAGED)] isDamaged("_DAMAGED", Float) = 0
		[NoScaleOffset] _Damage_Tex("_Main DAMAGE Mask (_UV2) (_ATL) (RGB)", 2D) = "black" {}
		_DamDiffuse("Damaged Diffuse", 2D) = "red" {}
		_BumpMapDam("Damaged Normal Map", 2D) = "bump" {}
	}


	SubShader
	{
		Tags 
		{ 
			"RenderType"="Opaque" 
			"PerformanceChecks"="False" 
		}
		LOD 400
	
		CGINCLUDE

			sampler2D   _ParallaxMap;
			float _maxDist;
			float _Displacement;
			float _DispOffset;

#			if _DAMAGED
				sampler2D _Damage_Tex;
				float4 _Damage_Tex_TexelSize;
				sampler2D _DamDiffuse;
				float4 _DamDiffuse_TexelSize;
#			endif
			//half        _Parallax;
			
			float SampleHeight(float2 uv, out float4 dam)
			{
				float h = tex2Dlod(_ParallaxMap, float4(uv, 0, 0)).b;

				#if !_DAMAGED
					dam = 0;
					return h;
				#else
					dam = tex2Dlod(_Damage_Tex, float4(uv, 0, 0));
					h *= saturate(1-dam.g);

					h = lerp(h, 0.25, saturate(dam.r)); // blood

					return h;
				#endif
			}

			float SampleHeight(float2 uv)
			{
			/*
				float h = tex2Dlod(_ParallaxMap, float4(uv, 0, 0)).b;

				#if !_DAMAGED
					return h;
				#else
					float4 dam = tex2Dlod(_Damage_Tex, float4(uv, 0, 0));
					h *= saturate(1-dam.g);

					h = lerp(h, 0.25, saturate(dam.r)); // blood

					return h;
				#endif*/
				float4 dam;

				return SampleHeight(uv, dam);
			}

			float3 GetDispWorldSpace (float2 uv, float3 norm, float dist)
			{
				float fadeOut = saturate((_maxDist - dist) / (_maxDist * 0.7f));
				float d = (SampleHeight(uv) + _DispOffset) * _Displacement;
				//..d = d + _DispOffset * _Displacement;
				return norm * d * fadeOut;
			}

	

		ENDCG

		Pass
		{
			Name "FORWARD" 
			Tags 
			{ 
				"LightMode" = "ForwardBase" 
			}

			ColorMask RGBA
			Cull Back

			CGPROGRAM
			#pragma target gl4.1

			// -------------------------------------

		//	#pragma shader_feature _NORMALMAP

		//	#pragma shader_feature _ FT_EDGE_TESS
			#pragma shader_feature_local ___ _DAMAGED

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
			#pragma shader_feature_local ___ _NO_HB_AMBIENT


			#include "Tess_Standard_Core.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"

			struct VertexOutputForwardBase
			{
				UNITY_POSITION(pos);
				float4 tex                            : TEXCOORD0;
				float4 eyeVec                         : TEXCOORD1;    // eyeVec.xyz | fogCoord
				float4 tangentToWorldAndPackedData[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
				half4 uv1             : TEXCOORD5;    // SH or Lightmap UV
				float4 edge : TEXCOORD6;
				SHADOW_COORDS(8)
				float3 posWorld                     : TEXCOORD9;
				#if !_NO_HB_AMBIENT
					float4 screenPos :		TEXCOORD10;
				#endif
				fixed4 color : COLOR;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			sampler2D   _MainTex;
			float4      _MainTex_ST;

			float4 tessIt (float4 v0, float4 v1, float4 v2) 
			{
				return FTDistanceBasedTess(v0, v1, v2, _maxDist * 0.2f, _maxDist * 1.2f, _Tess);
			}

				
			float4 disp (float4 pos, float2 uv, float3 norm)
			{
				float d = SampleHeight(uv) * _Displacement;
				d = d * 0.5 - 0.5 + _DispOffset;

				return UnityObjectToClipPos(float4(pos.xyz + norm * d, pos.w));
			}

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
				o.color = v.color;
				o.edge = float4(v.uv1.w, v.uv2.w, v.uv3.w, v.uv0.w);

				o.tex = float4(v.uv0 * _MainTex_ST.xy + _MainTex_ST.zw,0,0);// TexCoords(v);
				o.eyeVec.xyz = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
				float3 normalWorld = UnityObjectToWorldNormal(v.normal);

				float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

				float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
				o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
				o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
				o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];

				//We need this for shadow receving
				//UNITY_TRANSFER_LIGHTING(o, v.uv1);
				TRANSFER_SHADOW(o);

				o.uv1 = v.uv1;//VertexGIForward(v, posWorld, normalWorld);
		

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
				o.color =  v[0].color * fU + v[1].color * fV + v[2].color * fW; //v.color;

				o.edge =v[0].edge * fU + v[1].edge * fV + v[2].edge * fW;

				half4 tangentToWorldAndPackedData0 = v[0].tangentToWorldAndPackedData[0] * fU + v[1].tangentToWorldAndPackedData[0] * fV + v[2].tangentToWorldAndPackedData[0] * fW;
				half4 tangentToWorldAndPackedData1 = v[0].tangentToWorldAndPackedData[1] * fU + v[1].tangentToWorldAndPackedData[1] * fV + v[2].tangentToWorldAndPackedData[1] * fW;
				half4 tangentToWorldAndPackedData2 = v[0].tangentToWorldAndPackedData[2] * fU + v[1].tangentToWorldAndPackedData[2] * fV + v[2].tangentToWorldAndPackedData[2] * fW;
				half4 uv1 = v[0].uv1 * fU + v[1].uv1 * fV + v[2].uv1 * fW;
				o.uv1 = uv1;

				o.tangentToWorldAndPackedData[0] = tangentToWorldAndPackedData0;
				o.tangentToWorldAndPackedData[1] = tangentToWorldAndPackedData1;
				o.tangentToWorldAndPackedData[2] = tangentToWorldAndPackedData2;

				phongIt4 (pos, v[0].pos, v[1].pos, v[2].pos, v[0].tangentToWorldAndPackedData[2] , v[1].tangentToWorldAndPackedData[2] , v[2].tangentToWorldAndPackedData[2] , bary);
								float3 posWorld = v[0].posWorld * fU + v[1].posWorld * fV + v[2].posWorld * fW;
				phongIt3 (posWorld, v[0].posWorld, v[1].posWorld, v[2].posWorld, v[0].tangentToWorldAndPackedData[2].xyz, v[1].tangentToWorldAndPackedData[2].xyz, v[2].tangentToWorldAndPackedData[2].xyz, bary);
					
				float dist =  length(posWorld - _WorldSpaceCameraPos.xyz) - _ProjectionParams.y;

				float3 normalWorld = normalize( tangentToWorldAndPackedData2.xyz);


				float4 ed = smoothstep(0.8, 1, o.edge);
				
				//return ed.a;


				o.posWorld = posWorld + GetDispWorldSpace(tex.xy, normalWorld, dist) ;//* (1- ed.a);

				float4 vertexDta = mul(unity_WorldToObject, float4(o.posWorld.xyz,1));

				o.pos = UnityObjectToClipPos(vertexDta);

				#if !_NO_HB_AMBIENT
					o.screenPos = ComputeScreenPos(o.pos);
				#endif

			//	o.pos = disp(pos, tex.xy, tangentToWorldAndPackedData2.xyz);

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

		

			sampler2D _BumpMapDam;

			half4 frag (VertexOutputForwardBase i) : SV_Target
			{ 
				UNITY_SETUP_INSTANCE_ID(i);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

				#if !_NO_HB_AMBIENT
						float2 screenUv = i.screenPos.xy / i.screenPos.w;
				#endif

				float4 i_tex =i.tex ; 

				float2 uv2 = i.uv1;

				//float4 ed = smoothstep(0.9, 1, i.edge);
				
				//return ed.a;

				//i.color;// 
				//float4(uv2,0,1);

				float4 bump = tex2D (_BumpMap, i_tex.xy);

				float shadow = SHADOW_ATTENUATION(i);
				float4 tex = tex2D(_MainTex, i.tex.xy);
				float4 dam;
				float4 madsMap = SampleHeight(i.tex.xy, dam);

#			if _DAMAGED
				float4 damTex = tex2D(_DamDiffuse, uv2);
					float isDam = smoothstep(0.1, 0.3, dam.g);
			//	return isDam;

			
				tex = lerp(tex, damTex, isDam);
				madsMap = lerp(madsMap, float4(0,0.5,0,0.1), isDam);
				bump = lerp (bump, tex2D(_BumpMapDam, i.tex.xy), isDam);

				

#			endif


				half3 normalTangent =  UnpackNormal(bump);


				half3 tangent = i.tangentToWorldAndPackedData[0].xyz;
				half3 binormal = i.tangentToWorldAndPackedData[1].xyz;
				half3 normal = i.tangentToWorldAndPackedData[2].xyz;

				float3 normalWorld = NormalizePerPixelNormal(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z);

				float3 viewDir = -normalize(i.eyeVec.xyz);


				float fresnel = saturate(1 - dot(viewDir, normalWorld));
				float metal = madsMap.r;

					float4 illumination;
				float ao = 
			#if _NO_HB_AMBIENT
				1;
				illumination = 0;
			#else
				SampleSS_Illumination( screenUv, illumination);
				shadow *= saturate(1-illumination.b);
			#endif	

				ao *= madsMap.g + (1-madsMap.g) * fresnel;

				MaterialParameters precomp;
					
				precomp.shadow = shadow;
				precomp.ao = ao;
				precomp.fresnel = fresnel;
				precomp.tex = tex;
				
				precomp.reflectivity = 0.1; //_Reflectivity;
				precomp.metal = metal;
				precomp.traced = 0; //i.traced;
				precomp.water = 0;
				precomp.smoothsness = madsMap.a;

				precomp.microdetail = 0;
				precomp.metalColor = tex; //lerp(tex, _MetalColor, _MetalColor.a);


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

			#pragma multi_compile_shadowcaster

			#pragma skip_variants _PARALLAXMAP 
			#pragma shader_feature_local ___ _DAMAGED

			#define TESS_SHADOW

			#pragma vertex vs_tess
			#pragma fragment fragShadowCaster
			#pragma hull hs_tess
    		#pragma domain ds_tess

			#include "Tess_Standard_Shadow.cginc"


			float4 disp (float4 pos, float2 uv, float3 norm)
			{
			//	float fadeOut =  saturate((_maxDist - distance(mul(unity_ObjectToWorld, pos.xyz), _WorldSpaceCameraPos)) / (_maxDist * 0.7f));
				float d = SampleHeight(uv * _MainTex_ST.xy + _MainTex_ST.zw)* _Displacement;//tex2Dlod(_ParallaxMap, float4(uv * _MainTex_ST.xy + _MainTex_ST.zw, 0, 0)).b * _Displacement;
				d = d * 0.5 - 0.5 + _DispOffset;
				return float4(pos.xyz + mul(unity_WorldToObject, norm) * d, pos.w);
			}

			[domain("tri")]
			void ds_tess(TessFactors hs_data, const OutputPatch<TessData, 3> vi, float3 bary : SV_DomainLocation,
			#ifdef UNITY_STANDARD_USE_SHADOW_OUTPUT_STRUCT
			  out VertexOutputShadowCaster o,
			#endif
			  out float4 opos : SV_POSITION
			)
			{
				VertexInput v = (VertexInput)0;

				float fU = bary.x;
				float fV = bary.y;
				float fW = bary.z;

				float4 vertex = vi[0].vertex * fU + vi[1].vertex * fV + vi[2].vertex * fW;
				v.normal = vi[0].normal * fU + vi[1].normal * fV + vi[2].normal * fW;
				v.uv0 = vi[0].uv0 * fU + vi[1].uv0 * fV + vi[2].uv0 * fW;

				phongIt4 (vertex, vi[0].vertex, vi[1].vertex, vi[2].vertex, vi[0].normal, vi[1].normal, vi[2].normal, bary);
				
			//v.normal; // Incorrect
				
				
				//	float3 posWorld2 = v[0].posWorld * fU + v[1].posWorld * fV + v[2].posWorld * fW;
				//	phongIt3 (posWorld2, v[0].posWorld, v[1].posWorld, v[2].posWorld, v[0].tangentToWorldAndPackedData[2].xyz, v[1].tangentToWorldAndPackedData[2].xyz, v[2].tangentToWorldAndPackedData[2].xyz, bary);
				//float dist =  max(0, distance(mul(unity_ObjectToWorld, vertex.xyz), _WorldSpaceCameraPos) - _ProjectionParams.y);
					
				//distance(mul(unity_ObjectToWorld, vertex.xyz), _WorldSpaceCameraPos);

			//	float3 normalWorld = tangentToWorldAndPackedData2.xyz;

				float3 normal = normalize(mul(unity_ObjectToWorld, float4(v.normal,0)).xyz);

				//	float dist = max(0, distance(mul(unity_ObjectToWorld, pos.xyz), _WorldSpaceCameraPos) - _ProjectionParams.y);
				float3 posWorld = mul(unity_ObjectToWorld, float4(vertex.xyz,1)).xyz;

				float dist = length(posWorld.xyz - _WorldSpaceCameraPos.xyz) - _ProjectionParams.y;
				
				posWorld = mul(unity_ObjectToWorld, float4(vertex.xyz,1)).xyz + GetDispWorldSpace(v.uv0, normal, dist); 

				v.vertex = mul(unity_WorldToObject, float4(posWorld.xyz,1)); 

				// To Object space
				//v.vertex = disp(vertex, v.uv0, normal);

				#if defined(UNITY_STANDARD_USE_SHADOW_UVS) && defined(_PARALLAXMAP)
					v.tangent = vi[0].tangent * fU + vi[1].tangent * fV + vi[2].tangent * fW;
				#endif

				v.vertex.w = 1.0;

				TRANSFER_SHADOW_CASTER_NOPOS(o,opos)
				#if defined(UNITY_STANDARD_USE_SHADOW_UVS)
					o.tex = float4(v.uv0,0,0); // TRANSFORM_TEX(v.uv0, _MainTex);
				#endif
			}


			
half4 fragShadowCaster (UNITY_POSITION(vpos)
#ifdef UNITY_STANDARD_USE_SHADOW_OUTPUT_STRUCT
    , VertexOutputShadowCaster i
#endif
	) : SV_Target
	{
		SHADOW_CASTER_FRAGMENT(i)
	}


			ENDCG
		}
	}

	FallBack "VertexLit"
}
