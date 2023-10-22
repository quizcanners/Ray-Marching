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

			#pragma multi_compile ___ RT_TO_CUBEMAP
			#pragma multi_compile ___ _qc_IGNORE_SKY

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
			float Qc_SmoothingBakingTransparency;

			inline float3 GET_RANDOM_POINT(float4 rand, float farFromWall, float VOL_SIZE, float3 normalTmp)
			{ 
				if (farFromWall > 0.9) 
					return randomSpherePoint(rand) * VOL_SIZE;
					return  cosWeightedRandomHemisphereDirection(normalTmp, rand) * farFromWall * VOL_SIZE;
			}



			float4 frag(v2f o) : COLOR
			{
				float3 worldPos = volumeUVtoWorld(o.texcoord.xy);

				float VOL_SIZE = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

				float4 seed = tex2Dlod(_Global_Noise_Lookup, float4(o.noiseUV, 0, 0));

				seed.a = ((seed.r + seed.b) * 2) % 1;

				float4 off = (seed - 0.5);

				worldPos += off.rgb * VOL_SIZE;

				float oobSDF;
				float4 normalTmp = SampleSDF(worldPos , oobSDF);

				//float4 normalTmp = NormalAndDistance(worldPos, VOL_SIZE);

				float farFromWall =  smoothstep(0, VOL_SIZE, normalTmp.w) ;

			

			

				float4 previous = tex2Dlod(_PreviousTex, float4(o.texcoord.xy, 0, 0));

				/*
				float DARKENING_RADIUS = 0.25 * VOL_SIZE;
				if (normalTmp.w <  DARKENING_RADIUS)
				{
					return previous * 0.1 * (9 + smoothstep( - DARKENING_RADIUS,  DARKENING_RADIUS,normalTmp.w));
				}*/
				//randomSpherePoint(float4 rand)

			//	float maxOffset = farFromWall * VOL_SIZE;

				// ? randomSpherePoint(rand) * VOL_SIZE :

			
				float4 total = 0;
				float outOfBounds;

				total += SampleVolume(_MainTex, worldPos, outOfBounds); //SampleVolume(_MainTex, worldPos, outOfBounds);// *(1 - outOfBounds);

				//GET_RANDOM_POINT(float4 rand, float farFromWall, float VOL_SIZE, float3 normalTmp)
				
				
				total += SampleVolume(_MainTex, worldPos + GET_RANDOM_POINT(seed.rgba, farFromWall, VOL_SIZE, normalTmp), outOfBounds);
				total += SampleVolume(_MainTex, worldPos + GET_RANDOM_POINT(seed.gbar, farFromWall, VOL_SIZE, normalTmp), outOfBounds);
				total += SampleVolume(_MainTex, worldPos + GET_RANDOM_POINT(seed.barg, farFromWall, VOL_SIZE, normalTmp), outOfBounds);
				total += SampleVolume(_MainTex, worldPos + GET_RANDOM_POINT(seed.argb, farFromWall, VOL_SIZE, normalTmp), outOfBounds);
					
			


				total.rgb /= max(total.a , 1);

			


#ifdef UNITY_COLORSPACE_GAMMA
				total.rgb = pow(total.rgb, LINEAR_TO_GAMMA);
#endif

				
				//total += previous;
			
				total = lerp(previous, total, total.a / (total.a + previous.a + 1) );


				/*
#if RT_TO_CUBEMAP
				total.rgb = max(total.rgb, previous.rgb); 
#else 
*/
			//	total = lerp(previous, total, min(smoothstep(0, 300, total.a) * 0.3, total.a / (total.a + previous.a + 1)));
//#endif

				total = max(0, total); // Fixes some division bug

				return total;
				
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}