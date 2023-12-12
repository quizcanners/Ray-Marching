Shader "RayTracing/Debug/Show Top-Down Lights and Shadows"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        Pass {

            CGPROGRAM
            #include "Assets/The-Fire-Below/Common/Shaders/quizcanners_built_in.cginc"
           #pragma vertex vert
           #pragma fragment frag

           struct v2f {
                    float4 pos : 		SV_POSITION;
                    float3 viewDir: 	TEXCOORD0;
                    float2 texcoord : TEXCOORD1;
                    float3 worldPos : TEXCOORD2;
                };



            float4 _RayTracing_TopDownBuffer_Position;

            v2f vert(appdata_full v) 
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.texcoord = (o.worldPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;
              
                return o;
            }

            sampler2D _RayTracing_TopDownBuffer;

            float4 frag(v2f o) : COLOR
            {
         
                float4 col = tex2Dlod(_RayTracing_TopDownBuffer, float4(o.texcoord,0,0));
                  
                col.rgb = lerp(0.5, 0, col.a) + col.rgb;

                return col;
            }

            ENDCG
        }
    }
    FallBack "Diffuse"
}
