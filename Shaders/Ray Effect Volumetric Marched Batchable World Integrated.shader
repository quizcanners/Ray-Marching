Shader "RayTracing/Integrated SDF/Batchable Sphere"
{
	Properties
	{
		[NoScaleOffset]_MainTex("Texture (RGB)", 2D) = "white" {}
		[NoScaleOffset] _Map("Bump/Combined Map (or None)", 2D) = "gray" {}
	}

	SubShader
	{

		Tags
		{ 
			"RenderType" = "Opaque"
			"IgnoreProjector" = "True"
		}


		CGINCLUDE

			#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
			#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
			#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"

			float4 _Effect_Time;


			float Droplet(float3 pos, float rain_density)
			{
				float3 seed;
				float3 gridPosition = GetGridAndSeed(pos + float3(0,_Effect_Time.x * 20,0), rain_density, seed); // (((rotatedPos * upscale) + 100) % 1) - 0.5;
				float dropletSize = 15 * (1 + abs(seed.x));
				gridPosition.y = -gridPosition.y;
				return sdRoundCone((gridPosition.xyz + seed*0.5 ) * dropletSize   ) / (dropletSize * rain_density);
			}


			float SampleSDF (float3 pos, float4 spherePos, float4 rotation, float4 size)
			{
				//float scale = spherePos.w;

				//float dist = SphereDistance(pos - spherePos.xyz ,  0.5 * scale);

				//float4 rotation = float4(0.1,0,0,1);

			//	float softness = 0.05;
			//	size -= softness;
			//	float3 rotatedPos = GetRotatedPos(pos, spherePos.xyz, rotation);
				
			//	float cube = CubeDistance_Inernal(rotatedPos, size * 0.25) - softness;
				
				
				/*
				float RAIN_DENSITY = 1;

				float3 seed;
				float3 gridPosition = GetGridAndSeed(pos + float3(0,_Effect_Time * 10,0), RAIN_DENSITY, seed); 
				float dropletSize = 10 * (1 + abs(seed.x));
				gridPosition.y = -gridPosition.y;
				float droplet = sdRoundCone((gridPosition.xyz + seed*0.25 ) * dropletSize   ) / (dropletSize * RAIN_DENSITY);*/
				//SphereDistance(gridPosition.xyz + seed * 0.25
				//, 0.05) 
				/// upscale;


			//	float

				//dist = SmoothIntersection(cube, gridSphere, 0.2);

				float droplet = min( Droplet(pos, 1), Droplet(pos + 0.456f, 1.23));

				// Melt into scene
				float scene = SceneSdf(pos, 1);
				float dist = //min(scene-0.2, droplet);// 
				CubicSmin (droplet, scene-0.15, 0.15) ;

				//dist = OpSmoothSubtraction(dist, scene - 0.12, 0.05);

				float smoothness = 2;
				float edges = 0.2;
				float dynamics = SceneSdf_Dynamic(pos,  smoothness,  edges);
					dist = CubicSmin (dist, dynamics - 0.1, 0.2) ;


				// Limiting Sphere
				float sphere = SphereDistance(pos - spherePos.xyz , size.w * 0.5);
				dist = SmoothIntersection(dist, sphere, 0.2);

				return dist;
			}
		ENDCG

		Pass
		{
			Tags 
			{
				"LightMode" = "ForwardBase"
			}

			ZWrite On
			ZTest Off
			Cull Front
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase

			struct v2f 
			{
				float4 vertex: SV_POSITION;
				float4 screenPos : TEXCOORD0;
			
				float4 viewDir		: TEXCOORD2;
				float3 normal	: TEXCOORD3;
				
				float3 meshPos : TEXCOORD4;
				float4 meshSize : TEXCOORD5;
				float4 meshQuaternion : TEXCOORD6;

				float4 centerPos : TEXCOORD7;

				fixed4 color : COLOR;
			};

			v2f vert(appdata_full v) {
				v2f o;


				o.vertex = UnityWorldToClipPos(mul(unity_ObjectToWorld, v.vertex));

				o.screenPos = ComputeScreenPos(o.vertex);

				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.normal = UnityObjectToWorldNormal(v.normal);
			
				o.meshPos = v.texcoord;
				o.meshSize = v.texcoord1;
				o.meshQuaternion = v.texcoord2;

				float size = max(o.meshSize.z, max(o.meshSize.x, o.meshSize.y));

				o.meshSize.w =  min(o.meshSize.z, min(o.meshSize.x, o.meshSize.y));

				o.centerPos = float4(o.meshPos.xyz, size);			

				o.color = v.color;
				return o;
			}


			sampler2D _MainTex;

			FragColDepth frag(v2f i)
			{
				MARCH_FROM_DEPTH_ROT(newPos, spherePos, shadow, viewDir, screenUv);

				INIT_SDF_NORMAL_ROT(normal, newPos, spherePos, SampleSDF);

				PrimitiveLight(lightColor, ambientCol, outOfBounds, newPos, normal);

				TopDownSample(newPos, ambientCol, outOfBounds);

				
			/*	float3 uvPos = newPos * 0.2;

				float4 yCol = tex2D(_MainTex, uvPos.xz);
				float4 xCol = tex2D(_MainTex, uvPos.yz);
				float4 zCol = tex2D(_MainTex, uvPos.xy);

				col = lerp(yCol, xCol, abs(normal.x));
				col = lerp(col, zCol, abs(normal.z));

				float gloss = col.a;*/
				
				float fresnel = smoothstep(-1, 1 , dot(viewDir, normal));


				// normalize(lerp(normal, viewDir, 0.1 + 0.9 * gloss));

				float3 reflectionPos;
				float outOfBoundsRefl;
				float3 bakeReflected = SampleReflection(newPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);

				TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);

				float outOfBoundsStraight;
				float3 straightHit;
				float3 bakeStraight = SampleRay(newPos + normal , -normal, shadow, straightHit, outOfBoundsStraight);

			
				//bakeStraight *= shadow;

				TopDownSample(straightHit, bakeStraight, outOfBoundsStraight);

			

				float4 col = 0;

				col.rgb = lerp(bakeReflected, bakeStraight, fresnel);

				ApplyBottomFog(col.rgb, newPos, viewDir.y);
				FragColDepth result;
				result.depth = calculateFragmentDepth(newPos);
				result.col = col;// * shadow;
				return result;

			}

			ENDCG
		}

		
		Pass
		{
			Tags 
			{
				"LightMode" = "Shadowcaster"
			}

			ZWrite On
			ZTest LEqual
			Cull Front
			CGPROGRAM
			#pragma multi_compile_shadowcaster
			#pragma vertex vert
			#pragma fragment frag

			v2fMarchBatchable vert(appdata_full v)
			{
				v2fMarchBatchable o;
				InitializeBatchableMarcher(v,o);
				return o;
			}

			float frag(v2fMarchBatchable i) : SV_Depth
			{
				MARCH_DEPTH_ROT(SampleSDF);
			}
			ENDCG
		}
		
	}
}