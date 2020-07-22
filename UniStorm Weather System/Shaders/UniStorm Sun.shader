Shader "UniStorm/Celestial/Sun" 
{
	Properties 
	{
		//[HDR]_SunColor ("Sun Color", Color) = (0.5,0.5,0.5,0.5)
		_SunBrightness ("Sun Brightness", Range(0.0, 1.0)) = 1.0

		_SunRays("Sun Rays (RGB)", 2D) = "clear" {}
		_SunSurface("Sun Surface (RGB)", 2D) = "white" {}
	}

Category 
{
	Tags 
	{ 
		"Queue" = "Transparent-400" //"Queue"="Transparent-451" 
		"IgnoreProjector"="True" 
		"RenderType"="Transparent" 
	}

	Blend SrcAlpha One //MinusSrcAlpha
	ColorMask RGB
    ZWrite Off
	Cull Off
	Lighting Off 

	SubShader 
	{
		Pass 
		{
            Stencil 
			{
                Ref 1
                Comp always
                Pass replace
            }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_particles
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			sampler2D _SunRays;
			sampler2D _SunSurface;
			//fixed4 _SunColor;

			
			struct appdata_t 
			{
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
			};

			struct v2f 
			{
				float4 vertex : SV_POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
				float3 viewDir: 	TEXCOORD1;
				float4 projPos : TEXCOORD2;
			};
			
			v2f vert (appdata_t v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.color = v.color;
				o.texcoord = v.texcoord;
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);

				return o;
			}
			

			fixed4 frag (v2f i) : SV_Target
			{
				float3 viewDir = normalize(i.viewDir.xyz);

				float2 uv = i.texcoord - 0.5;
				float len = length(uv);

				const float PI = 3.14159265359;
				float angle = (atan2(uv.x, uv.y) + PI) / (PI * 2);

				float4 sunRays = tex2Dlod(_SunRays, float4(angle, -(1-len* len* len) - _Time.x * 0.5, 0, 0));
				float4 sunCol = tex2D(_SunSurface, uv * 2);

				float SUN_EDGE = 0.15;

				float4 sunColor = _LightColor0;

				float sunCircle = smoothstep(SUN_EDGE,SUN_EDGE-0.01, len);
				fixed4 col = i.color * (sunColor);
				col.rgb *= (0.1+sunCol.rgb)*0.5;
				col *= sunCircle;


				float outline = 5 / (abs(SUN_EDGE - len)*1500 + 5);

				col += smoothstep(0,1, outline * sunColor);

				col += float4(sunRays.rgb, length(sunRays.rgb)) * sunColor * (1-sunCircle);

				col.a *= smoothstep(0.5,0.3, len);

				col = lerp(0, col, smoothstep(-0.02,0,-viewDir.y));

				float3 mix = col.gbr * col.brg * col.a;
					col.rgb += mix * 0.2;


			    return col;
			}
			ENDCG 
		}
	}	
}
}
