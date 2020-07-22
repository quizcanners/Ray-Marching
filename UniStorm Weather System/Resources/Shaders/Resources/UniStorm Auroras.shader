Shader "UniStorm/Celestial/Aurora" {
    Properties {
        _AuroraTex ("Aurora Texture", 2D) = "white" {}
        _HorizontalLightSpeed ("Horizontal Light Speed", Float ) = 0.004
        _XSegments ("X Segment", Float ) = 3.7
        _YSegments ("Y Segments", Float ) = 1
        _ColorBalance ("Color Balance", Range(0, 2)) = 1.25
		_AmplitudeX("Amplitude X", Float) = 0.02
		_AmplitudeY("Amplitude Y", Float) = 0.02
		_AmplitudeZ("Amplitude Z", Float) = 0.02
		_Frequency("Frequency", Float) = 15
		_SpeedX("Speed X", Float) = 2
		_SpeedY("Speed Y", Float) = 2
		_SpeedZ("Speed Z", Float) = 3
    }

    SubShader {
        Tags {
            "IgnoreProjector"="True"
            "Queue"="Transparent"
            "RenderType"="Transparent"
			"DisableBatching" = "True"
        }

        LOD 200
        Pass {
            Name "FORWARD"
            Tags {
                "DisableBatching" = "True"
            }

            Blend One One
            Cull Off
            ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            //#define UNITY_PASS_FORWARDBASE
            #include "UnityCG.cginc"
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma only_renderers d3d9 d3d11 glcore gles 
            #pragma target 3.0
            uniform sampler2D _AuroraTex; uniform float4 _AuroraTex_ST;
            uniform float _HorizontalLightSpeed;
            uniform float _XSegments;
            uniform float _YSegments;
            uniform float _ColorBalance;
            uniform float4 _OuterColor;
            uniform float4 _InnerColor;
            uniform float _LightIntensity;

			uniform float _SpeedX;
			uniform float _SpeedY;
			uniform float _SpeedZ;
			uniform float _Frequency;
			uniform float _AmplitudeX;
			uniform float _AmplitudeY;
			uniform float _AmplitudeZ;

            struct VertexInput {
                float4 vertex : POSITION;
                float2 texcoord0 : TEXCOORD0;
				float3 normal : NORMAL;
            };
            struct VertexOutput {
                float4 pos : SV_POSITION;
                float2 uv0 : TEXCOORD0;
				float4 wpos : TEXCOORD1;
            };
            VertexOutput vert (VertexInput v) {
				VertexOutput o = (VertexOutput)0;
				o.uv0 = v.texcoord0;
				float3 vertexPos = v.vertex.xyz;
				float4 result = (float4(0.0, (sin((_Time.x * _SpeedY + (vertexPos.x * _Frequency))) * _AmplitudeY), (sin((_Time.x * _SpeedZ + (vertexPos.x * _Frequency))) * _AmplitudeZ), 0.0));
				v.vertex.xyz += result.xyz;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.pos.z = 1.0e-9f;
				return o;
            }

            float4 frag(VertexOutput i) : COLOR {
                float4 Aurora1 = tex2D(_AuroraTex,TRANSFORM_TEX(_Time.g +i.uv0, _AuroraTex));
                float2 UVMovement = (float2(_XSegments,_YSegments)*((float2(_HorizontalLightSpeed,0)*_Time.g)+i.uv0));
                float4 Aurora2 = tex2D(_AuroraTex,TRANSFORM_TEX(UVMovement, _AuroraTex));
                float4 Aurora3 = tex2D(_AuroraTex,TRANSFORM_TEX(i.uv0, _AuroraTex));
                float AuroraFinal = (((Aurora1.a)+(0.1+Aurora2.b))*Aurora3.g);
				//float AuroraFinal = (((2*Aurora1.a) + (0.1 + Aurora2.b))*Aurora3.g);
                float3 CombinedColors = ((lerp(_OuterColor.rgb,_InnerColor.rgb,(_ColorBalance*AuroraFinal))*AuroraFinal)*_LightIntensity);
                fixed4 FinalColor = fixed4(CombinedColors,1);
                return FinalColor;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
