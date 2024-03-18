Shader "QcRendering/Terrain/Internal/PixelsToHexagonRemapping"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags 
		{ 
			"IgnoreProjector" = "True"
			"RenderType" = "Opaque" 
            "Queue" = "Geometry+10" 
		}

        LOD 100
		  ColorMask RGBA
		  ZTest Off

        Pass
        {

		   // Blend One Zero//SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
			 #include "Qc_TerrainCommon.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 worldPos : 	TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			float4 _MainTex_TexelSize;

			sampler2D Ct_NoiseTex;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
				o.worldPos = worldPos;

                return o;
            }

         	float GetHexagon(float2 uv) {
					uv = abs(uv);

					const float2 toDot = normalize(float2(1, 1.73));

					float c = dot(uv, toDot);

					return max(c, uv.x);
				}


				inline float4 GetHexagons(float2 uv, float2 texelSize) 
				{
					//uv -= 0.5;
					float2 grid = uv;// * texelSize;  //(uv * 1.03 - float2(0.03, 0.06))*texelSize;

					//grid += texelSize * 0.5;

					const float2 r = float2(1, 1.73);

					const float2 h = r * 0.5;

					float2 gridB = grid + h;

					float2 floorA = floor(grid / r);

					float2 floorB = floor(gridB / r);

					float2 uvA = ((grid - floorA * r) - h);

					float2 uvB = ((gridB - floorB * r) - h);

					float distA = GetHexagon(uvA);

					float distB = GetHexagon(uvB);

					float isB = saturate((distA - distB) * 9999);

					float dist = (distB * isB + distA * (1 - isB))*2;

					const float2 deChecker = float2(1, 2);

					float2 index = lerp(floorA * deChecker, deChecker * (floorB  - 1) + 1, isB);

					float2 uvCell = lerp(uvA, uvB, isB);

					const float pii = 3.141592653589793238462;

					const float pi2 = 1.0 / 6.283185307179586476924;

					float angle = (atan2(uvCell.x, uvCell.y) + pii) * pi2;

					return float4(index, dist, angle);

				}


				float4 Ct_HEX_PARAMS; //x HexMetrics.INNER_RADIUS, y HexMetrics.OUTER_RADIUS, z HexMetrics.ELEVATION_SCALE
				float Ct_HexNoiseStrength;

				float2 Rot(float2 uv, float angle) 
				{
					float si = sin(angle);
					float co = cos(angle);
					return float2(co * uv.x - si * uv.y, si * uv.x + co * uv.y);
				}

				float4 frag(v2f i) : COLOR
				{
					i.worldPos.xz += float2(Ct_HEX_PARAMS.x, Ct_HEX_PARAMS.y * 1.5); // One-pixel offset for right allignment

					float4 noise = tex2Dlod(Ct_NoiseTex, float4(i.worldPos.xz*0.01,0,0));

					float2 pixelUV = ((i.worldPos.xz * 0.5 + (noise.xy-0.5) * Ct_HexNoiseStrength) / Ct_HEX_PARAMS.x);

					float thickness = length(fwidth(pixelUV));

					float4 hex = GetHexagons(pixelUV, _MainTex_TexelSize.zw);
					float dist = hex.z;

					float2 remappedUv = (hex.xy+0.5) * _MainTex_TexelSize.xy + 0.5;

					float4 col = tex2Dlod(_MainTex, float4(remappedUv,0,0));

					float2 cut = max(0, max(-remappedUv, remappedUv - 1) * 9999);

					float alpha = saturate(1 - (cut.x+cut.y));
					col= lerp(Ct_TerrainDefault, col, alpha);

					col.a = max(col.a, Ct_TerrainDefault.a);

					// col.a *= saturate((col.a - dist) * (1.5 - col.a) * 10)
					
					float height = Ct_HeightRange.x + col.a * Ct_HeightRange.z;
					float belowWater = smoothstep(-0.5, 0, Ct_WaterLevel.x - height);

				//	col.a -= (noise.b +1)*0.15 * belowWater;

					// Next Hexagon test
					/*
					float angle = hex.w;
					float side = floor(angle * 5.9999);
					const float _Pi = 3.141592653589793238462; 
					float2 neighbour = Rot(float2(0,1), (side+0.5)/6 * 2 * _Pi);
					neighbour.y = -neighbour.y;
					float4 nextHex = GetHexagons(pixelUV + neighbour * 0.41, _MainTex_TexelSize.zw);
					float2 remappedUvNext = (nextHex.xy+0.5) * _MainTex_TexelSize.xy + 0.5;
					float4 colNext = tex2D(_MainTex, float4(remappedUvNext,0,0));
					float border = smoothstep(0, 0.1, length(col.rgb - colNext.rgb) );
					border *= smoothstep(0.999 - thickness*2, 1,dist);
					col = lerp(col, 1, border);*/

					return col;

				}
            ENDCG
        }
    }
}
