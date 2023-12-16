Shader "Cryptopia/Terrain/Flat"
{
    Properties
    {
       
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
                float3 worldPos : 	TEXCOORD1;
                 float3 viewDir : TEXCOORD2;
                   SHADOW_COORDS(3)
            };

            v2f vert (appdata_full v)
            {
                v2f o;
                	UNITY_SETUP_INSTANCE_ID(v);
                 o.pos = UnityObjectToClipPos(v.vertex);
                float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
                 o.worldPos = worldPos;
                TRANSFER_SHADOW(o);
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
          
              ApplyRefraction(i.worldPos, i.viewDir);

              float3 normal;
              float4 control = Ct_SampleTerrainAndNormal(i.worldPos, normal);



          //   return (control.r * control.g + control.r * control.b + control.g * control.b) * 100;

              float height = GetTerrainHeight(control);


                float4 mads;
                float3 col = GetTerrainBlend(i.worldPos, control, mads, normal);

              // col = UNITY_SAMPLE_TEX2DARRAY(civ_Albedo_Arr, float3(i.worldPos.xz, 0)).rgb;

                float shadow = SHADOW_ATTENUATION(i);

            /*  float isUnderwater = smoothstep(0, -5, height);

              col = lerp(col, float4(0.2,0.3,1,0), isUnderwater);
              normal = lerp(normal, float3(0,1,0), isUnderwater);
              mads = lerp(mads, float4(0,1,1,1), isUnderwater);*/


              i.worldPos.y = height;

              float foam;
              ApplyWater(i.worldPos, col,  normal,  mads, foam);

              ApplyLight(col, normal, mads, shadow);
            
              float fresnel = max(0, 1- dot(normal, i.viewDir));

             // return fresnel;

             col = lerp(col, float4(0.5,0.5,1,0) ,fresnel * mads.a * 0.5);

              ApplyFoam(col, mads, foam);

                   return float4(col,1);
            }



            ENDCG
        }



         UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

    }
}
