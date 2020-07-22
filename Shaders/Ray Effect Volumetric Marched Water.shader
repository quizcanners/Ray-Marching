Shader "RayTracing/Integrated SDF/Volumetric Water"
{
	Properties
	{
		_Test("Test", Range(0.01,2)) = 1
	}

	SubShader
	{
		Tags
		{ 
			"Queue" = "Transparent"
			"RenderType" = "Transparent" 
			"DisableBatching" = "True"
		}

	

		CGINCLUDE

			#define RENDER_DYNAMICS

			#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
			#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
			#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"
		
			

			float4 _Effect_Time;

			float SampleSDF(float3 pos, float4 spherePos)
			{
				float scale = spherePos.w;
				float dist = SphereDistance(pos - spherePos.xyz ,  0.25 * scale);

				float smoothness = 2;
				float edges = 0.2; // scale; // upscaling

				float dynamics = SceneSdf_Dynamic(pos,  smoothness,  edges);

				float deDyn =  5 * smoothstep(2,0,dynamics) / (dynamics + 0.5);

			

				//float deScene = scene * sin(3 / (1 + scene)); // ;

				float gyr = sdGyroid(pos + float3(0 ,
				+_Effect_Time.x * 10 + deDyn
					-10, 0) , 	5 , 0.1   , 1 );
				
				float gyr2 = sdGyroid(pos + float3(0, +_Effect_Time.x * 4 //+ deScene * 10 
				- deDyn
					-10, 0) , 4	, 0.1  , 1);

				float newGyr =  SmoothIntersection (gyr, gyr2, 0.1); // * smoothstep(-0.1,0.1, gyr);

					float scene = SceneSdf(pos, 1);

				dist = CubicSmin (dist, scene, 0.5 * scale);

				float limitSphere = SphereDistance(pos - spherePos.xyz ,  0.5 * scale);

			

				dist = CubicSmin(dist, dynamics, 0.4);

				dist = lerp(dist, newGyr, 0.05);

				dist = SmoothIntersection(dist, limitSphere, 0.2);

				dist = OpSmoothSubtraction(dist, dynamics, 0.075);

				return  dist;
			}

		ENDCG

		Pass{

			Tags
			{
				"LightMode" = "ForwardBase"
			
			}

			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off
			ZTest Off
			Cull Front
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			#pragma multi_compile_instancing
		
			struct v2f 
			{
				float4 pos: SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float3 viewDir		: TEXCOORD1;
				float4 centerPos : TEXCOORD4;
				fixed4 color : COLOR;
			};

			float4 _Global_Noise_Lookup_TexelSize;
			float _Test;
		
			v2f vert(appdata_full v) 
			{
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);
				o.centerPos = PositionAndSizeFromMatrix();
				//MARCH_SETUP_CENTER_POS_VERT(o.centerPos);
				
				o.pos = UnityWorldToClipPos(mul(unity_ObjectToWorld, v.vertex));
				o.screenPos = ComputeScreenPos(o.pos);
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.color = v.color;
				
				return o;
			}

			fixed4 frag(v2f i) : SV_TARGET
			{
				float3 viewDir = normalize(i.viewDir.xyz);
				float2 screenUv = i.screenPos.xy / i.screenPos.w;

				//SAMPLE_TRUE_DEPTH(depth, viewDir, screenUv);


				float depth = SampleTrueDepth(viewDir, screenUv);

				
			

				RAYMARCH_WORLD(SampleSDF, newPos, viewDir, depth, i.centerPos);

				//	return 1;

				INIT_SDF_NORMAL(normal, newPos, i.centerPos, SampleSDF);

				float fresnel = smoothstep(-1, 1 , dot(viewDir, normal));

				float3 reflectionPos;
				float outOfBoundsRefl;
				float shadow = 1;
				float3 bakeReflected = SampleReflection(newPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);

				TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);

				float outOfBounds;
				float3 straightHit;
				float3 bakeStraight = SampleRay(newPos, normalize(-viewDir - normal*0.2), shadow, straightHit, outOfBounds );

				TopDownSample(straightHit, bakeStraight, outOfBounds);

				float toSurface = smoothstep(0, 5,  depth - dist);
				float showReflected = 1 - fresnel * fresnel;
				float showStraight = (1 - showReflected) * (toSurface);

				float4 col;
				
				col.rgb = bakeReflected * showReflected + bakeStraight * showStraight;
				col.a = showReflected + showStraight;

				col.a = lerp(col.a, 1, 0.5);

				col.rgb *= i.color.rgb;

				ApplyBottomFog(col.rgb, newPos, viewDir.y);

				return col;
			}
			ENDCG
		}
	}
}