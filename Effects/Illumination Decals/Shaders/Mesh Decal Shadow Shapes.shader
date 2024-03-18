Shader "Quiz cAnners/Illumination/Shadow Decal Shapes" 
{
	Properties
	{
		[KeywordEnum(Sphere, Box, Capsule, Sdf)]	Shape ("Shape", Float) = 0
		_Volume ("Sdf Texture", 3D) = "" {}
		[Toggle(_DEBUG)] debugMode ("Debug Mode", Float) = 0  
	}

	Category
	{
		Tags
		{
			"Queue" = "Transparent"
			"PreviewType" = "Plane"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
		}

		Cull Front
		ZWrite Off
		ZTest Off
		ColorMask RGBA
	
		Blend One One
					//SrcAlpha OneMinusSrcAlpha

		SubShader
		{
			Pass
			{
				CGPROGRAM

				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"
				#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"
				#include "Assets/Qc_Rendering/Shaders/inc/RayDistanceOperations.cginc"
				#include "Assets/Qc_Rendering/Shaders/inc/SDFoperations.cginc"

				#include "Assets/Qc_Rendering/Shaders/Signed_Distance_Functions.cginc"
				#include "Assets/Qc_Rendering/Shaders/RayMarching_Forward_Integration.cginc"

				#include "Savage_Shadows.cginc"

				#pragma shader_feature_local SHAPE_SPHERE SHAPE_BOX SHAPE_CAPSULE SHAPE_SDF
				#pragma shader_feature_local  ____ _DEBUG



				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fwdbase
				#pragma multi_compile_instancing
				#pragma target 3.0

				v2fMarchBatchableTransparent vert(appdata_full v) 
				{
					v2fMarchBatchableTransparent o;
					InitializeBatchableTransparentMarcher(v,o);
					return o;
				}

				uniform sampler3D _Volume;
			//	uniform float4 qc_SunBackDirection;

				float4 frag(v2fMarchBatchableTransparent i) : COLOR
				{
					i.rayDir = normalize(i.rayDir);

					float3 rd = qc_SunBackDirection.xyz;//
					//_WorldSpaceLightPos0.xyz; // Probably this one is the issue
					
					float size = i.centerPos.w;

					float minSize = i.meshSize.w;
					
					float3 ro = GetRayPoint(-i.rayDir, i.screenPos.xy / i.screenPos.w);

					float3 pos = i.centerPos;

					float shadow = 0;
					float ao = 0;
					float4 q = i.meshQuaternion;
					float4 invRot = q;
					invRot.xyz= -invRot.xyz;

					float outsideVolume;
					float4 scene = SampleSDF(ro , outsideVolume);

					#if SHAPE_SDF

						float3 relativePos = ro- pos.xyz;

						float3 approxNormal = normalize(relativePos);

						relativePos = Rotate(relativePos,q);
						relativePos /= i.meshSize.xyz;

						float3 relPos = relativePos + 0.5;

						float EPSILON = 0.02f;

						float3 left = float3(relPos.x - EPSILON, relPos.y, relPos.z);
						float3 down = float3(relPos.x, relPos.y - EPSILON, relPos.z);
						float3 back = float3(relPos.x, relPos.y, relPos.z - EPSILON);

						float center = tex3D (_Volume, relPos);

						float3 normal = normalize(float3(
							center - tex3D(_Volume, left).r,
							center - tex3D(_Volume, down).r,
							center - tex3D(_Volume, back).r
							));

						normal = Rotate(normal,invRot);

						float outsideTheBox = length(max(0, abs(relativePos) - 0.4));

						float dist = (center + outsideTheBox) * size ;

						#if _DEBUG
							float outside = saturate(center*100);
							float inside = saturate(-center*100);
							float alright = saturate(1 - outside - inside);
							return float4(outside,alright,inside,1-outsideTheBox); ///(1+abs(center) * 200);
						#endif

						float fadeNormalOverDist = smoothstep(0.5, 0 ,center);

						float wallByNormal = dot(-normal, scene.xyz);


						float wallByRawNormal = dot(-approxNormal, scene.xyz);


						float facingWall = max(wallByNormal, 0.5);

					//	scene.a = 0;

						float addedDistance = scene.a + dist;

						float clipSdf = smoothstep(0.2 * minSize, 0,addedDistance);


						float aoBySize = minSize/(minSize + pow(addedDistance, 2)) * clipSdf;

						ao = saturate(max(0,wallByNormal) * aoBySize-0.01);//saturate(minSize * max(0,facingWall) /(minSize + pow(scene.a + dist, 2)) - 0.01);

					//	ao += (1-ao) * smoothstep(0, -0.01, center) * 0.5;

						// marching the SDF
						float3 start = relativePos;
						float3 dir = Rotate(rd, q);

						dir /= i.meshSize.xyz;
						dir = normalize(dir);

						float t = center + 0.01;
						int maxSteps = 15;
						float light = 1;
						float koefficient = 0.1;
						float sdfDist = 0;
						float bias = 0;

						for (int i=0; i<maxSteps; i++)
						{
							float3 newPos = start + dir * t;
							sdfDist = tex3D (_Volume, newPos + 0.5);
							outsideTheBox = max(0,  length(max(0, abs(newPos)- 0.5)));
							sdfDist += outsideTheBox;
							bias = smoothstep(0.01, 0.02,t);
							float newRes = min(light, max(0, sdfDist + koefficient * t * 0.1)/(koefficient * t));
							light  = lerp(light, newRes,  bias);

							t += max(0.05, sdfDist);

							if (light < 0.1)
								break;
						}
				
						float nearHit = smoothstep(0.1, 0, sdfDist) * sharpstep(0.1, 0.3, t);

						shadow = smoothstep(1,0, light - nearHit);


					#elif SHAPE_SPHERE 

						float3 toCenterVector = (ro - pos); 
						float dist = length(toCenterVector);
						float newSize = size * 0.34;

						float distanceToSurface = max(0,  dist - newSize); // Is Correct

						

						#if _DEBUG
							return float4(scene.xyz,1) + 0.1;
						#endif

						float sharpness = 2;

						float lght = sphereShadow(ro, rd, float4(pos, newSize),  sharpness); // Not correct for second camera

					

						float fadingShadow = smoothstep(size*3, size, distanceToSurface ); 

						shadow = saturate(1 - lght) * fadingShadow;

						float3 normal = normalize(toCenterVector);

						float facingWall = max(0,dot(-normal, scene.xyz));

						ao = saturate(facingWall * newSize /(newSize + pow(scene.a + distanceToSurface,2)) - 0.05) ;

					#elif SHAPE_BOX
						
						float3 normal;
						float dist = iBoxRot(ro- pos.xyz, rd, q, float2(0.001,20000), normal, i.meshSize.xyz * 0.48);

						shadow = smoothstep(100 ,10,dist);

						// Ambient
			
						#define SAMPLE_CUBE(ro) CubeDistanceRot(ro, q , float4(pos.xyz, 0), i.meshSize.xyz* 0.5, size * 0.25 )

						float center = SAMPLE_CUBE(ro);

						float EPSILON = 0.01f;

						float3 left = float3(ro.x - EPSILON, ro.y, ro.z);
						float3 down = float3(ro.x , ro.y - EPSILON, ro.z);
						float3 back = float3(ro.x , ro.y, ro.z- EPSILON);

						normal = normalize(float3(
							center - SAMPLE_CUBE(left),
							center - SAMPLE_CUBE(down),
							center - SAMPLE_CUBE(back)
							));

						float facingWall = max(0,dot(-normal, scene.xyz));

						ao = saturate(facingWall * size /(size + pow(scene.a + center,3)) - 0.1) ;

				#elif SHAPE_CAPSULE

						float3 localOffset = RotateVec(pos - ro,q) / i.meshSize.xyz;

						float3 lineDirection = Rotate(float3(0,0,1),invRot);

						float3 farPoint = ro + rd * 1000;

						float toDepth;
						float fromCameraToLine;
						float combinedDistance = GetDistanceToSegment(ro, rd, pos, lineDirection,  size * 0.6, farPoint, toDepth, fromCameraToLine);

						float objectRadius = minSize * 0.5; 
						objectRadius*=objectRadius;

						float softness = fromCameraToLine * 0.1;

						shadow = smoothstep(objectRadius + softness , objectRadius - softness*softness , combinedDistance*combinedDistance ); ///(1+softness * 0.1);
					
						float3 len = abs(localOffset);
						float maxExtendSharp = smoothstep(1, 0.99, max(len.x, max(len.y, len.z)));

						#if _DEBUG
							return float4(0.1, ao, shadow, 0);
						#endif


					#endif


					return float4(0, ao, shadow, 0) ; 
				}
				ENDCG
			}
		}
		Fallback "Legacy Shaders/Transparent/VertexLit"
	}
}

