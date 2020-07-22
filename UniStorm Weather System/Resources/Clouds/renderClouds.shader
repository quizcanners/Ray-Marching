Shader "UniStorm/Clouds/Cloud Computing"
{
	Properties
	{
		
		_MainTex ("Texture", 2D) = "white" {}
		_CloudCurl("Cloud Curls (RGB)", 2D) = "white" {}
		_CurlStrength("Curl Strength", Range(0.0, 1)) = 1
	}
	SubShader
	{
        Tags{ "Queue" = "Transparent-400" "RenderType" = "Transparent" "IgnoreProjector" = "True" }
		LOD 100
        Blend One OneMinusSrcAlpha
        ZWrite Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 viewDir: 	TEXCOORD1;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _CurlStrength;

			v2f vert (appdata v)
			{
				v2f o;

                float s = _ProjectionParams.z;

                float4x4 mvNoTranslation =
                    float4x4(
                        float4(UNITY_MATRIX_V[0].xyz, 0.0f),
                        float4(UNITY_MATRIX_V[1].xyz, 0.0f),
                        float4(UNITY_MATRIX_V[2].xyz, 0.0f),
                        float4(0, 0, 0, 1.1)
                    );
                    
                
                o.vertex = mul(mul(UNITY_MATRIX_P, mvNoTranslation), v.vertex * float4(s, s, s, 1));
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.viewDir = WorldSpaceViewDir(v.vertex);
				return o;
			}
			
				float4 _Effect_Time;
				
			sampler2D _CloudCurl;

			fixed4 frag (v2f i) : SV_Target
			{
				float3 viewDir = normalize(i.viewDir.xyz);
				// sample the texture
				float curl = tex2D(_CloudCurl, i.uv*19 + _Effect_Time.x *0.0456) - 0.5;
				float curl2 = tex2D(_CloudCurl, i.uv*23 - _Effect_Time.x *0.0123) - 0.5;

				//return curl * curl2;

				//return _ProjectionParams.z;

				_CurlStrength *= abs(viewDir.y) * 0.01;

				fixed4 col = 
				max(tex2D(_MainTex, i.uv + float2(curl, curl2) * _CurlStrength), 
				tex2D(_MainTex, i.uv - curl2 * curl * _CurlStrength)) ;
				
				///col *= 0.5;
				//col.a += (1-col.a) *  curl * curl2 * _CurlStrength;

				return col;
			}
			ENDCG
		}
	}
}
