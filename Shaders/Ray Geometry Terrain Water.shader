Shader "RayTracing/Terrain/Water"
{
	Properties
	{
		_Waves("Waves", Range(0.01,1)) = 0.5
		_Test("Test", Range(0.01,2)) = 1
		_Color("Water Color", Color) = (1,1,1,1)
	}

		SubShader
	{
		Tags
		{
			"Queue" = "Geometry+20"
			"RenderType" = "Transparent"
			"DisableBatching" = "True"
		}

		CGINCLUDE

			#define RENDER_DYNAMICS
			#define IGNORE_FLOOR

			#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
			#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
			#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"
			#include "Assets\The-Fire-Below\Common\Shaders\qc_terrain_cg.cginc"

			float _Waves;
			float _Test;
			float4 _Effect_Time;

			float SampleSDF(float3 pos, float4 spherePos)
			{
				//float smoothness = 1;
			//	float edges = 0.1;

				//float dynamics = SceneSdf_Dynamic(pos,  smoothness,  edges);

				float baseFloor = pos.y - spherePos.y;//_qc_WaterPosition.y; //scene; //CubicSmin (dist, scene, 0.5);


				float toCamera = length(_WorldSpaceCameraPos - pos) - _ProjectionParams.y;
					float scene = SceneSdf(pos, 1);
					
				float scale = 0.012; 

				float gyr1Big = sdGyroid(pos + float3(0 ,_Effect_Time.x * 3/scale -10, 0) , 5*scale , 0.1   , 1 );
				float gyr2Big = sdGyroid(pos + float3(0, _Effect_Time.x * 1/scale -10, 0) , 4*scale , 0.1  , 1);
				float newGyrBig =  SmoothIntersection (gyr1Big, gyr2Big, 8 ); 
			
				float waveSize = smoothstep(0, 50, scene) * smoothstep(2000 ,0 ,toCamera);

				float dist = lerp(baseFloor, newGyrBig, 0.005 * waveSize * _Waves); // *scene);

				float3 miniGrPos = pos;

				miniGrPos.y = 0;

				float gyr = sdGyroid(miniGrPos + float3(0 ,_Effect_Time.x * 10 -10, 0) , 5 , 0.1   , 1 );
				float gyr2 = sdGyroid(miniGrPos + float3(0, _Effect_Time.x * 4 -10, 0) , 4 , 0.1  , 1);
				float smallGyr =  SmoothIntersection (gyr, gyr2, 0.1 ); 

				dist = lerp(dist, smallGyr, 0.2 * _Waves); // *smoothstep(-1, 2 + toCamera * 0.2, dist - baseFloor)); // *scene);
			


			

				dist = CubicSmin(dist, scene-0.1, 2);


			//	dist = lerp(baseFloor, dist, 0.2 * waveSize);


			//	return dist;
		
			//	dist = CubicSmin(dist, dynamics, 0.4);

			


			//	dist = OpSmoothSubtraction(dist, dynamics, 0.075);

				//dist = OpSmoothSubtraction(dist, 1 - pos.y, 0.4);

				return  dist;
			}

		ENDCG

		Pass{

			Tags
			{
				"LightMode" = "ForwardBase"
			
			}

			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite On
			ZTest On
			Cull Off
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
				//float3 tc_Control : TEXCOORD2;
				float4 worldPos : TEXCOORD4;
				fixed4 color : COLOR;
			};

			float4 _Global_Noise_Lookup_TexelSize;
		
		
			v2f vert(appdata_full v) 
			{
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);
				//o.centerPos = PositionAndSizeFromMatrix();
				//MARCH_SETUP_CENTER_POS_VERT(o.centerPos);
				o.worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)) - float4(0,0.2,0,0);

				o.pos = UnityWorldToClipPos(mul(unity_ObjectToWorld, v.vertex));
				o.screenPos = ComputeScreenPos(o.pos);
				 COMPUTE_EYEDEPTH(o.screenPos.z);
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.color = v.color;
				//o.tc_Control = WORLD_POS_TO_TERRAIN_UV_3D(worldPos);

				return o;
			}

			float4 _Color;

			fixed4 frag(v2f i) : SV_TARGET
			{
				float3 viewDir = normalize(i.viewDir.xyz);
				float2 screenUv = i.screenPos.xy / i.screenPos.w;

				float depth = SampleTrueDepth(viewDir, screenUv);

				float4 centerPos = float4(i.worldPos.xyz,10000);

				RAYMARCH_WORLD(SampleSDF, newPos, viewDir, depth, centerPos);

			//	float3 terrainUV = WORLD_POS_TO_TERRAIN_UV_3D(newPos);

			//	float4 terrain = tex2D(_qcPp_mergeTerrainHeight, terrainUV.xz);
					
				//float3 terrainNormal = (terrain.rgb - 0.5)*2;
			//	float aboveTerrain = (newPos.y - _qcPp_mergeTeraPosition.y) - terrain.a*_qcPp_mergeTerrainScale.y;

			//	float foam = smoothstep( 0, 1, (newPos.y - _qc_WaterPosition.y) * 0.5 + smoothstep(6, -1, aboveTerrain));

				INIT_SDF_NORMAL(normal, newPos, centerPos, SampleSDF);


				//normal = lerp(terrainNormal, normal, smoothstep(0,1, aboveTerrain) );

				float fresnel = smoothstep(0, 1 , dot(viewDir, normal));

				float3 reflectedRay = reflect(-viewDir, normal);
				float reverse = smoothstep(0,-0.001, reflectedRay.y);
				reflectedRay = normalize(lerp(reflectedRay, reflect(reflectedRay, float3(0,1,0)), reverse));

				float4 col;

		
					float3 reflectionPos;
					float outOfBoundsRefl;
					float shadow = 1;

					float3 bakeReflected = SampleRay(newPos, reflectedRay, shadow, reflectionPos, outOfBoundsRefl);

					TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);

					col.rgb = bakeReflected;
		

				
				
			

				float toCamera = length(_WorldSpaceCameraPos - newPos) - _ProjectionParams.y;

				float waterThickness = (depth - toCamera);

				float showSky = 0.25 + (1-fresnel) * 0.75;

				col.a = showSky;

				//col = lerp(col, float4(GetAvarageAmbient(normal).rgb,1) , foam);

				col.rgb = lerp( _Color.rgb, col.rgb, col.a);

			//	float hideTerrain = smoothstep(0, 1 + 10 * (1- foam) , waterThickness);

			//	col.a = hideTerrain; 

				ApplyBottomFog(col.rgb, newPos, viewDir.y);

				return col;
			}
			ENDCG
		}
	}
}
