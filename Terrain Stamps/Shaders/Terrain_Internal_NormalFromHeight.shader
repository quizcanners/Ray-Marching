Shader "QcRendering/Terrain/Internal/Terrain_NormalFromHeight"
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

            float _HeightVisibility;
            float _BiomeVisibility;

        //    float4 Ct_Control_Previous_ST;
         //   float4 Ct_Control_Previous_TexelSize;

         float IsWater (float4 control)
         {
         float terrainHeight;
         GetTerrainHeight(control, terrainHeight);
            return smoothstep(-0.1, 0.1, Ct_WaterLevel.x - terrainHeight);
         }

            void AddNormal(inout float2 bump, inout float toWater, inout float toTerrain, inout float totalPower, float center, float2 uv, float kernelX, float kernelY, float power)
            {
                float2 d = _MainTex_TexelSize.xy;

                float4 pix = tex2Dlod(_MainTex, float4(uv + float2(kernelX * d.x, kernelY* d.y)  ,0,0)).a;

                float diff = center - pix.a;

                float isWater = IsWater(pix); //smoothstep(-0.1, 0.1, Ct_WaterLevel.x - GetTerrainHeight(pix)); 

                float distanceToPixel = length(float2(kernelX, kernelY));

                toWater = lerp(toWater, min(toWater, distanceToPixel),isWater);
                toTerrain = lerp(toTerrain, min(toTerrain, distanceToPixel), 1-isWater);

                bump += float2(kernelX, kernelY) * diff * power;
                totalPower += power;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv;

                float4 center = tex2Dlod(_MainTex, float4(uv,0,0)).a;

                float2 bump = 0;
                float totalPower = 0;
                float toWater = length(float2(3,2)); // 159
                float toTerrain = toWater;
                // If resolution is < 1 pixel per meter, the sampling distance will decrease
                float distanceCoefficient = 1; // min(1.0,Ct_Size_Bake.x * _MainTex_TexelSize.x); // 256 area / 1024 pixels 
    
                #define GRABPIXEL(kernelX, kernelY, weight) AddNormal(bump, toWater, toTerrain, totalPower, center.a, uv, kernelX * distanceCoefficient, kernelY * distanceCoefficient, weight);

                // Using Gaussian Blur coefficients
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

                float water = IsWater(center);

                float sdf = lerp(toWater, -toTerrain,water);

                bump /= totalPower;
                bump *= Ct_HeightRange.z;
            
                float3 normal = normalize(float3(bump.x, 1, bump.y));

               // #define GRABPIXEL(kernelX, kernelY, float weight) normalDirection += tex2Dlod(Ct_Control_Previous, float4(uv + float2(kernelX*xker, kernelY*yker)  ,0,0)); \
                 //   totalPower += weight;

               return float4 (normal, sdf);
            }
            ENDCG
        }
    }
}
