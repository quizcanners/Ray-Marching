Shader "UniStorm/Celestial/Stars" {
Properties {
	_Color ("Tint Color", Color) = (0.5,0.5,0.5,0.5)
	_Starmap ("Star Map", 2D) = "white" {}
	_StarSpeed ("Rotation Speed", Float) = 2.0
	_LoY ("Opaque Y", Float) = 0
    _HiY ("Transparent Y", Float) = 10
}

Category {
	Tags{ "Queue" = "Transparent-400" "RenderType" = "Transparent" "IgnoreProjector" = "True" }
	Blend SrcAlpha One
	Lighting Off 
	ZWrite Off

	SubShader 
	{
		Pass 
		{
            Stencil {
                Ref 1
                Comp NotEqual
            }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_particles
			#pragma multi_compile_fog

			#include "UnityCG.cginc"

			sampler2D _Starmap;
			sampler2D _Global_Noise_Lookup;
			fixed4 _Color;
			half _LoY;
      		half _HiY;
			uniform float3 _uWorldSpaceCameraPos;
			
			struct appdata_t {
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
			};

			struct v2f {
				float4 vertex : SV_POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
				//float2 noiseUV :	TEXCOORD2;
			};

			float2 rotateUV(float2 uv, float degrees)
            {
               const float Rads = (UNITY_PI * 2.0) / 360.0;
 
               float ConvertedRadians = degrees * Rads;
               float _sin = sin(ConvertedRadians);
               float _cos = cos(ConvertedRadians);
 
                float2x2 R_Matrix = float2x2( _cos, -_sin, _sin, _cos);
 
                uv -= 0.5;
                uv = mul(R_Matrix, uv);
                uv += 0.5;
 
                return uv;
            }
			
			float4 _Starmap_ST;
			float _StarSpeed;
			float _Rotation;

			v2f vert (appdata_t v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f,o);

				float s = _ProjectionParams.z;

				float4x4 mvNoTranslation =
					float4x4(
						float4(UNITY_MATRIX_V[0].xyz, 0.0f),
						float4(UNITY_MATRIX_V[1].xyz, 0.0f),
						float4(UNITY_MATRIX_V[2].xyz, 0.0f),
						float4(0, 0, 0, 1.1)
						);

				o.vertex = mul(mul(UNITY_MATRIX_P, mvNoTranslation), v.vertex * float4(s, s, s, 1));
				o.texcoord = TRANSFORM_TEX(v.texcoord, _Starmap);
				o.color = v.color;

				_Rotation = _Time.x*_StarSpeed*10;

				o.texcoord1.xy = TRANSFORM_TEX(rotateUV(v.texcoord, _Rotation), _Starmap);

				float4 worldV = mul (unity_ObjectToWorld, v.vertex);
		        o.color.a = 1 - saturate(((_uWorldSpaceCameraPos.y - worldV.y) - _LoY) / (_HiY - _LoY));

			//	o.noiseUV = o.texcoord1.xy * (123.12345678) + float2(_SinTime.x, _CosTime.y) * 32.12345612;


				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{				
				fixed4 col = 1.0f * i.color * _Color * (tex2D(_Starmap, i.texcoord1.xy));

				//	float4 noise = tex2Dlod(_Global_Noise_Lookup, float4(i.noiseUV.xy, 0, 0));

//#ifdef UNITY_COLORSPACE_GAMMA
				//col.rgb = (noise.rgb) * 0.02;
//#else
				//col.rgb = (noise.rgb);
//#endif



				return col;
			}
			ENDCG 
			}
		}	
	}
}
