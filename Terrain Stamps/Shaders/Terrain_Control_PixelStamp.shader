Shader "QcRendering/Terrain/Internal/Terrain_PixelStamp"
{
    Properties
    {
        _Color("Biome To Blit (RGB)", Color) = (1,0,0,0)
        _BiomeVisibility("Biome Visibility", Range(0,1)) = 1
    }

    SubShader
    {
        Tags 
        { 
			"IgnoreProjector" = "True"
			"RenderType" = "Opaque" 
            "Queue" = "Geometry+10" 
        }

        ColorMask RGBA
	//	Cull Off
	//	ZWrite Off
		ZTest Off
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local MIX_MAX MIX_MIN MIX_ADD MIX_ALPHA MIX_OVERRIDE
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"
            #include "Qc_TerrainCommon.cginc"


            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldPos : 	TEXCOORD1;
                float4 vertex : SV_POSITION;
            };


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

            float4 _Color;
            float _BiomeVisibility;


            float4 frag (v2f i) : SV_Target
            {
                float4 terrainControl =  Ct_TerrainDefault;

                terrainControl.a = HeightToColor(i.worldPos.y);
                terrainControl.rgb = lerp(terrainControl.rgb, _Color.rgb, _BiomeVisibility);
                return terrainControl;
            }
            ENDCG
        }
    }
}
