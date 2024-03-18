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

                if (length(max(0,abs(uv-0.5) - 0.45)) > 0)
                    return tex2Dlod(_MainTex, float4(i.uv, 0, 0));

                float2 pixelSize = _MainTex_TexelSize.xy * 1.5;

                float4 col =0;// tex2Dlod(_MainTex, float4(i.uv, 0, 0));

                float4 avg = 0;

                float sum = 0;

                float4 center = tex2Dlod(_MainTex, float4(i.uv, 0, 0));

                for (float x = -3; x<=3; x++)
                {
                    for (float y = -3; y<=3; y++)
                    {   
                        float off =  float2(x,y);

                        float alpha = 6/(6 + length(off));

                        float4 neihbour = tex2Dlod(_MainTex, float4(i.uv + pixelSize * off, 0, 0)) * alpha;

                         center = max(center,neihbour);
                         avg += neihbour;
                       // col += tex2Dlod(_MainTex, float4(i.uv + pixelSize * off, 0, 0)) * alpha;
                        sum += alpha;
                    }
                }
           
                return center; //avg / sum;
            }
            ENDCG
        }
    }
}
