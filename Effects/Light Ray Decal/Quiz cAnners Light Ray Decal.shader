Shader "Quiz cAnners/Effects/Light Ray Decal" 
{
	Properties
	{
		[HDR]_Color("Color", Color) = (1,1,1,1)
		[HDR]_FadeColor("Fade Color", Color) = (1,1,1,1)
	}

	Category
	{
		Tags
		{
			"Queue" = "Transparent+1"
			"PreviewType" = "Plane"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
			"DisableBatching" = "True"
		}

		Cull Front
		ZWrite Off
		ZTest Off
		Blend SrcAlpha One //MinusSrcAlpha

		SubShader
		{
			Pass
			{
				CGPROGRAM

				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Debug.cginc"
				#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"
				#include "Assets/Qc_Rendering/Shaders/inc/RayDistanceOperations.cginc"
		
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

				float4 _Color;
				float4 _FadeColor;

				float LaserGyroid(float3 pos, float scale) 
				{
					pos *= scale;
    				return dot(sin(pos), cos(pos.zxy))/scale ;
				}

				float4 frag(v2fMarchBatchableTransparent i) : COLOR
				{
					i.rayDir = normalize(i.rayDir);

					float3 ro = i.rayPos + _ProjectionParams.y * i.rayDir;
					float3 rd = i.rayDir;

					float size = i.centerPos.w;
					float minSize = i.meshSize.w;

					float3 farPoint = GetRayPoint(-rd, i.screenPos.xy / i.screenPos.w);

					float4 q = i.meshQuaternion;
					float3 pos = i.centerPos;

					q.xyz= -q.xyz;
					float3 lineDirection = Rotate(float3(0,0,1),q);

					float toDepth;
					float combinedDistance = GetDistanceToSegment(ro, rd, pos, lineDirection,  size * 0.6, farPoint, toDepth);

					float gyroid = LaserGyroid(farPoint + lineDirection * toDepth, 4) ; 

					float fadeCoefficient = 30/minSize;

					float scaleFade = saturate(size * 4 / length(pos - ro));

					float alpha = (1 / (1 + combinedDistance*fadeCoefficient) +
					smoothstep(-2,2,gyroid)/(1+toDepth*fadeCoefficient));

					alpha = saturate(alpha * scaleFade);

					float4 col = lerp( _FadeColor,_Color, smoothstep(0.25, 1, alpha)) * alpha * alpha;

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

