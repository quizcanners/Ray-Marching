Shader "RayTracing/Integrated SDF/Batchable Sphere"
{
	Properties
	{
		[NoScaleOffset]_MainTex("Texture (RGB)", 2D) = "white" {}
		[NoScaleOffset] _Map("Bump/Combined Map (or None)", 2D) = "gray" {}
		_Merging("Merging", Range(0.1,10)) = 1
		_Test("Test", Range(0.01,2)) = 1
		_Test1("Test1", Range(0.01,2)) = 1
		_Test2("Test2", Range(0.01,2)) = 1
	}

	SubShader
	{

		Tags
		{ 
			"RenderType" = "Opaque"
			"IgnoreProjector" = "True"
		}


		CGINCLUDE

			#define RENDER_DYNAMICS
			#define IGNORE_FLOOR


			#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
			#pragma multi_compile __ _qc_IGNORE_SKY 

			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Debug.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"

			float _Merging;
			float4 _Effect_Time;
			float _Test;
			float _Test1;
			float _Test2;

			float Droplet(float3 pos, float rain_density)
			{
				float3 seed;
				float3 gridPosition = GetGridAndSeed(pos + float3(0,_Effect_Time.x * 20,0), rain_density, seed); // (((rotatedPos * upscale) + 100) % 1) - 0.5;
				float dropletSize = 15 * (1 + abs(seed.x));
				gridPosition.y = -gridPosition.y;
				float dist = sdRoundCone((gridPosition.xyz + seed*0.25 ) * dropletSize   ) / (dropletSize * rain_density);

				//dist = min(dropletSize * rain_density*0.01, dist);

				return dist;
			}


			float SampleSDF (float3 pos, float4 spherePos, float4 rotation, float4 size)
			{
				float scale = spherePos.w;

				float dist = SphereDistance(pos - spherePos.xyz ,  0.4 * scale);

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

				//float droplet = min( Droplet(pos, 1), Droplet(pos + 0.456f, 1.23));

				// Melt into scene
				float outOfBounds;
				float scene = SampleSDF(pos, outOfBounds).a;
				scene = lerp(scene, 1000, outOfBounds);

				dist = CubicSmin(scene, dist, 0.1*scale * _Merging); 
				//CubicSmin (droplet, scene-0.15, 0.15) ;

				//float gyr = sdGyroid(pos, 2* _Test, 0.1 * _Test1, 0.1* _Test2 );

				//dist = gyr *0.01; 

				//dist = OpSmoothSubtraction(dist, scene - 0.12, 0.05);

				float smoothness = 2;
				float edges = 0.2;
				float dynamics = SceneSdf_Dynamic(pos,  smoothness,  edges);
					dist = OpSmoothSubtraction (dist, dynamics - 0.5, 1) ;


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
			#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

			struct v2f 
			{
				float4 vertex: SV_POSITION;
				float4 screenPos : TEXCOORD0;
			
				float3 viewDir		: TEXCOORD2;
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

				o.viewDir = WorldSpaceViewDir(v.vertex);
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

				float3 volumeSamplePosition = newPos;
				float fresnel = 1 - saturate(dot(normal, viewDir));

				float ao = 1;

				float3 reflectedRay = reflect(-viewDir, normal);
				float3 bakeReflected = GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, BLOOD_SPECULAR, ao);//SampleReflection(o.worldPos, viewDir, normal, shadow, hit);

				bakeReflected += GetDirectionalSpecular(normal, viewDir, 0.85) * GetDirectional();


				float3 refractedRay =  refract(-viewDir, normal, 0.75);
				float3 bakeStraight = GetBakedAndTracedReflection(volumeSamplePosition, refractedRay, BLOOD_SPECULAR, ao);
			
				#if !_qc_IGNORE_SKY 
				bakeReflected += GetDirectionalSpecular(normal, viewDir, 0.85) * shadow * GetDirectional();
				bakeStraight += GetTranslucent_Sun(refractedRay) * shadow; //translucentSun * shadow * GetDirectional() * 4; 
				#endif

				float4 col = i.color;

				float showStright = (1 - fresnel);
 
				col.rgb *= lerp(bakeReflected.rgb, bakeStraight.rgb, showStright);// + specularReflection * lightColor;

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