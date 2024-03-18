Shader "QcRendering/Terrain/Internal/Terrain_Internal_RetractGrassFromWater"
{
     Properties
    {
        _MainTex("Main Texture", 2D) = "black"{}
    }

    SubShader{

        Tags 
        { 
            "Queue" = "Overlay" 
        }

        LOD 10
        ColorMask RGBA
        Cull Off
        ZTest Always
        ZWrite Off

        Pass
        {

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
		    #include "UnityCG.cginc"
            #include "Qc_TerrainCommon.cginc"

            struct v2f 
            {
              float4 pos        : SV_POSITION;
              float2 texcoord   : TEXCOORD1;
            };

            v2f vert(appdata_full v) 
            {
              v2f o;
              o.pos = UnityObjectToClipPos(v.vertex);
              o.texcoord.xy = v.texcoord.xy;

              return o;
            }

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            //sampler2D _Ct_Normal;

            float4 frag(v2f i) : SV_TARGET
            {
           		float2 uv = i.texcoord.xy;

                float4 terrainControl = tex2Dlod(_MainTex, float4(uv,0,0));

                float4 bumpAndSdf = tex2Dlod(_Ct_Normal, float4(uv,0,0));

                float height;
                GetTerrainHeight(terrainControl, height);

               float notTooHigh = smoothstep(0.3,0,height - Ct_WaterLevel.x);

                //float nearWater = smoothstep(0, -1, bumpAndSdf.a);

                float nearWater = smoothstep(4, 0, bumpAndSdf.a);// * notTooHigh;

            //    terrainControl.gb = lerp(terrainControl.gb, float2(1,0), smoothstep(4, -1, bumpAndSdf.a) * (1-notTooHigh));

                terrainControl.rgb = lerp(terrainControl.rgb, float3(0,0,1), nearWater * notTooHigh);

                return terrainControl;
            }
             ENDCG
        }
    }
      FallBack Off
}
