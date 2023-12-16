Shader "RayTracing/Decal/Simple"
{
	Properties
	{
		[NoScaleOffset] _MainTex("Texture", 2D) = "white" {}
		_BumpMap("Bump", 2D) = "bump" {}
	}

	SubShader{
		Tags
		{ 
			"Queue" = "Geometry+10"
			//"IgnoreProjector" = "True"
			//"RenderType" = "Transparent"
		
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

			#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Sampler.cginc"
			#include "Assets/Qc_Rendering/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Qc_Rendering/Shaders/RayMarching_Forward_Integration.cginc"
			#include "Assets/Qc_Rendering/Shaders/Sampler_TopDownLight.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing

			#pragma multi_compile_fwdbase
			//#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

			sampler2D _MainTex;
			sampler2D _BumpMap;

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
				//float2 topdownUv : TEXCOORD7;
				//fixed4 color : COLOR;
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

				float2 uv = relativePosition.xy * i.upscaleProjection;
			
				float4 col = tex2D(_MainTex, uv + 0.5);

				col.a *= center;

				float shadow = getShadowAttenuation(newPos);

				float3 _lightColor = _LightColor0.rgb * shadow;

				float oob;
				float4 vlm = SampleVolume(newPos, oob);
				//vlm.rgb = lerp(vlm.rgb, GetAvarageAmbient(o.normal.xyz), oob);


				TopDownSample(newPos, vlm.rgb);

				col.rgb *= _lightColor + vlm.rgb;

				ApplyBottomFog(col.rgb, newPos, i.viewDir.y);

				
				return col;
			}

			ENDCG
		}
		//UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
	}
}