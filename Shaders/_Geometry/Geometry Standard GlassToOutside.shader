Shader "QcRendering/Geometry/Glass Show Skybox"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		[Toggle(_ONLY_SKY)] traceSkyOnly ("Don't ray trace geometry'", Float) = 0  
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
				#pragma shader_feature_local   ___ _ONLY_SKY

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
					float ao = SampleSSAO(screenUV);
					float3 refractedRay = refract(-viewDir, normal, 0.75);
					float smoothness = 1;
					float shadow = 1;
					float3 sky = getSkyColor(-viewDir, shadow);//SampleSkyBox(refractedRay, smoothness);
					float3 col = sky; 
					ApplyBottomFog(col.rgb, i.worldPos, viewDir.y);

					float4 result = float4(col,1);

					return float4(col,1);
				}
				ENDCG
			}
			UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
		}
		Fallback "Diffuse"
	}
}