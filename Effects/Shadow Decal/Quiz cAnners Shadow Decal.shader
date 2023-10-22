Shader "Quiz cAnners/Effects/Shadow decal" 
{
	Properties
	{
		[HDR]_Color("Color", Color) = (1,1,1,1)
	}

	Category
	{
		Tags
		{
			"Queue" = "Transparent+1"
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

				#include "Assets/Ray-Marching/Shaders/Savage_Sampler_Debug.cginc"
				#include "Assets/Ray-Marching/Shaders/Savage_DepthSampling.cginc"
			
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

					//meshQuaternion  4
					//meshSize   4
					

					float3 farPoint = GetRayPoint(-rd, i.screenPos.xy / i.screenPos.w);


					float4 q = i.meshQuaternion;
					float3 pos = i.centerPos;

					float3 localOffset = RotateVec(pos - farPoint,q) / i.meshSize.xyz;



					//float3 diff = farPoint - i.centerPos.rgb;

					float dist = 1/(1+pow(dot(localOffset, localOffset) * 10, 2));

					float maxExtend = smoothstep(0, 0.25, 1 - saturate(length(localOffset) * 2));

					_Color.a *= maxExtend * 
					dist;

					return _Color;

				}
				ENDCG
			}
		}
		Fallback "Legacy Shaders/Transparent/VertexLit"
	}
}

