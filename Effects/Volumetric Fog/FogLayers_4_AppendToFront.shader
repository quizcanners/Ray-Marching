Shader "Unlit/Append To Front"
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

            #include "Assets/Qc_Rendering/Shaders/Savage_Baker_VolumetricFog.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float index;
                float2 uv = GetLayerUvs (i.uv, index); 

                float4 col;

                float remainingAlpha = 1;

                float distPower = 3 - qc_LayeredFog_Alpha * 2;

                float transprencyStep = qc_LayeredFog_Alpha / pow(16, distPower);

                for (float i = 0; i<=index; i++)
                {
                    float y = floor(i/4); //floor(index/4);
                    float x = i - y * 4;

                    float pixel = _MainTex_TexelSize.xy;

                    float4 checking = tex2Dlod(_MainTex, float4((float2(x,y) + uv) * 0.25,0,0));

                    float brightness = checking.a; //* saturate(10 * length(checking.rgb));

                  //  checking.rgb *= checking.a;
                    float layerAlpha = remainingAlpha * brightness *  transprencyStep * pow(1+i, distPower);

                    remainingAlpha -= layerAlpha;

                    checking.a = layerAlpha;
                    checking.rgb *= layerAlpha;

                    col+= checking;
                }

                return col;
            }
            ENDCG
        }
    }
}
