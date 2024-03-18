Shader "Unlit/Fog Layers Baking"
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
         //   #pragma multi_compile_fog

			#pragma multi_compile ___ qc_LAYARED_FOG
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
                o.uv = v.uv; //TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }



            sampler2D qc_DepthMax;
            float4 qc_DepthMax_TexelSize;

            inline float GetSceneDepth(float2 uv)
            {
	            return tex2Dlod(qc_DepthMax, float4(uv, 0,0));
            }


            float4 frag (v2f i) : SV_Target
            {
               // float3 ro = GetRayPoint(-i.rayDir, i.screenPos.xy / i.screenPos.w);

               //float2 upscaledUv = i.uv * 4;
              // float2 indexXY = floor(upscaledUv);
               float index;
               i.uv = GetLayerUvs (i.uv, index); //upscaledUv - indexXY;

              // float index = indexXY.y * 4 + indexXY.x;
               // _Global_Noise_Lookup

             //  float4 noise = tex2Dlod(_Global_Noise_Lookup, 
				//	float4(i.uv * (123.12345678) + float2(_SinTime.x, _CosTime.y + i.uv.y) * 32.12345612, 0, 0));


               float3 from = _WorldSpaceCameraPos;

            	float depth = GetSceneDepth(i.uv);

				float3 finish = ReconstructWorldSpacePositionFromDepth(i.uv, depth); // Is Correct

                float3 toPosVec = finish - from;

				float len = min(length(toPosVec), qc_LayeredFog_Distance);

                float offset = GetDither(qc_DepthMax_TexelSize.zw * i.uv); // +float2(index*9, index*11));

               // offset = offset * noise.x + (1-offset) * noise.y;

				float3 rayStart = from; // UNITY_MATRIX_I_V._m03_m13_m23;//GetAbsoluteWorldSpacePos(); 

				float3 rayDir = normalize(toPosVec);
				
                float segmentStart;
                float segmentEnd;

                GetFogLayerSegment(index, segmentStart, segmentEnd);

                if (segmentStart > len)
                    return 0;

                float fullSegmentLength = segmentEnd - segmentStart;

                float length = min(segmentEnd, len) - segmentStart;

				return TraceVolumetricSegment(rayStart, rayDir, length, index, segmentStart, fullSegmentLength, offset);
            }
            ENDCG
        }
    }
}
