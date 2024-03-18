Shader "QcRendering/Terrain/Complimentary"
{
    Properties
    {
         _BumpMap("Normal Map", 2D) = "bump" {}
         _AmbientMap("AO", 2D) = "white" {}
         _BlendHeight("Blend Height", Range(0,10)) = 1
        _BlendSharpness("Blend Sharpness", Range(0,1)) = 0
    }
    SubShader
    {
        Tags 
        { 
           "RenderType"="Geometry" 
        "Queue" = "Geometry+10"
        }
        LOD 100

        CGINCLUDE
        #pragma multi_compile_instancing
        #include "Qc_TerrainCommon.cginc"

        ENDCG

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog

            struct v2f
            {
                float4 pos			: SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : 	TEXCOORD1;
                  float4 wTangent		: TEXCOORD2;
                    float3 normal		: TEXCOORD3;
                SHADOW_COORDS(4)
                 float3 viewDir : TEXCOORD5;
            };

            v2f vert (appdata_full v)
            {
                v2f o;
               	UNITY_SETUP_INSTANCE_ID(v);
                 o.pos = UnityObjectToClipPos(v.vertex);
                float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
                 o.worldPos = worldPos;
                   o.normal.xyz = UnityObjectToWorldNormal(v.normal);
                     o.uv = v.texcoord;
                TRANSFER_SHADOW(o);
              TRANSFER_WTANGENT(o);
                 o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
                return o;
            }

            sampler2D _BumpMap;
            sampler2D _AmbientMap;
            float _BlendHeight;
            float _BlendSharpness;


            fixed4 frag (v2f i) : SV_Target
            {
               i.viewDir = normalize(i.viewDir);
              //  fixed4 col = tex2D(_MainTex, i.uv);
               float3 bump = UnpackNormal(tex2D(_BumpMap, i.uv));
              
              float3 normal;
              float4 terrainControl = Ct_SampleTerrainAndNormal(i.worldPos, normal);

              float height = GetTerrainHeight(terrainControl);

                float4 mads;
                float3 col = GetTerrainBlend(i.worldPos, terrainControl, mads, normal);



                 float3 objectNormal = i.normal.xyz;

                 ApplyTangent (objectNormal, bump, i.wTangent);

             

                float isUp = smoothstep(0.4,0.6, objectNormal.y);

                float diff = (i.worldPos.y- height);
                float transition = smoothstep(_BlendHeight * _BlendSharpness * 0.99, _BlendHeight, diff);


                 normal = normalize(lerp(normal, i.normal.xyz, transition));

                normal = normalize(lerp(normal, objectNormal, transition + transition * (1-isUp) * (1-transition)));
                mads.g = lerp(  mads.g, tex2D(_AmbientMap, i.uv),transition);
           

                float shadow = SHADOW_ATTENUATION(i);

               ApplyLight(col, normal, mads, shadow);

                   return float4(col,1);
            }
            ENDCG
        }



         UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

    }
}
