Shader "Cryptopia/Terrain/Integration"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BlendMap("Blend Map", 2D) = "black" {}
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

            #include "Ct_TerrainCommon.cginc"

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
                float2 texcoord : TEXCOORD0;
                float3 worldPos : 	TEXCOORD1;
                float4 wTangent		: TEXCOORD2;
                float3 normal		: TEXCOORD3;
                float3 viewDir : TEXCOORD4;
                SHADOW_COORDS(5)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata_full v)
            {
                v2f o;
               
                float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
                o.normal.xyz = UnityObjectToWorldNormal(v.normal);
                 o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.texcoord = v.texcoord;
                TRANSFER_SHADOW(o);
                o.worldPos = worldPos;
                TRANSFER_WTANGENT(o);

                return o;
            }

            sampler2D _BumpMap;
            sampler2D _SpecularMap;
            sampler2D _BlendMap;
            float _BlendHeight;
            float _BlendSharpness;

            fixed4 frag (v2f i) : SV_Target
            {
            
                i.viewDir = normalize(i.viewDir);

              float3 rawNormal;
              float4 terrainControl = Ct_SampleTerrainAndNormal(i.worldPos, rawNormal);

                float height = GetTerrainHeight(terrainControl);

                float3 terrainNormal = rawNormal;
                float4 mads;
                float3 col = GetTerrainBlend(i.worldPos, terrainControl, mads, terrainNormal);

                 fixed4 tex = tex2D(_MainTex, i.texcoord);
                 float3 bump = UnpackNormal(tex2D(_BumpMap, i.texcoord));
                 float4 objectMads = tex2D(_SpecularMap, i.texcoord);

                 float3 objectNormal = i.normal.xyz;
                 ApplyTangent (objectNormal, bump, i.wTangent);

                 float isUp = smoothstep(0,1, objectNormal.y);

                 float diff = (i.worldPos.y- height);

                 float4 blendMap = tex2D(_BlendMap, i.texcoord);

                 float objectDisplacement = objectMads.b;
                 float objectAO = objectMads.g;

                 float blendWeight = (1-blendMap.r) * diff; // Bland mask
                 blendWeight *= (4-isUp*3) * 0.25; // Verticality
                 blendWeight *= (0.5 + objectDisplacement * 0.5); // Displacement
                 blendWeight *= (4-objectAO*3); // Darker areas should preserve normal

                 float transition = smoothstep(_BlendHeight * _BlendSharpness * 0.99, _BlendHeight, blendWeight);


                col = lerp(col, tex, transition);
                mads = lerp(mads, objectMads, transition);

                float3 normal = normalize(lerp(terrainNormal, objectNormal, transition));

                
                float shadow = SHADOW_ATTENUATION(i);

                ApplyLight(col, normal, mads, shadow);

                return float4(col,1);
            }

 


            ENDCG
        }

   UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}
