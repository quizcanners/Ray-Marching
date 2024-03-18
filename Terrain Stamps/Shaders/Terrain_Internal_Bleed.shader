Shader "QcRendering/Terrain/Internal/Terrain_Internal_Bleed"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "black"{}
    }

    SubShader
    {
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

            struct v2f 
            {
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
            sampler2D Ct_NoiseTex;
        //    float4 Ct_Size_Bake;

            float4 Ct_BleedBlurAmount;

            void GrabPixel(inout float4 maxVal, float2 uv, float kernelX, float kernelY, float delta, float power, float beaching)
            {
                //float2 d = _MainTex_TexelSize.xy;
                float4 noise = tex2Dlod(Ct_NoiseTex, float4(sin( uv * 123 + _Time.x + float2(kernelX, kernelY) * float2(43.45, 34.45)),0,0));

                noise -=0.5;

                float2 offsetUv = uv + float2(kernelX + noise.r, kernelY + noise.g) * delta;

                offsetUv = saturate(offsetUv);

                float4 pix = tex2Dlod(_MainTex, float4(offsetUv, 0, 0));

                maxVal = max(maxVal, pix * ((power + beaching)/(97.0 + beaching)));
            }

            float4 frag(v2f i) : SV_TARGET
            {
           		float2 uv = i.texcoord.xy;

                float4 maxVal = 0; 
                float bluriness = Ct_BleedBlurAmount.x * Ct_Size_Bake.y;
              
              float beaching = 0;

                #define GRABPIXEL(kernelX, kernelY, weight)  GrabPixel(maxVal, uv, kernelX, kernelY, bluriness, weight, beaching);

                // Using Gaussian Blur coefficients
                //GRABPIXEL(0, 0 ,41)

                float4 center = tex2Dlod(_MainTex, float4(uv  ,0,0));
                maxVal = center;

                float terHeight;
                GetTerrainHeight(maxVal, terHeight);

                float isWater = smoothstep(0, 1, Ct_WaterLevel.x - terHeight);

                beaching = 0; // isWater * 2;
                bluriness = 1; // + 5 * isWater;

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
                GRABPIXEL( 1, -2, 13)
                GRABPIXEL( 2,  1, 13)
                GRABPIXEL( 1,  2, 13)

                GRABPIXEL(-2,  -1, 13)
                GRABPIXEL( -1, -2, 13)
                GRABPIXEL( 2,  -1, 13)
                GRABPIXEL( -1,  2, 13)

                GRABPIXEL(-2, -2, 3)
                GRABPIXEL( 2,  2, 3)
                GRABPIXEL( 2, -2, 3)
                GRABPIXEL(-2,  2, 3)

                GRABPIXEL( 0, -3, 2)
                GRABPIXEL( 0,  3, 2)
                GRABPIXEL(-3,  0, 2)
                GRABPIXEL( 3,  0, 2)

                GRABPIXEL( 1, -3, 1)
                GRABPIXEL( 1,  3, 1)
                GRABPIXEL(-3,  1, 1)
                GRABPIXEL( 3,  1, 1)

                GRABPIXEL(-1, -3, 1)
                GRABPIXEL(-1,  3, 1)
                GRABPIXEL(-3, -1, 1)
                GRABPIXEL( 3, -1, 1)

               // float terrrainHeight = GetTerrainHeight(maxVal.a);

               // float tooHigh = smoothstep(-0.2, 0.2, terrrainHeight - Ct_WaterLevel.x);
             //   maxVal.a = lerp(maxVal.a, HeightToColor(Ct_WaterLevel.x), isWater * tooHigh);

                return maxVal;
            }
            ENDCG
        }
    }
    FallBack Off
}
