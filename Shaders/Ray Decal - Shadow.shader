Shader "RayTracing/Decal/Shadow"
{
	Properties
	{
		[KeywordEnum(Sphere, Box)]	SHAPE("Shape", Float) = 0
		_Color("Color", Color) = (1,1,1,1)
		_Softness("Softness", Range(0,1)) = 0.5
	}

	SubShader{
		Tags
		{ 
			"Queue" = "Geometry+10" 
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
			"LightMode" = "ForwardBase"
		}

		Blend SrcAlpha OneMinusSrcAlpha
		ZWrite Off
		ZTest Off
		Cull Front

		Pass
		{
			CGPROGRAM

			#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Sampler.cginc"
			#include "Assets/Qc_Rendering/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Qc_Rendering/Shaders/RayMarching_Forward_Integration.cginc"
			#include "Assets/Qc_Rendering/Shaders/Sampler_TopDownLight.cginc"
		#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"

			#pragma vertex vert
			#pragma fragment frag
			//#pragma multi_compile_fwdbase
			#pragma multi_compile_instancing
			#pragma shader_feature_local SHAPE_SPHERE SHAPE_BOX 
			

			struct v2f 
			{
				float4 pos:				SV_POSITION;
				float4 screenPos :		TEXCOORD0;
				float3 viewDir :		TEXCOORD1;
				float3 meshPos :		TEXCOORD2;
				float4 meshSize :		TEXCOORD3;
				float4 meshQuaternion : TEXCOORD4;
				float4 centerPos :		TEXCOORD5;
				fixed4 color :			COLOR;
			};

			float4 _Color;


			v2f vert(appdata_full v) 
			{
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.screenPos = ComputeScreenPos(o.pos);

				//Find the view-space direction of the far clip plane from the camera (which, when interpolated, gives us per pixel view dir of the scene position)
				//o.viewDir = mul(unity_CameraInvProjection, float4 (o.screenPos.xy * 2.0 - 1.0, 1.0, 1.0));
				o.viewDir = WorldSpaceViewDir(v.vertex);
			
				o.meshPos = v.texcoord;
				o.meshSize = v.texcoord1;
				o.meshQuaternion = v.texcoord2;

				o.meshSize.w = min(o.meshSize.z, min(o.meshSize.x, o.meshSize.y));

				float maxSize = max(o.meshSize.z, max(o.meshSize.x, o.meshSize.y));

				o.centerPos = float4(o.meshPos.xyz, maxSize);

				o.color = v.color;
				return o;
			}

			//float _Size;
		
			float _Softness;

			float4 frag(v2f i) : COLOR
			{
			

				float3 viewDir = normalize(i.viewDir.xyz);
				float2 screenUv = i.screenPos.xy / i.screenPos.w;

				float3 newPos = GetRayPoint(viewDir, screenUv);


#if SHAPE_BOX
				float dist = CubeDistanceRot(
					newPos,
					i.meshQuaternion,
					i.centerPos,
					i.meshSize.xyz * 0.5,
					0.1);
#else
				float dist = length(newPos - i.centerPos) - i.meshSize.w * 0.5;
#endif

			

				float4 col = 0; 
				col.a = i.color.a;

				col.a *= smoothstep(0,-1 * i.meshSize.w * _Softness, dist);

				clip(col.a - 0.1);

				ApplyBottomFog(col.rgb, newPos, viewDir.y);

				
			

				return col;
			}

			ENDCG
		}
	}
	//Fallback "Diffuse"
}