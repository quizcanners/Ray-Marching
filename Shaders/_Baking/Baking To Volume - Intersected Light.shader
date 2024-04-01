Shader "RayTracing/Baker/RayBakingOfLight"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		[Toggle(_DEBUG)] debugOn("Debug", Float) = 0
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
		Blend One One//One Zero 

		Pass
		{

			CGPROGRAM

			#define _qc_AMBIENT_SIMULATION
			#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_RayBaking.cginc"
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile __ RT_DENOISING
			#pragma multi_compile __ RT_TO_CUBEMAP 
			#pragma multi_compile ___ _qc_IGNORE_SKY
			#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 

			struct v2f 
			{
				float4 pos : 		SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float3 viewDir: 	TEXCOORD1;
			//	float2 noiseUV :	TEXCOORD2;
			};

			float4 _Effect_Time;
	
			v2f vert(appdata_full v) 
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.texcoord = v.texcoord.xy;

				//o.noiseUV = o.texcoord * (123.12345678) + float2(sin(_Effect_Time.x), cos(_Effect_Time.x*1.23)) * 123.12345612 * (1 + o.texcoord.y);

				return o;
			}


			sampler2D _MainTex;
			float4 _RT_CubeMap_Direction;
			uniform sampler2D _Global_Noise_Lookup;

			float4 frag(v2f o) : SV_TARGET 
			{

				float3 worldPos = volumeUVtoWorld(o.texcoord.xy);

				float4 noise = //tex2Dlod(_Global_Noise_Lookup, float4(o.noiseUV, 0, 0));

				tex2Dlod(_Global_Noise_Lookup, float4(
					//creenUV * (123.12345678) + float2(_SinTime.x, _CosTime.y + screenUV.y) * 32.12345612
					 o.texcoord * (123.12345678) + float2(sin(_Effect_Time.x), cos(_Effect_Time.x*1.23)) * 123.12345612 * (1 + o.texcoord.y)

					,0, 0));


				noise.a = ((noise.r + noise.b) * 2) % 1;

				float4 rand = (noise - 0.5) * 2;

				float VOL_SIZE = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;


				worldPos += rand.rga * 0.25 * VOL_SIZE;

				/*
				float4 nrmDist = NormalAndDistance(worldPos, VOL_SIZE * 2);

				
				if (nrmDist.w < 0)
				{
					return float4(0,0,0,1);
				}*/

					float outOfBounds;
				float3 rayDirection;

				float4 sdf0 = SampleSDF(worldPos, outOfBounds);

				float blackPixel = smoothstep(0, -0.01, sdf0.a) * (1-outOfBounds);

				if (blackPixel == 1)
					return float4(0,0,0,0.1);

			//	float sdfOffsetAmount = smoothstep(VOL_SIZE, 0, nrmDist.w);
			

#if RT_TO_CUBEMAP
				rayDirection = normalize(lerp(rand.xyz, _RT_CubeMap_Direction.xyz, abs(_RT_CubeMap_Direction.xyz)));
#else 
				
				

				rayDirection = normalize(rand.rgb);

				float dotToNorm = dot(sdf0.xyz, rayDirection);

				float flipRay = step(0, -dotToNorm) * outOfBounds;
			
				rayDirection = normalize(lerp(rayDirection, -rayDirection, flipRay));
#endif

				// + nrmDist.xyz * sdfOffsetAmount * 2;
				
				//worldPos += rand.rga * 0.45 * VOL_SIZE;
			
				float4 sdf = SampleSDF(worldPos + rayDirection * VOL_SIZE, outOfBounds);

			
				
				float4 col = render(worldPos, rayDirection, noise);

				/*
#ifdef UNITY_COLORSPACE_GAMMA
				col.rgb = pow(col.rgb, GAMMA_TO_LINEAR);
#endif
*/

				col.a = 1;

				col.rgb = lerp(col.rgb,0, blackPixel);

				return col;
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}