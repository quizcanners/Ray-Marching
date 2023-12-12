Shader "Cryptopia/Terrain_Deforming"
{
    Properties
    {
        //_MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque+10" }
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
                float2 uv : TEXCOORD0;
                float3 worldPos : 	TEXCOORD1;
                SHADOW_COORDS(2)
                 float3 viewDir : TEXCOORD3;
                 
            };

          //  sampler2D _MainTex;
           // float4 _MainTex_ST;

            v2f vert (appdata_full v)
            {
                v2f o;
               
                float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
                worldPos = SampleTerrainPosition(worldPos);
                v.vertex = mul(unity_WorldToObject, float4(worldPos, v.vertex.w));
                  o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
                o.pos = UnityObjectToClipPos(v.vertex);
                //o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                TRANSFER_SHADOW(o);
                o.worldPos = worldPos;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
            
                i.viewDir = normalize(i.viewDir);

              //  fixed4 col = tex2D(_MainTex, i.uv);
              float3 normal;
              float4 terrainControl = Ct_SampleTerrainAndNormal(i.worldPos, normal);

              float height = GetTerrainHeight(terrainControl);

                float4 mads;
                float3 col = GetTerrainBlend(i.worldPos, terrainControl, mads, normal);

                
              //  return mads;
           
                float shadow = SHADOW_ATTENUATION(i);

               ApplyLight(col, normal, mads, shadow);
                col +=  GetSpecular(normal, i.viewDir, mads);
              // return mads.g;

                   return float4(col,1);
            }
            ENDCG
        }

        Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			ZWrite On ZTest LEqual Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile_instancing
			#pragma multi_compile_shadowcaster
			

			struct v2f 
            {
				//float2 texcoord1 : TEXCOORD2;
				V2F_SHADOW_CASTER;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert(appdata_full v)
			{
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);

				float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
                v.vertex = mul(unity_WorldToObject, float4(SampleTerrainPosition(worldPos), v.vertex.w));

				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)

				return o;
			}

			float4 frag(v2f o) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(o)
			}
			ENDCG
		}
    }
}
