Shader "QcRendering/Terrain/Internal/Stamp Content Aware"
{
    Properties
    {
        _MainTex ("Stamp", 2D) = "clear" {}
        [Toggle(_INVERT_ALPHA)] invertAlpha ("Invert Height", Float) = 0  
         [Toggle(_BlACK_N_WHITE)] whiteMask ("Mask is blck&White", Float) = 0
         [Toggle(_MASK_SMOOTHING)] maskSmoothing ("Mask Smoothing", Float) = 0
         _Height("Height Scale", Range(0,300)) = 10
        _HeightVisibility("Height Visibility", Range(0,1)) = 1
        _BiomeVisibility("Biome Visibility", Range(0,1)) = 1
        [KeywordEnum(Max, Min, Add, Alpha, Override, Subtract)]	MIX ("Blend Mode", Float) = 0
         _ColorSwap("Avverride color (when Alpha = 1)", Color) = (1,0,0,0)


         [KeywordEnum(Red, Alpha, StampAlpha, None)]	MASK ("Masking Mode", Float) = 0
         _MaskClipping("Mask Clipping", Range(0,1)) = 0.1
         _MaskOpaqueness("Mask Opaqueness", Range(0,1)) = 0.1
         _Mask ("Mask", 2D) = "white" {}
    }

    SubShader
    {
        Tags 
        { 
			"IgnoreProjector" = "True"
			"RenderType" = "Opaque" 
            "Queue" = "Geometry+10" 
              "Preview" = "Plane"
        }

        ColorMask RGBA
		Cull Back
		ZWrite On
		ZTest On
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local MIX_MAX MIX_MIN MIX_ADD MIX_ALPHA MIX_OVERRIDE  MIX_SUBTRACT
            #pragma shader_feature_local MASK_RED MASK_ALPHA MASK_STAMPALPHA MASK_NONE
            #pragma shader_feature_local ___ _INVERT_ALPHA
            #pragma shader_feature_local ___ _BlACK_N_WHITE
            #pragma shader_feature_local ___ _MASK_SMOOTHING
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"
            #include "Qc_TerrainCommon.cginc"


            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldPos : 	TEXCOORD1;
                float4 vertex : SV_POSITION;
                float height : TEXCOORD2;
            };

            sampler2D _MainTex;
            sampler2D _Mask;
            float4 _MainTex_ST;
              float4 _MainTex_TexelSize;

            v2f vert (appdata_full v)
            {
                v2f o;
                	UNITY_SETUP_INSTANCE_ID(v);
                float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
                o.worldPos = worldPos;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord; //TRANSFORM_TEX(v.texcoord, _MainTex);


                o.height = -mul(unity_ObjectToWorld, float3(0,0,1)).y; // length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y));

                return o;
            }

            float _HeightVisibility;
            float _BiomeVisibility;
            float _Height;
            float _MaskClipping;
            float _MaskOpaqueness;
            float4 _ColorSwap;


            float4 frag (v2f i) : SV_Target
            {
                // ************ Stamp Reading

                _Height *= i.height;

                float4 stamp = tex2D(_MainTex, i.uv);

                #if _MASK_SMOOTHING

                 stamp *= 2;

                  float2 d = _MainTex_TexelSize.xy * 0.6;
                  stamp += tex2D(_MainTex, i.uv + float2(d.x, 0));
                  stamp += tex2D(_MainTex, i.uv - float2(d.x, 0));
                  stamp += tex2D(_MainTex, i.uv + float2(0, d.y));
                  stamp += tex2D(_MainTex, i.uv - float2(0, d.y));

                  stamp/= 6;
                #endif

                #if _BlACK_N_WHITE
                    stamp.a = stamp.r;
                #endif

                #if _INVERT_ALPHA
                    stamp.a = 1-stamp.a;
                #endif

                stamp.rgb = lerp(stamp.rgb, _ColorSwap.rgb, _ColorSwap.a);


                // ************ Mask Reading

                float mask; 

                #if MASK_RED
                    mask = tex2D(_Mask, i.uv).r;
                #elif MASK_ALPHA 
                    mask = tex2D(_Mask, i.uv).a;
                #elif MASK_STAMPALPHA
                    #if MIX_MIN
                        mask = 1 - stamp.a;
                    #else
                        mask = stamp.a;
                    #endif
                #elif MASK_NONE
                        mask = 1;
                #endif


                float adjustedMask = lerp(smoothstep(_MaskClipping,1,mask),1, _MaskOpaqueness);

              /*  #if MIX_MIN 
                    mask = adjustedMask * smoothstep(1-_MaskClipping+0.01,1- _MaskClipping, mask);
                #else*/
                    mask = adjustedMask * smoothstep(_MaskClipping, _MaskClipping+0.01, mask);
               // #endif

                //mask = lerp(mask,)

                _HeightVisibility *= mask;
                _BiomeVisibility *= mask;

                // Blending
           
                float4 terrainControl =  Ct_SampleTerrainPrevious(i.worldPos); // Ct_Control_Previous  //Ct_TerrainDefault;//float4(0,0,0,Ct_TerrainHeight); // Ct_SampleTerrain(i.worldPos);
                float terrainHeight; 
                GetTerrainHeight(terrainControl, terrainHeight);
                float stampHeightRaw = stamp.a * _Height;
                float4 result = float4(1,0,1,1);
  
        float stampHeight = i.worldPos.y + stampHeightRaw;

            float terrainH;
            GetTerrainHeight(terrainControl, terrainH);

                float diff = stampHeight - terrainH;


                #if MIX_ADD
                    stamp.a = HeightToColor(terrainHeight + stampHeightRaw);
                    result.a = lerp(terrainControl.a, stamp.a, _HeightVisibility);
                    result.rgb = lerp(terrainControl.rgb, stamp.rgb, _BiomeVisibility);
                    return result;
                #endif

                #if MIX_SUBTRACT
                    stamp.a = HeightToColor(terrainHeight - stampHeightRaw);
                    result.a = lerp(terrainControl.a, stamp.a, _HeightVisibility);
                    result.rgb = lerp(terrainControl.rgb, stamp.rgb, _BiomeVisibility);
                    return result;
                #endif

                #if MIX_ALPHA
                   float alpha = stamp.a;
                   stamp.a = HeightToColor(i.worldPos.y);
                   result.a = lerp(terrainControl.a, stamp.a, alpha * _HeightVisibility );
                   result.rgb = lerp(terrainControl.rgb, stamp.rgb, alpha * _BiomeVisibility);
                   return result;
               #endif

      

                #if MIX_MIN
                    stampHeight -= _Height;
                #endif

                 #if MIX_OVERRIDE
                    result.a = lerp(terrainControl.a, HeightToColor(stampHeight), _HeightVisibility);
                    result.rgb = lerp(terrainControl.rgb, stamp.rgb, _BiomeVisibility);
                    return result;
                #endif

                #if MIX_MAX || MIX_MIN

            
                   #if MIX_MIN
                    clip(0.9 - stamp.a);
                  #else
                    clip(stamp.a - 0.1);
                  #endif

             
                    #if MIX_MIN
                        float interpolate = smoothstep(0.5,0.9,stamp.a) * smoothstep(-0.5, -1,diff);
                      float t = smoothstep(0, -0.5, diff) * (1-interpolate);// * smoothstep(1, 0.9, stamp.a);
                    #else
                      float t = smoothstep(0, 0.5, diff);// * smoothstep(0, 0.1, stamp.a);
                    #endif
                  
                    stamp.a = HeightToColor(stampHeight);

                    result.a = lerp(terrainControl.a, stamp.a, t * _HeightVisibility );
                    result.rgb = lerp(terrainControl.rgb, stamp.rgb, t * _BiomeVisibility);
              
                    return result;
                #endif

     

               return result;
             
            }
            ENDCG
        }
    }
}
