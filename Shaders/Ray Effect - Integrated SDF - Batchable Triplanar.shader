Shader "RayTracing/Integrated SDF/Triplanar"
{
	Properties
	{
		_HorizontalTiling("Horizontal Tiling", float) = 1
		[NoScaleOffset]_MainTex("Horisontal (RGB)", 2D) = "white" {}
		[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		[NoScaleOffset] _Map("Bump/Combined Map (or None)", 2D) = "gray" {}


		[NoScaleOffset]_MainTexTop("Top (RGB)", 2D) = "white" {}
		[NoScaleOffset] _MapTop("Bump/Combined Map (or None)", 2D) = "gray" {}

		_BlendSmoothness("Blend Smoothness", Range(0,1)) = 0.2

		[KeywordEnum(Tombs, Buildings)] _SHAPE("Shape", Float) = 0
		[KeywordEnum(None, Slime)] _EFFECT("Effect", Float) = 0
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

		#include "Assets/Ray-Marching/Shaders/Savage_DepthSampling.cginc"

		#pragma shader_feature_local _EFFECT_NONE _EFFECT_SLIME
		#pragma shader_feature_local _SHAPE_TOMBS _SHAPE_BUILDINGS

		float4 _Effect_Time;
		float _BlendSmoothness;

		#define SUBTRACT(FROM, VAL, COEF) OpSmoothSubtraction(FROM, VAL,COEF* smoothness);
		#define INTERSECT(A,B,COEF) SmoothIntersection(A, B, COEF* smoothness);
		#define ADD(A,B,COEF) CubicSmin(A, B, COEF * smoothness);

		float getFlow(float3 pos)
		{
			const float GYR_UPSCALE = 0.345;
			return sdGyroid((pos + float3(0, _Time.y, 0)) * GYR_UPSCALE + 1.2345, 1.1) / GYR_UPSCALE;
		}

	
		float SampleSDF_Buildings(float3 pos, float4 spherePos, float4 rotation, float4 size, float smoothness)
		{
			float scale = spherePos.w;

			smoothness *= _BlendSmoothness;

			// BENDED SPACE

			float dist = CubeDistanceRot(pos, rotation, spherePos, size.xyz * 0.5, smoothness);

			float cutting = CubeDistanceRot(pos, rotation, spherePos, size.xyz * float3(0.48, 0.48, 0.6), smoothness);
			//dist = SUBTRACT(dist, cutting, 1);

			cutting = min(cutting, CubeDistanceRot(pos, rotation, spherePos, size.xyz * float3(0.48, 0.6, 0.48), smoothness));
			//	dist = SUBTRACT(dist, cutting, 1);

			cutting = min(cutting, CubeDistanceRot(pos, rotation, spherePos, size.xyz * float3(0.6, 0.48, 0.48), smoothness));
			dist = SUBTRACT(dist, cutting, 1);


			float CELL_SIZE = 10;
		//	float3 pillarPos = abs(((pos) % CELL_SIZE)) - CELL_SIZE * 0.5;


		//	float3 absPillarPosPos = abs(pillarPos);

		//	float vericalSlicing = SmoothIntersection(absPillarPosPos.x, absPillarPosPos.z , smoothness) - CELL_SIZE * 0.2;

			float HEX_SIZE = 16;
			float3 scaledPos = pos / HEX_SIZE + 100;
			scaledPos -= scaledPos % 1;
			float3 seed = hash33(scaledPos);
			
			float3 hexPos = abs((pos + seed * 0.05) % HEX_SIZE) - HEX_SIZE * 0.5;

			dist = ADD(dist, CubeDistance_Inernal(hexPos, HEX_SIZE *float3(0.35,0.6, 0.35)), 1);


			//float gyr = sdGyroid(pos, 2, 1, 1.5);
			//dist = lerp(dist, gyr, 0.6);

			
			float ROOMS_SIZE = 80;
			scaledPos = abs(pos % ROOMS_SIZE) - ROOMS_SIZE * 0.5;
			dist = SUBTRACT(dist, CubeDistance_Inernal(scaledPos, ROOMS_SIZE * float3(0.4, 0.3, 0.35)), 1);
	
			// Corridors
			dist = SUBTRACT(dist, CubeDistance_Inernal(scaledPos + float3(0, ROOMS_SIZE *0.2,0), ROOMS_SIZE * float3(0.1, 0.1, 1)), 1);
			dist = SUBTRACT(dist, CubeDistance_Inernal(scaledPos + float3(0, ROOMS_SIZE * 0.2, 0), ROOMS_SIZE * float3(1, 0.1, 0.1)), 1);

			// cealing
			dist = ADD(dist, CubeDistance_Inernal(scaledPos - float3(0, ROOMS_SIZE * 0.35, 0), ROOMS_SIZE * float3(1, 0.05, 1)), 1);

			//*********************************** floor
			dist = ADD(dist, CubeDistance_Inernal(scaledPos + float3(0, ROOMS_SIZE * 0.32, 0), ROOMS_SIZE * float3(0.4, 0.01, 0.35)), 1);


			return dist;
		}



		float SampleSDF_Pillars(float3 pos, float4 spherePos, float4 rotation, float4 size, float smoothness)
		{
			float scale = spherePos.w;

			smoothness *= _BlendSmoothness;

			// BENDED SPACE

			float CELL_SIZE = 10;
			float3 pillarPos = abs(((pos) % CELL_SIZE)) - CELL_SIZE * 0.5;


			float3 absPillarPosPos = abs(pillarPos);

			float thickening = -pillarPos.y * 0.25;

			float vericalSlicing = SmoothIntersection(absPillarPosPos.x + thickening, absPillarPosPos.z + thickening, smoothness) - CELL_SIZE * 0.2;

			float HEX_SIZE = 2;

			float3 scaledPos = pos / HEX_SIZE + 100;

			scaledPos -= scaledPos % 1;

			float3 seed = hash33(scaledPos);

			float3 hexPos = abs((pos + seed * 0.05) % HEX_SIZE) - HEX_SIZE * 0.5;
			float prism = sdHexPrism(hexPos + (seed - 0.5) * 0.01, float2(0.8 - smoothness * 0.2, 0.7)) - smoothness * 0.1;

			vericalSlicing = SUBTRACT(vericalSlicing, prism, 0.2);

			float flooring = -absPillarPosPos.y + CELL_SIZE * 0.3;

			float dist = ADD(flooring, vericalSlicing, 1); // OpSmoothSubtraction(sDist, pillar, smoothness); // max(sDist, -pillar);//OpSmoothSubtraction(sDist, box, _BlendSmoothness); // max(sDist, -box);



			return dist;
		}


		float SampleSDF_Internal (float3 pos, float4 spherePos, float4 rotation, float4 size, float smoothness)
		{

			float dist = 
#if _SHAPE_BUILDINGS
				SampleSDF_Buildings
#else 
				SampleSDF_Pillars
#endif
				
				(pos, spherePos, rotation, size, smoothness);


			float bounds = CubeDistanceRot(pos, rotation, spherePos, size.xyz * 0.5, smoothness);
			dist = INTERSECT(bounds, dist, 1);

#if _EFFECT_SLIME
			float gyr = getFlow(pos);
			gyr = INTERSECT(gyr, dist - 1.5, 5);
			dist = ADD(dist, gyr, 1);
#endif

			return dist;
		}
		
		float SampleSDF(float3 pos, float4 spherePos, float4 rotation, float4 size)
		{
			return SampleSDF_Internal(pos, spherePos, rotation, size, 1);
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

			#pragma shader_feature_local _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 
		

			struct v2f 
			{
				float4 vertex: SV_POSITION;
				float4 screenPos : TEXCOORD0;
			
				float3 viewDir		: TEXCOORD2;
				//float3 normal	: TEXCOORD3;
				
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
				//o.normal = UnityObjectToWorldNormal(v.normal);
			
				o.meshPos = v.texcoord;
				o.meshSize = v.texcoord1;
				o.meshQuaternion = v.texcoord2;

				o.meshSize.w =  min(o.meshSize.z, min(o.meshSize.x, o.meshSize.y));

				float maxSize = max(o.meshSize.z, max(o.meshSize.x, o.meshSize.y));

				o.centerPos = float4(o.meshPos.xyz, maxSize);

				o.color = v.color;
				return o;
			}




			sampler2D _MainTexTop;
			sampler2D _MapTop;
			sampler2D _MainTex;
			sampler2D _Map;
			float _HorizontalTiling;

			float GetShowNext(float currentHeight, float newHeight, float dotNormal)
			{
				return smoothstep(0, 0.2, newHeight * dotNormal - currentHeight * (1 - dotNormal));
			}


			void CombineMaps(inout float currentHeight, inout float4 bumpMap, out float3 tnormal, 
				out float showNew, float dotNormal, float2 uv)
			{
				float4 newbumpMap = 0.5;
				tnormal = 0.5;
			//	SampleBumpMap(_Map, newbumpMap, tnormal, uv);
				float newHeight = 0.5; //newbumpMap.a;// GetHeight(newbumpMap, tnormal, uv);

				showNew = GetShowNext(currentHeight, newHeight, dotNormal);
				currentHeight = lerp(currentHeight, newHeight, showNew);
				bumpMap = lerp(bumpMap, newbumpMap, showNew);
			}
		

			FragColDepth frag(v2f i)
			{
				MARCH_FROM_DEPTH_ROT(newPos, spherePos, shadow, viewDir, screenUv);

				INIT_SDF_NORMAL_ROT(normal, newPos, spherePos, SampleSDF);

				float external = CubeDistanceRot(newPos, i.meshQuaternion, spherePos, i.meshSize.xyz * 0.5, 0.1);

				float3 uvHor = newPos * 0.2 * _HorizontalTiling;

				// Horizontal Sampling X
				float3 tnormalX = 0.5;
				float4 bumpMapHor = 0.5;
				//SampleBumpMap(_Map, bumpMapHor, tnormalX, uvHor.zy);
				float horHeight = bumpMapHor.a;
				float4 tex = tex2D(_MainTex, uvHor.zy);

				float3 horNorm = float3(0, tnormalX.y, tnormalX.x);

				// Horixontal Sampling Z
				float3 tnormalZ;
				float showZ;
				CombineMaps(horHeight, bumpMapHor, tnormalZ, showZ,  abs(normal.z), uvHor.xy);
				float4 texZ = tex2D(_MainTex, uvHor.xy);
				tex = lerp(tex, texZ, showZ);

				horNorm = lerp(horNorm, float3(tnormalZ.x, tnormalZ.y, 0), showZ);

				// Update normal
				float horBumpVaidity = 1 - abs(horNorm.y);
				float3 tripNormal = normalize(normal + horNorm * horBumpVaidity);

				// Vertial Sampling

				float4 bumpMapTop = 0.5;
				float3 tnormalTop = 0.5;
				//SampleBumpMap(_MapTop, bumpMapTop, tnormalTop, uvHor.xz);
				float4 texTop = lerp(tex2D(_MainTex, uvHor.xz), tex2D(_MainTexTop, uvHor.xz), smoothstep(0.4, 0.5, normal.y));

				float topHeight = bumpMapTop.a;

				float3 topNorm = float3(tnormalTop.x, 0, tnormalTop.y);

				// Combine

				float showTop = GetShowNext(horHeight, topHeight, pow(abs(tripNormal.y), 2));

				float4 bumpMap = lerp(bumpMapHor, bumpMapTop, showTop);
				float height = lerp(horHeight, topHeight, showTop);

				tex = lerp(tex, texTop, showTop);

				float3 triplanarNorm = lerp(horNorm, topNorm, showTop);
#if _EFFECT_SLIME

				float flow = smoothstep(1,0.75, getFlow(newPos) + bumpMap.a );
				tex.rgb = lerp(tex.rgb, float3(0.02,0.01,0.02), flow);

				normal = lerp(normalize(tripNormal.xyz + triplanarNorm * 3), normal, flow);
#else
				normal = normalize(tripNormal.xyz + triplanarNorm * 3);
#endif
	
				PrimitiveLight(lightColor, ambientCol, outOfBounds, newPos, normal);
				TopDownSample(newPos, ambientCol);


				float sdfAO = SampleSDF_Internal(newPos, spherePos, i.meshQuaternion, i.meshSize, 4);
				sdfAO = smoothstep(-0.75, -0.01, sdfAO / (0.001 + _BlendSmoothness));
				
			
				float ambient = min(sdfAO, 0.5*(1 + smoothstep(-30, -2, external)));; 

				float4 col;
				col.rgb = tex.rgb* (lightColor * shadow + ambientCol * ambient);
				col.a = 1;

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
			Cull Off //Back//Front
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