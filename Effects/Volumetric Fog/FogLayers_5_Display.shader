Shader "Unlit/Fog Layers Display"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        ZWrite Off

        Pass
        {
         Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile __ qc_LAYARED_FOG

            #include "UnityCG.cginc"
           
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
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }


            float4 SampleLayeredFog_Test(float distance, float2 uv)
            {
	            #if !qc_LAYARED_FOG
		            return 0;
	            #endif

	            distance = min(distance, qc_LayeredFog_Distance);

	            float index;
                float fraction;
                GetFogLayerIndexFromDistance(distance, index, fraction);
	
                //return fraction;

	            float2 internalUv = uv / 4;

	            float y = floor(index/4);
                float x = index - y*4;
	            float4 last = tex2Dlod(qc_FogLayers, float4(float2(x,y)*0.25 + internalUv, 0, 0));

	            index--;
	            y = floor(index/4);
                x = index - y*4;
	            float4 previous = tex2Dlod(qc_FogLayers, float4(float2(x,y)*0.25 + internalUv, 0, 0));

	            float4 result =  lerp(previous, last, fraction);

	            return result;
            }

            float4 frag (v2f i) : SV_Target
            {
                float depth = tex2Dlod(_CameraDepthTexture, float4(i.uv, 0,0));

				float3 finish = ReconstructWorldSpacePositionFromDepth(i.uv, depth); 

                float distance = length(_WorldSpaceCameraPos - finish);

                /*
                float4 debug = tex2Dlod(_MainTex, float4(i.uv, 0, 0));
               debug.a = 1;
              return debug;*/

              //  distance = min(distance,500);

               // return smoothstep(0,100, distance);

                return SampleLayeredFog_Test(distance, i.uv);

            }
            ENDCG
        }
    }
}
