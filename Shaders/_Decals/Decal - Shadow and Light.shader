Shader "RayTracing/Decal/Shadow & Light"
{
	Properties
	{
		[KeywordEnum(Sphere, Hemisphere)] SHAPE("Shape", Float) = 0
		[Toggle(_INVERT)] invertShadow("Invert Light And Shadow", Float) = 0
	}

	SubShader{
		Tags
		{
			"Queue" = "Geometry+10"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
			"LightMode" = "ForwardBase"
		}

		Blend DstColor Zero //Blend SrcAlpha OneMinusSrcAlpha
		ZWrite off
		ZTest off
		Cull Front

		Pass{
			CGPROGRAM

			
			#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Sampler.cginc"
			#include "Assets/Qc_Rendering/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Qc_Rendering/Shaders/RayMarching_Forward_Integration.cginc"
			#include "Assets/Qc_Rendering/Shaders/Sampler_TopDownLight.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"
			#include "Assets/Qc_Rendering/Shaders/inc/SDFoperations.cginc"


			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			//#pragma multi_compile_fwdbase
			#pragma shader_feature_local  ___ _INVERT

			#pragma shader_feature_local SHAPE_SPHERE SHAPE_HEMISPHERE 

			struct v2f {
				float4 pos: SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float3 viewDir		: TEXCOORD1;
				float3 meshPos :		TEXCOORD2;
				float4 meshSize :		TEXCOORD3;
				float4 meshQuaternion : TEXCOORD4;
				float4 centerPos :		TEXCOORD5;
				float upscaleProjection : TEXCOORD6;
				fixed4 color : COLOR;
			};

			//the vertex shader function
			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.screenPos = ComputeScreenPos(o.pos);
				o.viewDir = WorldSpaceViewDir(v.vertex);
				o.meshPos = v.texcoord;
				o.meshSize = v.texcoord1;
				o.meshQuaternion = v.texcoord2;

				o.meshSize.w = min(o.meshSize.z, min(o.meshSize.x, o.meshSize.y));

				float maxSize = max(o.meshSize.z, max(o.meshSize.x, o.meshSize.y));

				o.centerPos = float4(o.meshPos.xyz, maxSize);


				o.upscaleProjection = 1 / min(o.meshSize.x, o.meshSize.y);

				o.color = v.color;

				COMPUTE_EYEDEPTH(o.screenPos.z);
				return o;
			}


			float4 frag(v2f i) : COLOR
			{
				float3 viewDir = normalize(i.viewDir.xyz);
				float2 screenUv = i.screenPos.xy / i.screenPos.w;
				float3 newPos = GetRayPoint(viewDir, screenUv);

				float3 relativePosition = GetRotatedPos(newPos, i.centerPos.xyz, i.meshQuaternion);


				float4 col;

#if SHAPE_HEMISPHERE // Hemisphere is the problematic one
				float3 off = relativePosition.xyz / i.meshSize.xyz;

				float front = smoothstep(0.5, -0.5, off.z);

#if _INVERT
				front = 1 - front;
#endif

				off = abs(off);

				float center = smoothstep(0.5, 0, max(off.x, off.y)) * smoothstep(0.5,0.4, off.z);
				//smoothstep(0.5, 0, length(relativePosition / i.meshSize.xyz));
			

				col.rgb = lerp(0, 6 * i.color.rgb, front * front * front);//lerp(lerp(1, 8 * i.color.rgb, center), 0, center);
				col.rgb = lerp(1, col.rgb, i.color.a * center);

#else
				float center = smoothstep(0.5, 0, length(relativePosition / i.meshSize.xyz));
				clip(center - 0.001);

				

#if _INVERT
				//center = 1 - center;
				col.rgb = lerp(lerp(1, 0, center), 8 * i.color.rgb  * center, center * center * center);
#else

				float deCaneter = 1 - center;
				deCaneter *= deCaneter;
				center = 1 - deCaneter;
				col.rgb = lerp(lerp(1, 8 * i.color.rgb, center), 0, center);
#endif

				
				col.rgb = lerp(1, col.rgb, i.color.a);

#endif

				

				col.a = 0;

				//ApplyBottomFog(col.rgb, newPos, i.viewDir.y);


				return col;
			}

			ENDCG
		}
	//UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
}
}