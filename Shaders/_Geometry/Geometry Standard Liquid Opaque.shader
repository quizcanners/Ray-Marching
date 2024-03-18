Shader "QcRendering/Geometry/Liquid Opaque"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
	}

	Category
	{
		SubShader
		{
			Pass
			{
				Tags
				{
					"Queue" = "Geometry+2"
					"RenderType" = "Opaque"
					"LightMode" = "ForwardBase"
				}

				ColorMask RGBA
				Cull Back

				CGPROGRAM

				#define RENDER_DYNAMICS

				//#pragma multi_compile __ RT_FROM_CUBEMAP 
				#pragma multi_compile ___ _qc_IGNORE_SKY

				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Transparent.cginc"
				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard_NoTracingPart.cginc"
				#include "AutoLight.cginc"


				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdbase
			

				struct v2f {
					float4 pos			: SV_POSITION;
					float3 worldPos		: TEXCOORD2;
					float3 normal		: TEXCOORD3;
					float4 wTangent		: TEXCOORD4;
					float3 viewDir		: TEXCOORD5;
					SHADOW_COORDS(6)
					float2 topdownUv : TEXCOORD7;
					float4 traced : TEXCOORD8;
					 float4 screenPos : TEXCOORD9;
					fixed4 color : COLOR;
				};


				v2f vert(appdata_full v) {
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					o.pos = UnityObjectToClipPos(v.vertex);
					
					o.worldPos = worldPos;
					o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					o.color = v.color;
					o.viewDir = WorldSpaceViewDir(v.vertex);
	

					o.traced = GetTraced_Glassy_Vertex(o.worldPos, normalize(o.viewDir.xyz), o.normal.xyz);
	
					o.screenPos = ComputeScreenPos(o.pos);

					TRANSFER_WTANGENT(o)
					TRANSFER_TOP_DOWN(o);
					TRANSFER_SHADOW(o);

					return o;
				}


				float4 _Color;

				float4 frag(v2f i) : COLOR
				{
					float2 screenUV = i.screenPos.xy / i.screenPos.w;
					float3 viewDir = normalize(i.viewDir.xyz);

					float3 normal = i.normal.xyz;

					float shadow = SHADOW_ATTENUATION(i) * i.traced.a; 

					float ao = SampleSSAO(screenUV);

					float3 refractedRay =  refract(-viewDir, normal, 0.75);

					i.traced.rgb += GetTranslucent_Sun(refractedRay) * shadow; 

					i.traced.rgb += GetDirectionalSpecular(normal, viewDir, 0.85) * GetDirectional();

					float outsideVolume;
				    float4 scene = SampleSDF(i.worldPos , outsideVolume);

				    float far = smoothstep(0,1, scene.a);

					float3 col = _qc_BloodColor.rgb * (1+ far) * 0.5 * i.traced.rgb * ao;

					ApplyBottomFog(col.rgb, i.worldPos, viewDir.y);

					return float4(col,1);

				}
				ENDCG
			}

			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

		}
		Fallback "Diffuse"
	}
}