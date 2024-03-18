Shader "RayTracing/Baker/SDF Field"
{
   Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
	}

	SubShader
	{

		Tags
		{
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
		}

		ColorMask RGBA
		Cull Off
		ZWrite Off
		ZTest Off
		//Blend One Zero

		Pass
		{

			CGPROGRAM

			#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_SDF.cginc"
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma fragment frag


			struct v2f 
			{
				float4 pos : 		SV_POSITION;
				float2 texcoord : TEXCOORD0;
			};

			float4 _Effect_Time;
	
			v2f vert(appdata_full v) 
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.texcoord = v.texcoord.xy;

				return o;
			}

			float4 frag(v2f o) : SV_TARGET
			{
				float3 worldPos = volumeUVtoWorld(o.texcoord.xy);

				float4 nrmDist = NormalAndDistance_Exact(worldPos);

				return nrmDist;
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}