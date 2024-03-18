Shader "RayTracing/Effect/Spritesheet/Blurred Screen Grab For Particle System"
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
		SubShader
		{
			GrabPass
			{
				"_GrabTexture"
			}


			Tags
			{ 
				"Queue" = "Transparent+10"
				"IgnoreProjector" = "True"
				"RenderType" = "Transparent"
				"PreviewType" = "Plane"
				"LightMode" = "ForwardBase"
			}

			Blend SrcAlpha OneMinusSrcAlpha

			Cull Off
			ZWrite Off

			Pass
			{

				CGPROGRAM


				#pragma multi_compile __ RT_FROM_CUBEMAP 
				#pragma multi_compile ___ qc_LAYARED_FOG

				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Transparent.cginc"

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
					float4 screenPos : TEXCOORD3;
					float3 worldPos	: TEXCOORD4;
					float3 viewDir	: TEXCOORD5;
#if _MOTION_VECTORS
					float4 motionVectorSampling : TEXCOORD6;
#endif
					float4 uvgrab : TEXCOORD7;
					//float shadow : TEXCOORD8;
					UNITY_VERTEX_OUTPUT_STEREO
				};

				float4 _MainTex_ST;
				sampler2D _MotionVectorsMap;
				float _FlowIntensity;
			//	float _GridSize_Col;
			//	float _GridSize_Row;

				UNITY_DECLARE_SCREENSPACE_TEXTURE(_GrabTexture);

				v2f vert(appdata_t v)
				{
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v); //Insert
					UNITY_INITIALIZE_OUTPUT(v2f, o); //Insert
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); //Insert
					//o.vertex = UnityObjectToClipPos(v.vertex);
					o.vertex = GetBillboardPos(v.vertex);
					o.screenPos = ComputeScreenPos(o.vertex);
					COMPUTE_EYEDEPTH(o.screenPos.z);

					o.color = v.color * _TintColor;
					

					o.texcoord = TRANSFORM_TEX(v.texcoords.xy, _MainTex);
					o.texcoord2 = TRANSFORM_TEX(v.texcoords.zw, _MainTex);
					o.blend = v.texcoordBlend;

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.worldPos = worldPos;
					o.viewDir = WorldSpaceViewDir(v.vertex);

					o.uvgrab = ComputeGrabScreenPos(o.vertex);

				//	o.shadow = //SampleRayShadow(worldPos) *
					//	SampleSkyShadow(worldPos);

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

	

#if _MOTION_VECTORS
					OffsetByMotionVectors(i.texcoord, i.texcoord2, i.motionVectorSampling, _MotionVectorsMap);
#endif


					half4 colA = tex2D(_MainTex, i.texcoord);
					half4 colB = tex2D(_MainTex, i.texcoord2);
					half4 col = i.color *
					LerpTransparent(colA, colB, i.blend);

				//	return  col;

					float3 viewDir = normalize(i.viewDir.xyz);

					float distToCamera = length(_WorldSpaceCameraPos - i.worldPos.xyz) - _ProjectionParams.y;

					float toCamera = smoothstep(0, 1, distToCamera);

					float volumetriEdge = smoothstep(0, 1, 1 - col.r) * (0.1 + distToCamera * 0.1);

					float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
					float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
					float fade = smoothstep(volumetriEdge, volumetriEdge + 1, (sceneZ - i.screenPos.z)) * smoothstep(0.1, _FadeRange, length(i.worldPos - _WorldSpaceCameraPos.xyz));

					col.a = saturate(col.a * fade);

#if !_UNLIT

					float3 normal = -viewDir.xyz;

					float shadow = GetSunShadowsAttenuation(i.worldPos, i.screenPos.z);

					col.rgb = TransparentLightStandard(col, i.worldPos, normal, viewDir, shadow);
#endif

					//ApplyBottomFog(col.rgb, i.worldPos.xyz, viewDir.y);

				

					
					float2 grabUv = i.uvgrab.xy / i.uvgrab.w;
					float2 pix = (_ScreenParams.zw - 1) * (1+col.a*2);// *proximity;// *circle;

				   #define GRABPIXELX(we, offset) UNITY_SAMPLE_SCREENSPACE_TEXTURE(_GrabTexture, grabUv + float2(pix.x * offset, 0)) * we;
				   
				   
				   //tex2Dlod( _MainTex, float4(uv + float2(kernel*xker, 0)  ,0,0)) * weight
				   
				   	float4 sum = 0; // UNITY_SAMPLE_SCREENSPACE_TEXTURE(_GrabTexture, grabUv);

					float div = 0;

				    sum += GRABPIXELX(0.15, -2.0);
					sum += GRABPIXELX(0.30, -1.0);
					sum += GRABPIXELX(0.20, 0.0);
					sum += GRABPIXELX(0.30, +1.0);
					sum += GRABPIXELX(0.15, +2.0);
					div+=1;

					 #define GRABPIXELY(we, offset) UNITY_SAMPLE_SCREENSPACE_TEXTURE(_GrabTexture, grabUv + float2(0, pix.y * offset)) * we;

					sum += GRABPIXELY(0.15, -2.0);
					sum += GRABPIXELY(0.30, -1.0);
					//sum += GRABPIXELY(0.10, 0.0);
					sum += GRABPIXELY(0.30, +1.0);
					sum += GRABPIXELY(0.15, +2.0);
						div+=1;
					


					 #define GRABPIXELXY(we, offsetX, offsetY) UNITY_SAMPLE_SCREENSPACE_TEXTURE(_GrabTexture, grabUv + float2(offsetX*pix.x, offsetY*pix.y)) * we;

					sum += GRABPIXELXY(0.25, -1, -1);
					sum += GRABPIXELXY(0.25, 1, 1);
					sum += GRABPIXELXY(0.25, -1, 1);
					sum += GRABPIXELXY(0.25, 1, -1);
						div+=1;

					sum += GRABPIXELXY(0.25, -1, -2);
					sum += GRABPIXELXY(0.25, 1,  2);
					sum += GRABPIXELXY(0.25, -1, 2);
					sum += GRABPIXELXY(0.25, 1, -2);
						div+=1;

					sum += GRABPIXELXY(0.25, -2, -1);
					sum += GRABPIXELXY(0.25, 2,  1);
					sum += GRABPIXELXY(0.25, -2, 1);
					sum += GRABPIXELXY(0.25, 2, -1);
					div+=1;

					sum.rgb /= div;

					sum.a = 1;

					col += sum * (1-col.a) * smoothstep(0, 0.5, col.a); 
					//LerpTransparent(colA, colB, i.blend);

				//	col.a = smoothstep(0, 0.5, col.a);

				ApplyLayeredFog_Transparent(col, screenUV, distToCamera);

					return col;
				}
				ENDCG
			}
		}
	}
}
