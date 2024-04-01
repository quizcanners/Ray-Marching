Shader "RayTracing/Decal/Simple"
{
	Properties
	{
		 _MainTex("Texture", 2D) = "white" {}
		[NoScaleOffset]_BumpMap("Bump", 2D) = "bump" {}
		[NoScaleOffset]_SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
		[KeywordEnum(OFF, PLASTIC, METAL, LAYER, MIXED_METAL, PAINTED_METAL)] _REFLECTIVITY("Reflective Material Type", Float) = 0
		[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0
		_Reflectivity("Added Reflectiveness (Mat)", Range(0,1)) = 0.33

			[Toggle(_SHADOW_IMITATION)] shadowImitation("Shadow Imitation", Float) = 0

		[Toggle(_EMISSIVE)] emissiveTexture("Emissive Texture", Float) = 0
		_Emissive("Emissive", 2D) = "clear" {}
	}

	SubShader{
		Tags
		{ 
			"Queue" = "Geometry+1"
			"RenderType" = "Opaque"
			"LightMode" = "ForwardBase"
		}

		Blend SrcAlpha OneMinusSrcAlpha
		ZWrite off
		ZTest off
		Cull Front

		Pass{
			Tags {"LightMode" = "ForwardBase"}
			CGPROGRAM

			#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
			#pragma multi_compile ___ _qc_IGNORE_SKY 

			#pragma shader_feature_local _PER_PIXEL_REFLECTIONS_OFF _PER_PIXEL_REFLECTIONS_ON _PER_PIXEL_REFLECTIONS_INVERTEX  _PER_PIXEL_REFLECTIONS_MIXED
			#pragma shader_feature_local _REFLECTIVITY_OFF _REFLECTIVITY_PLASTIC _REFLECTIVITY_METAL _REFLECTIVITY_LAYER  _REFLECTIVITY_MIXED_METAL  _REFLECTIVITY_PAINTED_METAL

			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"
			#include "Assets/Qc_Rendering/Shaders/inc/SDFoperations.cginc"

			
			#include "Assets/Qc_Rendering/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Qc_Rendering/Shaders/RayMarching_Forward_Integration.cginc"
		
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing

			#pragma multi_compile_fwdbase
			#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

			#pragma shader_feature_local __ _SHADOW_IMITATION
	

			struct v2f 
			{
				float4 pos:				SV_POSITION;
				float4 screenPos :		TEXCOORD0;
				float3 viewDir		:	TEXCOORD1;
				float3 meshPos :		TEXCOORD2;
				float4 meshSize :		TEXCOORD3;
				float4 meshQuaternion : TEXCOORD4;
				float4 centerPos :		TEXCOORD5;
				float upscaleProjection : TEXCOORD6;
			};

			//the vertex shader function
			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.screenPos = ComputeScreenPos(o.pos);
				COMPUTE_EYEDEPTH(o.screenPos.z);

				o.viewDir = WorldSpaceViewDir(v.vertex);
				o.meshPos = v.texcoord;
				o.meshSize = v.texcoord1;
				o.meshQuaternion = v.texcoord2;

				o.meshSize.w = min(o.meshSize.z, min(o.meshSize.x, o.meshSize.y));

				float maxSize = max(o.meshSize.z, max(o.meshSize.x, o.meshSize.y));

				o.centerPos = float4(o.meshPos.xyz, maxSize);


				o.upscaleProjection = 1 / min(o.meshSize.x, o.meshSize.y);

				//o.color = _Color;
				//float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
				
				//TRANSFER_TOP_DOWN(o);
				return o;
			}

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			sampler2D _SpecularMap;
			float _Reflectivity;

			float4 frag(v2f i) : COLOR
			{
				float3 viewDir = normalize(i.viewDir.xyz);
				float2 screenUv = i.screenPos.xy / i.screenPos.w;
				float3 newPos = GetRayPoint(viewDir, screenUv);

				float3 relativePosition = GetRotatedPos(newPos, i.centerPos.xyz, i.meshQuaternion);

				float3 off = relativePosition.xyz / i.meshSize.xyz;
				off = abs(off);
				float center = smoothstep(0.5, 0.4, max(off.z, max(off.x, off.y))); // *smoothstep(0.5, 0.4, off.z);
				//return fromCenter;

			//	return center;
				float4 q = i.meshQuaternion;
				float4 inverseQuaternion = float4(-q.x, -q.y, -q.z, q.w);

				float2 uv = relativePosition.xy * i.upscaleProjection + 0.5;
			
				uv = uv * _MainTex_ST.xy + _MainTex_ST.zw;

				float4 tex = tex2D(_MainTex, uv);
				float4 bumpSample = tex2D(_BumpMap, uv);
				float3 tnormal = UnpackNormal(bumpSample);
				
				float3 normal =  normalize(Rotate(float4(tnormal,0), inverseQuaternion));

			//	return float4(normal, 1);

				float4 madsMap = tex2D(_SpecularMap, uv);
			
			

				#if _SHADOW_IMITATION
					

					float3 localSpaceSun = normalize(Rotate(float4(qc_SunBackDirection.xyz, 0),inverseQuaternion));

					//return float4(qc_SunBackDirection.xyz, 1);

					float2 localShadowUVoffset =  float2(
						localSpaceSun.x, 
						localSpaceSun.z
						);

					float4 sTex = tex2Dlod(_MainTex, float4(uv + localShadowUVoffset * float2(0.1, 0.1) * _MainTex_ST.xy,0,3));

					float fadeShadow =  (1-tex.a) * center;

					float showShadow = sTex.a * fadeShadow;

					float aoTex = tex2Dlod(_MainTex, float4(uv,0,4)).a * fadeShadow;

			

					clip(tex.a + showShadow + aoTex - 0.01);
				#endif

				tex.a *= center;
				

				float4 illumination;

			float ao = 
			#if _NO_HB_AMBIENT
				1;
				illumination = 0;
			#else
				SampleSS_Illumination( screenUv, illumination);
			#endif			

			float shadow = saturate(1-illumination.b);

			shadow *= getShadowAttenuation(newPos);

					// **************** light

					float metal = madsMap.r;
					float fresnel = GetFresnel_FixNormal(normal, normal, viewDir);//GetFresnel(normal, viewDir) * ao;

					MaterialParameters precomp;
					
					precomp.shadow = shadow;
					precomp.ao = ao;
					precomp.fresnel = fresnel;
					precomp.tex = tex;
				
					precomp.reflectivity = _Reflectivity;
					precomp.metal = metal;
					precomp.traced = 0;
					precomp.water = 0;
					precomp.smoothsness = madsMap.a;

					precomp.microdetail = 0.5; //_MudColor;
					precomp.metalColor = 0.5; //lerp(tex, _MetalColor, _MetalColor.a);

					precomp.microdetail.a = 0;
				
					float3 col = GetReflection_ByMaterialType(precomp, normal, normal, viewDir, newPos);


					#if _EMISSIVE
						col.rgb += tex2D(_Emissive, uv).rgb;
					#endif


					float4 result = float4(col, tex.a);

				#if _SHADOW_IMITATION
					showShadow *= shadow * 0.5;

					showShadow = lerp(showShadow, 1, aoTex);

					result = lerp(result, float4(0,0,0,1), showShadow);
				#endif


				ApplyBottomFog(result.rgb, newPos, i.viewDir.y);

				
				return result;
			}

			ENDCG
		}
		//UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
	}
}