Shader "RayTracing/Internal/Ambient Occlusion Second Pass"
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
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

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

            //sampler2D _MainTex;
            //float4 _MainTex_ST;

            float4 Qc_CameraDepthTextureLowRes_TexelSize;
            sampler2D_float Qc_CameraDepthTextureLowRes;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv; //TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }


            inline void Process(inout float sum, inout float nearest, float2 uv)
            {
                float result = tex2D(Qc_CameraDepthTextureLowRes, uv).r;
                sum += result;
                nearest = max(nearest, result);
            }



            float frag (v2f i) : SV_Target
            {
                float2 off = Qc_CameraDepthTextureLowRes_TexelSize.xy * 2.5;

                float sum = 0; // tex2D(Qc_CameraDepthTextureLowRes, i.uv).r;
                float nearest = sum;

                float xker = off.x;
                float yker = off.y;


               		#define GRABPIXELX(weight,kernel) nearest = max(nearest, tex2Dlod( Qc_CameraDepthTextureLowRes, float4(i.uv + float2(kernel*xker, 0)  ,0,0))); // * weight

					#define GRABPIXELY(weight,kernel) nearest = max(nearest, tex2Dlod( Qc_CameraDepthTextureLowRes, float4(i.uv + float2(0, kernel*yker)  ,0,0))); // * weight


				//	float4 sum = 0;

					sum += GRABPIXELX(0.05, -4.0);
					sum += GRABPIXELX(0.09, -3.0);
					sum += GRABPIXELX(0.12, -2.0);
					sum += GRABPIXELX(0.15, -1.0);
					sum += GRABPIXELX(0.18, 0.0);
					sum += GRABPIXELX(0.15, +1.0);
					sum += GRABPIXELX(0.12, +2.0);
					sum += GRABPIXELX(0.09, +3.0);
					sum += GRABPIXELX(0.05, +4.0);

				
				
					sum += GRABPIXELY(0.05, -4.0);
					sum += GRABPIXELY(0.09, -3.0);
					sum += GRABPIXELY(0.12, -2.0);
					sum += GRABPIXELY(0.15, -1.0);
					sum += GRABPIXELY(0.18, 0.0);
					sum += GRABPIXELY(0.15, +1.0);
					sum += GRABPIXELY(0.12, +2.0);
					sum += GRABPIXELY(0.09, +3.0);
					sum += GRABPIXELY(0.05, +4.0);

					sum *= 0.5;




                return nearest;
            }
            ENDCG
        }
    }
}
