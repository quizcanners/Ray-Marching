Shader "RayTracing/Internal/Low Resolution Depth"
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

            float4 _CameraDepthTexture_TexelSize;
            sampler2D_float _CameraDepthTexture;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv; //TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }


            inline void Process(inout float sum, inout float nearest, float2 uv)
            {
                float result = tex2D(_CameraDepthTexture, uv).r;
                sum += result;
                nearest = max(nearest, result);
            }



            float frag (v2f i) : SV_Target
            {
                float2 off = _CameraDepthTexture_TexelSize.xy * 2.5;

                float sum = 0; //tex2D(_CameraDepthTexture, i.uv).r;
                float nearest = sum;

               #define SAMPLE_D(OFF) Process(sum, nearest, i.uv + OFF);

               /*
               SAMPLE_D(float2(0, off.y))
               SAMPLE_D(float2(0, -off.y))
               SAMPLE_D(float2(off.x, 0))
               SAMPLE_D(float2(-off.x, 0))
               SAMPLE_D(float2(off.x, -off.y))
               SAMPLE_D(float2(-off.x, -off.y))
               SAMPLE_D(float2(off.x, off.y))
               SAMPLE_D(float2(-off.x, off.y))*/

               
                float xker = off.x;
                float yker = off.y;

               		#define GRABPIXELX(weight,kernel) nearest = max(nearest, tex2Dlod( _CameraDepthTexture, float4(i.uv + float2(kernel*xker, 0)  ,0,0))); // * weight

					#define GRABPIXELY(weight,kernel) nearest = max(nearest, tex2Dlod( _CameraDepthTexture, float4(i.uv + float2(0, kernel*yker)  ,0,0)));// * weight


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



              //  sum /= 5;

                return nearest;
            }
            ENDCG
        }
    }
}
