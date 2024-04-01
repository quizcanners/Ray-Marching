Shader "QcRendering/Terrain/Internal/Terrain_ExpandSDF"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "black"{}
    }

    SubShader
    {
        Tags 
        { 
			"IgnoreProjector" = "True"
			"RenderType" = "Opaque" 
            "Queue" = "Geometry" 
        }

        ColorMask RGBA
		ZTest Off
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_instancing
            #include "UnityCG.cginc"
            #include "Qc_TerrainCommon.cginc"


            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldPos : 	TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;

            v2f vert (appdata_full v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
                o.worldPos = worldPos;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord; 
                return o;
            }

            void ExtendSdf(inout float toWater, inout float toTerrain, float isWater, float2 uv, float kernelX, float kernelY)
            {
                float2 d = _MainTex_TexelSize.xy;

                float4 pix = tex2Dlod(_MainTex, float4(uv + float2(kernelX * d.x, kernelY* d.y)  ,0,0));

                float distanceToPixel = length(float2(kernelX, kernelY));

                float pixIsWater = step(pix.a, 0);

                if (pix.a <= 0)
                {
                    toTerrain = min(toTerrain, distanceToPixel - pix.a);
                } else 
                {
                    toWater = min(toWater, distanceToPixel + pix.a);
                }
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv;

                float4 center = tex2Dlod(_MainTex, float4(uv,0,0));
                float currentIsWater = step(center.a, 0);

                 float distanceCoefficient = 3;

                 float currentHeight = center.a;

                float toTerrain = CT_SDF_RANGE; // 50 * currentIsWater;
                float toWater = CT_SDF_RANGE; //currentHeight * (1-currentIsWater);
               
    
                #define GRABPIXEL(kernelX, kernelY, weight) ExtendSdf(toWater, toTerrain, currentIsWater,  uv, kernelX * distanceCoefficient, kernelY * distanceCoefficient);

                for (int x = -5; x<=5; x++)
                   for (int y = -5; y<=5; y++)
                      GRABPIXEL(x,  y , 97)

                // Using Gaussian Blur coefficients
           /*     GRABPIXEL(-1,  0 , 97)
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
                GRABPIXEL( 3, -1, 1)*/

          

                float sdf = lerp(toWater, -toTerrain, currentIsWater);

                center.a = sdf;
             
               return center;
            }
            ENDCG
        }
    }
}
