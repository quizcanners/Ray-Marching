Shader "QcRendering/Terrain/Internal/Terrain_Stamp_OverlapFriendly"
{
    Properties
    {
        _MainTex ("Stamp", 2D) = "clear" {}
        [Toggle(_INVERT_ALPHA)] invertAlpha ("Invert Alpha", Float) = 0  
         [Toggle(_BlACK_N_WHITE)] whiteMask ("Mask is blck&White", Float) = 0
         _AdditiveFactor("Add instead of replacing", Range(0,4)) = 0
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

        Blend One OneMinusSrcAlpha                                      
        ColorMask RGB
		Cull Back
		ZWrite On
		ZTest Off
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

             #pragma shader_feature_local MASK_RED MASK_ALPHA MASK_STAMPALPHA MASK_NONE
            #pragma shader_feature_local ___ _INVERT_ALPHA
            #pragma shader_feature_local ___ _BlACK_N_WHITE
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"
            #include "Qc_TerrainCommon.cginc"


            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldPos : 	TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
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
                return o;
            }


            sampler2D _Mask;
            float _MaskClipping;
            float _MaskOpaqueness;

            float4 _ColorSwap;
            float _AdditiveFactor;

            float4 frag (v2f i) : SV_Target
            {
                // ************ Stamp Reading
                float4 stamp = tex2D(_MainTex, i.uv);

                #if _BlACK_N_WHITE
                    stamp.a = stamp.r;
                    stamp.rgb = 1;
                #endif

                #if _INVERT_ALPHA
                    stamp.a = 1-stamp.a;
                #endif

                stamp.rgb = lerp(stamp.rgb, _ColorSwap.rgb, _ColorSwap.a);

                stamp.rgb *= stamp.a * (1 + _AdditiveFactor);

                stamp.a = pow(stamp.a,1 + _AdditiveFactor); // To preserve more of the original blend


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
                mask = adjustedMask * smoothstep(_MaskClipping, _MaskClipping+0.01, mask);

                stamp *= mask;

                return stamp;
             
            }
            ENDCG
        }
    }
}
