Shader "RayTracing/Effect/Spritesheet/For Particle System"
{
	Properties{
		[HDR] _TintColor("Tint Color", Color) = (0.5,0.5,0.5,0.5)
		_MainTex("Tex (Feed UV, UV2, AnimBlend)", 2D) = "white" {}
		_InvFade("Soft Particles Factor", Range(0.01,5)) = 1.0
		_FadeRange("Fade When Near", Range(0.1,100)) = 0.3

		[Toggle(_UNLIT)] notLit("Emissive Effect", Float) = 0

	 [Toggle(_MOTION_VECTORS)] motVect("Has Flow Motion Vectors", Float) = 0
	  _MotionVectorsMap("Flow Motion Vetors", 2D) = "white" {}
	  _FlowIntensity("Flow Intensity", Range(0,1)) = 0

	_GridSize_Col("Columns", Range(1,128)) = 1.0
	_GridSize_Row("Rows", Range(1,128)) = 1.0
	}

	Category
	{

		Tags
		{ 
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
			"PreviewType" = "Plane"
			"LightMode" = "ForwardBase"
		}

		Blend SrcAlpha OneMinusSrcAlpha

		Cull Off
		ZWrite Off

		SubShader
		{
			Pass
			{

				CGPROGRAM

				#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
				#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
				#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
				#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"


				#pragma vertex vert
				#pragma fragment frag

				#pragma shader_feature_local __ _MOTION_VECTORS
				#pragma shader_feature_local __ _UNLIT

				sampler2D _MainTex;
				fixed4 _TintColor;

				struct appdata_t 
				{
					float4 vertex : POSITION;
					fixed4 color : COLOR;
					float3 normal : NORMAL;
					float4 texcoords : TEXCOORD0;
					float texcoordBlend : TEXCOORD1;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};

				struct v2f {
					float4 vertex : SV_POSITION;
					fixed4 color : COLOR;
					float2 texcoord : TEXCOORD0;
					float2 texcoord2 : TEXCOORD1;
					float blend : TEXCOORD2;
					float4 screenPos : TEXCOORD4;
					float3 worldPos	: TEXCOORD5;
					float3 viewDir	: TEXCOORD6;
#if _MOTION_VECTORS
					float4 motionVectorSampling : TEXCOORD7;
#endif
					UNITY_VERTEX_OUTPUT_STEREO
				};

				float4 _MainTex_ST;
				sampler2D _MotionVectorsMap;
				float _FlowIntensity;
				float _GridSize_Col;
				float _GridSize_Row;

				v2f vert(appdata_t v)
				{
					v2f o;
				UNITY_SETUP_INSTANCE_ID(v); //Insert
					UNITY_INITIALIZE_OUTPUT(v2f, o); //Insert
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); //Insert
					o.vertex = UnityObjectToClipPos(v.vertex);
					o.screenPos = ComputeScreenPos(o.vertex);
					COMPUTE_EYEDEPTH(o.screenPos.z);

					o.color = v.color * _TintColor;
					

					o.texcoord = TRANSFORM_TEX(v.texcoords.xy, _MainTex);
					o.texcoord2 = TRANSFORM_TEX(v.texcoords.zw, _MainTex);
					o.blend = v.texcoordBlend;

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.worldPos = worldPos;
					o.viewDir = WorldSpaceViewDir(v.vertex);


#if _MOTION_VECTORS
					float2 deGrid = 1 / float2(_GridSize_Col, _GridSize_Row);
					o.motionVectorSampling = MotionVectorsVertex(_FlowIntensity, o.blend, deGrid);
#endif

					return o;
				}

				float _InvFade;
				float _FadeRange;

				fixed4 frag(v2f i) : SV_Target
				{
					//return float4(i.color.xyz, 1);
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i); //Insert
				float2 screenUV = i.screenPos.xy / i.screenPos.w;

				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
				float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
				float partZ = i.screenPos.z;
				float fade = smoothstep(0, 1, _InvFade * (sceneZ - partZ)) * smoothstep(0.1, _FadeRange, length(i.worldPos - _WorldSpaceCameraPos.xyz));
		

#if _MOTION_VECTORS
					OffsetByMotionVectors(i.texcoord, i.texcoord2, i.motionVectorSampling, _MotionVectorsMap);
#endif


					half4 colA = tex2D(_MainTex, i.texcoord);
					half4 colB = tex2D(_MainTex, i.texcoord2);
					half4 col = i.color * LerpTransparent(colA, colB, i.blend);

				//	return  col;

					float3 viewDir = normalize(i.viewDir.xyz);

#if !_UNLIT

					float outOfBounds;
					float4 bake = SampleVolume(i.worldPos, outOfBounds);

					i.worldPos.y *= 0.5;

					TopDownSample(i.worldPos, bake.rgb, outOfBounds);

					

					col.rgb *= bake.rgb;

#endif

					ApplyBottomFog(col.rgb, i.worldPos.xyz, viewDir.y);

					col.a = saturate(col.a * fade);
					return col;
				}
				ENDCG
			}
		}
	}
}
