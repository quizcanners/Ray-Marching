Shader "QcRendering/Terrain/Internal/Terrain_Internal_Smooth"
{
     Properties
    {
        _MainTex("Main Texture", 2D) = "black"{}
    }

    SubShader{

        Tags 
        { 
            "Queue" = "Overlay" 
        }

        LOD 10
        ColorMask RGBA
        Cull Off
        ZTest Always
        ZWrite Off

        Pass
        {

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
		    #include "UnityCG.cginc"
            #include "Qc_TerrainCommon.cginc"


            struct v2f {
              float4 pos        : SV_POSITION;
              float2 texcoord   : TEXCOORD1;
            };

            v2f vert(appdata_full v) 
            {
              v2f o;
              o.pos = UnityObjectToClipPos(v.vertex);
              o.texcoord.xy = v.texcoord.xy;

              return o;
            }

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            uniform sampler2D Ct_NoiseTex;
            float4 Ct_BleedBlurAmount;

            void GrabPixel(inout float4 totalVal, inout float totalPower,  float2 uv, float kernelX, float kernelY, float delta, float power)
            {
                //float2 d = _MainTex_TexelSize.xy * 1.5;

                float4 noise = tex2Dlod(Ct_NoiseTex, float4(sin(uv * 12.345 + float2(kernelX, kernelY) * float2(12.4567, 23.45678)),0,0));

                noise -=0.5;

                float2 offsetUv = uv + float2(kernelX + noise.b, kernelY + noise.r) * delta;

                offsetUv = saturate(offsetUv);

                float4 pix = tex2Dlod(_MainTex, float4(offsetUv ,0,0)); // + noise * 0.1;

                pix.rgb += noise.rgb * 0.1;

                totalVal += pix * power;
                totalPower += power;
            }


            float4 frag(v2f i) : SV_TARGET
            {
           		float2 uv = i.texcoord.xy;

                float4 maxVal = 0; 
                float totalPower = 0;
                float bluriness =Ct_BleedBlurAmount.y * Ct_Size_Bake.y;

                float beaching = 0;

                #define GRABPIXEL(kernelX, kernelY, weight)  GrabPixel(maxVal, totalPower, uv, kernelX, kernelY, bluriness, weight + beaching);

                // Using Gaussian Blur coefficients
                GRABPIXEL(0, 0 ,159)

               // float isWater = smoothstep(-2, 1, Ct_WaterLevel.x - GetTerrainHeight(maxVal));// IsWater (maxVal);

                GRABPIXEL(-1,  0 , 97)
                GRABPIXEL( 1,  0 , 97)
                GRABPIXEL( 0,  1 , 97)
                GRABPIXEL( 0, -1, 97)

                GRABPIXEL(-1,  1, 59)
                GRABPIXEL( 1, -1, 59)
                GRABPIXEL( 1,  1, 59)
                GRABPIXEL(-1, -1, 59)
                
                GRABPIXEL(-2,  0, 22)
                GRABPIXEL( 0, -2, 22)
                GRABPIXEL( 2,  0, 22)
                GRABPIXEL( 0,  2, 22)

                GRABPIXEL(-2,  1, 13)
                GRABPIXEL( 1, -2, 13 )
                GRABPIXEL( 2,  1, 13 )
                GRABPIXEL( 1,  2, 13 )

                GRABPIXEL(-2,  -1, 13 )
                GRABPIXEL( -1, -2, 13 )
                GRABPIXEL( 2,  -1, 13 )
                GRABPIXEL( -1,  2, 13 )

                GRABPIXEL(-2, -2, 3 )
                GRABPIXEL( 2,  2, 3 )
                GRABPIXEL( 2, -2, 3 )
                GRABPIXEL(-2,  2, 3 )

                GRABPIXEL( 0, -3, 2 )
                GRABPIXEL( 0,  3, 2 )
                GRABPIXEL(-3,  0, 2 )
                GRABPIXEL( 3,  0, 2 )

                GRABPIXEL( 1, -3, 1 )
                GRABPIXEL( 1,  3, 1 )
                GRABPIXEL(-3,  1, 1 )
                GRABPIXEL( 3,  1, 1 )

                GRABPIXEL(-1, -3, 1 )
                GRABPIXEL(-1,  3, 1 )
                GRABPIXEL(-3, -1, 1 )
                GRABPIXEL( 3, -1, 1 )

                maxVal /= totalPower;

               // return tex2Dlod(Ct_NoiseTex, float4(sin(uv* 123.456 + float2(1, 2) * float2(12.4567, 23.45678)),0,0));

                return maxVal;
            }
             ENDCG
        }
    }
      FallBack Off
}
