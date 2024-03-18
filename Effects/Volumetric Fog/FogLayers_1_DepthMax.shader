Shader "Unlit/Fog Layers Depth Max"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
           // #pragma multi_compile_fog

			#pragma multi_compile ___ qc_KWS_ASFOG
			#pragma multi_compile ___ _qc_IGNORE_SKY
			#pragma multi_compile __ _qc_USE_RAIN 

            #include "Assets/Qc_Rendering/Shaders/Savage_Baker_VolumetricFog.cginc"
          	#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"
            #include "Assets/Qc_Rendering/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Qc_Rendering/Shaders/RayMarching_Forward_Integration.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
            	float depth = 99999;
                
                float2 off = _CameraDepthTexture_TexelSize.xy * 1.5;

                for (float x = -2; x<2; x++)
                {
                    for (float y = -2; y<2; y++)
                    {
                        float4 smpl = float4(i.uv + float2(off.x * x, off.y * y), 0,0);

                        float newDepth = tex2Dlod(_CameraDepthTexture, smpl).r;

                        depth = min(newDepth, depth);
                    }
                }

                return depth;

            }
            ENDCG
        }
    }
}
