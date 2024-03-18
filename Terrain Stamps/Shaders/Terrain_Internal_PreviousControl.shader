Shader "QcRendering/Terrain/Internal/Terrain_PreviousBuffer"
{
    Properties
    {
    }

    SubShader
    {
        Tags 
        { 
			"IgnoreProjector" = "True"
			"RenderType" = "Opaque" 
            "Queue" = "Geometry" 
        }

        ColorMask RGBA
		ZTest Off
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_instancing
            #include "UnityCG.cginc"
            #include "Qc_TerrainCommon.cginc"


            struct v2f
            {
             //   float2 uv : TEXCOORD0;
                float3 worldPos : 	TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata_full v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
                o.worldPos = worldPos;

                o.vertex = UnityObjectToClipPos(v.vertex);
               // o.uv = v.texcoord; 
                return o;
            }

            float _HeightVisibility;
            float _BiomeVisibility;

            float4 frag (v2f i) : SV_Target
            {
                return  Ct_SampleTerrainPrevious(i.worldPos);
            }
            ENDCG
        }
    }
}
