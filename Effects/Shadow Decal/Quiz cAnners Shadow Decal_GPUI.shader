Shader "GPUInstancer/Quiz cAnners/Effects/Shadow decal" 
{
	Properties
	{
		[HDR]_Color("Color", Color) = (1,1,1,1)

		[KeywordEnum(Sphere, Box, Capsule)]	Shape ("Shape", Float) = 0
		

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
#include "UnityCG.cginc"
#include "./../../../GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
#pragma instancing_options procedural:setupGPUI
#pragma multi_compile_instancing

				#include "Assets/Ray-Marching/Shaders/Savage_Sampler_Debug.cginc"
				#include "Assets/Ray-Marching/Shaders/Savage_DepthSampling.cginc"
			#include "Assets/Ray-Marching/Shaders/inc/RayDistanceOperations.cginc"
		
			#pragma shader_feature_local SHAPE_SPHERE SHAPE_BOX SHAPE_CAPSULE 

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fwdbase
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

					float dist;

					#if SHAPE_SPHERE

						dist = dot(localOffset, localOffset);

					#elif SHAPE_BOX 

						float3 offDist =//smoothstep(1-0.1/i.meshSize.xyz,1, 
						abs(localOffset);//);

						offDist.x = pow(offDist.x,3);
						offDist.y = pow(offDist.y,3);
						offDist.z = pow(offDist.z,3);

						//offDist -= pow(localOffset.yzx, 2) + pow(localOffset.zxy, 2);

						dist = max(max(offDist.x, offDist.y), offDist.z);

					#elif SHAPE_CAPSULE

						q.xyz= -q.xyz;
						float3 lineDirection = Rotate(float3(0,0,1),q);

						float toDepth;
						dist = GetDistanceToSegment(ro, rd, pos, lineDirection,  size * 0.6, farPoint, toDepth);

					#endif

					//float3 diff = farPoint - i.centerPos.rgb;

					float distFade = 1/(1+pow(dist * 10, 2));

					float maxExtend = smoothstep(0, 0.25, 1 - saturate(length(localOffset) * 2));

					float4 col = _Color * maxExtend * distFade;

					
					float3 mix = (col.gbr + col.brg);
					col.rgb += mix * mix * 0.1;

					return col;

				}
				ENDCG
			}
		}
		Fallback "Legacy Shaders/Transparent/VertexLit"
	}
}

