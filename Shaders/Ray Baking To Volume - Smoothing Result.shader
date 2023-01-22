Shader "RayTracing/Baker/Smoothing Result"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_PreviousTex("Albedo (RGB)", 2D) = "clear" {}
	}

	SubShader
	{
		Tags
		{
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
		}

		ColorMask RGBA
		Cull Off
		ZWrite Off
		ZTest Off

		Pass{

			CGPROGRAM

			#define _qc_AMBIENT_SIMULATION
			#include "PrimitivesScene_Sampler.cginc"

			#pragma vertex vert
			#pragma fragment frag

			struct v2f {
				float4 pos : 		SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float2 noiseUV :	TEXCOORD1;
			};

			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.texcoord = v.texcoord.xy;
				o.noiseUV = o.texcoord * (123.12345678) + float2(_SinTime.x, _CosTime.y) * 32.12345612;

				return o;
			}

			sampler2D _MainTex;
			sampler2D _PreviousTex;


			float4 frag(v2f o) : COLOR
			{
				float4 total = 0;
				float3 worldPos = volumeUVtoWorld(o.texcoord.xy);

				float3 size = 1 / _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;// *5;// *0.5;

				float3 normalTmp = EstimateNormal(worldPos);

				float4 seed = tex2Dlod(_Global_Noise_Lookup, float4(o.noiseUV, 0, 0));

				float outOfBounds;
				total += SampleVolume(_MainTex, worldPos, outOfBounds);// *(1 - outOfBounds);
				total += SampleVolume(_MainTex, worldPos + cosWeightedRandomHemisphereDirection(normalTmp, seed.rgba) * size, outOfBounds);// *(1 - outOfBounds);
				total += SampleVolume(_MainTex, worldPos + cosWeightedRandomHemisphereDirection(normalTmp, seed.gbar) * size, outOfBounds);// *(1 - outOfBounds);
				total += SampleVolume(_MainTex, worldPos + cosWeightedRandomHemisphereDirection(normalTmp, seed.barg) * size, outOfBounds);// *(1 - outOfBounds);
				total += SampleVolume(_MainTex, worldPos + cosWeightedRandomHemisphereDirection(normalTmp, seed.argb) * size, outOfBounds);// *(1 - outOfBounds);
				

				float a = total.a;
				

				total /= a + 1;

				
#ifdef UNITY_COLORSPACE_GAMMA
				total.rgb = pow(total.rgb, LINEAR_TO_GAMMA);
#endif

				float4 previous = tex2Dlod(_PreviousTex, float4(o.texcoord.xy, 0, 0));

				total = lerp(previous, total, 0.2 + 0.7 * smoothstep(500, 0, a));

				total = max(0, total); // Fixes a some division bug

				return total;
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}