Shader "Quiz cAnners/Illumination Dacals/Simple" 
{
	Properties
	{
		[HDR]_Color("Color", Color) = (1,1,1,1)
		[KeywordEnum(Sphere, Box, Capsule)]	Shape ("Shape", Float) = 0
		[KeywordEnum(Center, Side, Edge, Corner)] Offs ("Offset", Float) = 0
	}

	Category
	{
		Tags
		{
			"Queue" = "Transparent-1"
			"PreviewType" = "Plane"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
		}

		Cull Front
		ZWrite Off
		ZTest Off
		Blend SrcAlpha OneMinusSrcAlpha

		SubShader
		{
			Pass
			{

				CGPROGRAM

				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"
				#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"
				#include "Assets/Qc_Rendering/Shaders/inc/RayDistanceOperations.cginc"
				#include "Assets/Qc_Rendering/Shaders/inc/SDFoperations.cginc"

				#include "Assets/Qc_Rendering/Shaders/RayMarching_Forward_Integration.cginc"

				#pragma shader_feature_local SHAPE_SPHERE SHAPE_BOX SHAPE_CAPSULE
				#pragma shader_feature_local OFFS_CENTER OFFS_SIDE OFFS_EDGE OFFS_CORNER

			//QuaterSphere

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fwdbase
				#pragma multi_compile_instancing
				#pragma target 3.0


				v2fMarchBatchableTransparent vert(appdata_full v) 
				{
					v2fMarchBatchableTransparent o;
					InitializeBatchableTransparentMarcher(v,o);
					return o;
				}

				//sampler2D _CameraDepthTexture;
				float4 _Color;
				//float _Angle;

				float4 frag(v2fMarchBatchableTransparent i) : COLOR
				{
					i.rayDir = normalize(i.rayDir);

					float3 ro = i.rayPos + _ProjectionParams.y * i.rayDir;
					float3 rd = i.rayDir;
					float size = i.centerPos.w;

					//meshQuaternion  
					//meshSize   
					
					float3 farPoint = GetRayPoint(-rd, i.screenPos.xy / i.screenPos.w);

					float4 q = i.meshQuaternion;
					float3 pos = i.centerPos;
					float3 localOffset = RotateVec(pos - farPoint,q) / i.meshSize.xyz;

					float3 len = abs(localOffset);

					float maxExtendSharp = smoothstep(0.5, 0.49, max(len.x, max(len.y, len.z)));

					#if OFFS_SIDE
						localOffset.x = (localOffset.x + 0.5) * 0.5;
					#elif OFFS_EDGE
						localOffset.xz = (localOffset.xz + 0.5) * 0.5;
					#elif OFFS_CORNER
						localOffset.xyz = (localOffset.xyz + 0.5) * 0.5;
					#endif


					float dist;


					#if SHAPE_SPHERE

							dist = dot(localOffset, localOffset);

					#elif SHAPE_BOX 

						float3 offDist =
						abs(localOffset);

						offDist.x = pow(offDist.x,3);
						offDist.y = pow(offDist.y,3);
						offDist.z = pow(offDist.z,3);

						dist = max(max(offDist.x, offDist.y), offDist.z);

					#elif SHAPE_CAPSULE

						q.xyz= -q.xyz;
						float3 lineDirection = Rotate(float3(0,0,1),q);

						float toDepth;
						//dist = GetDistanceToSegment(ro, rd, pos, lineDirection,  size * 0.6, farPoint, toDepth);
						dist = 999; // Temporarily
					#endif


					float maxExtend = smoothstep(1, 0.9, saturate(length(localOffset) * 2));

					float distFade = 1/(1+pow(dist * 10, 2));

			
					float4 col = i.color; 
					col.a *= distFade * maxExtend * maxExtendSharp;
					

					return col;

				}
				ENDCG
			}
		}
		Fallback "Legacy Shaders/Transparent/VertexLit"
	}
}

