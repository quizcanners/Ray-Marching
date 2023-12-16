Shader "RayTracing/Effect/Volumetric SDF Shape Collection"
{
	Properties
	{
		//_Size("Size", Range(0.01,5)) = 1

		[KeywordEnum(Sphere, Box, BoundingBox, Torus, Cone, CappedCone, SolidAngle, CappedTorus, Capsule, Cylinder, HexPrism, Pyramid, Octohedron, TriPrism, Ellipsoid, Rhombus, OctogonPrism, RoundCone)]	SHAPE("Shape", Float) = 0
		[KeywordEnum(Matt, Mirror, Glow)]	SURFC("Surface", Float) = 0
		[KeywordEnum(None, Sin)]	EFFECT("Effect", Float) = 0

		[Toggle(MESH_POS)] thisDoesntMatter("Position Baked Into Mesh", Float) = 0
		

	}

	SubShader{
		Tags
		{ 
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent" 
			//"DisableBatching" = "True"
			"LightMode" = "ForwardBase"
		}

		Blend One OneMinusSrcAlpha
		ZWrite off
		ZTest off
		Cull Front // Enable after Ray Marching isOn

		Pass{
			Tags {"LightMode" = "ForwardBase"}

			CGPROGRAM

			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"
			//#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Sampler.cginc"
		
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

			#pragma multi_compile_instancing
			#pragma shader_feature_local SHAPE_SPHERE SHAPE_BOX SHAPE_BOUNDINGBOX SHAPE_TORUS SHAPE_CONE SHAPE_CAPPEDCONE SHAPE_SOLIDANGLE SHAPE_CAPPEDTORUS SHAPE_CAPSULE SHAPE_CYLINDER SHAPE_HEXPRISM SHAPE_PYRAMID SHAPE_OCTOHEDRON SHAPE_TRIPRISM SHAPE_ELLIPSOID SHAPE_RHOMBUS SHAPE_OCTOGONPRISM SHAPE_ROUNDCONE
			#pragma shader_feature_local SURFC_MATT SURFC_MIRROR SURFC_GLOW
			#pragma shader_feature_local EFFECT_NONE EFFECT_SIN 
			#pragma shader_feature_local ____ MESH_POS 
			

			struct v2f {
				float4 pos: SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float3 viewDir		: TEXCOORD2;
				
				#if MESH_POS
					float3 meshPos : TEXCOORD4;
					float3 meshSize : TEXCOORD5;
					float4 meshQuaternion : TEXCOORD6;
				#else
					float3 objViewDir : TEXCOORD4;
					float3 objCamPos : TEXCOORD5;
				#endif

				fixed4 color : COLOR;
			};

			//sampler2D_float _CameraDepthTexture;
			

			//the vertex shader function
			v2f vert(appdata_full v) {
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);

				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.pos = UnityWorldToClipPos(o.worldPos);
				o.screenPos = ComputeScreenPos(o.pos);

				//Find the view-space direction of the far clip plane from the camera (which, when interpolated, gives us per pixel view dir of the scene position)
				//o.viewDir = mul(unity_CameraInvProjection, float4 (o.screenPos.xy * 2.0 - 1.0, 1.0, 1.0));
				o.viewDir = WorldSpaceViewDir(v.vertex);
			
				#if MESH_POS
					o.meshPos = v.texcoord;
					o.meshSize = v.texcoord1;
					o.meshQuaternion = v.texcoord2;
				#else
					o.objViewDir = ObjSpaceViewDir(v.vertex);
					o.objCamPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;
				#endif

				o.color = v.color;
				return o;
			}

			float sdSolidAngle(float3 pos)
			{
				float2 c = float2(3, 4) / 5;
				float ra = 0.4;

				float2 p = float2(length(pos.xz), pos.y);
				float l = length(p) - ra;
				float m = length(p - c * clamp(dot(p, c), 0.0, ra));
				return max(l, m * sign(c.y * p.x - c.x * p.y));
			}
			
			//float _Size;

			float SampleSDF (float3 pos, float3 camPos, float size)
			{
				#if EFFECT_SIN
					pos.x += sin(pos.x*20 + _Time.y)*0.1;
				#endif

				float dist =
				#if SHAPE_ROUNDCONE
					sdRoundCone(pos);
				#elif SHAPE_SOLIDANGLE
					sdSolidAngle(pos);

				//#elif SHAPE_BOX 
				#elif SHAPE_BOUNDINGBOX 
					sdBoundingBox(pos, float3(0.3, 0.25, 0.2), 0.025);
				#elif SHAPE_TORUS 
					sdTorus((pos).xzy , float2(0.25, 0.05 ));
				#elif SHAPE_CONE 
					sdCone(pos - float3(0,0.4 + size * 0.25,0) , float2(0.6, 0.8), 0.65 * size);
				#elif SHAPE_CAPPEDCONE  
					sdCappedCone(pos - float3(0, 0.2, 0), 0.25, 0.25, 0.1);
				#elif SHAPE_CAPPEDTORUS 
					sdCappedTorus((pos) - float3(0, 0.2, 0), float2(0.866025, -0.5), 0.25, 0.05);
				#elif SHAPE_CAPSULE 
					sdCapsule(pos - float3(0,-0.25,0), float3(-0.1, 0.1, -0.1), float3(0.2, 0.4, 0.2), 0.1);
				#elif SHAPE_CYLINDER 
					sdCylinder(pos, float2(0.15, 0.25));
				#elif SHAPE_HEXPRISM 
					sdHexPrism(pos, float2(0.2, 0.05));
				#elif SHAPE_PYRAMID 
					sdPyramid(pos - float3(0,-0.5,0), 1.0);
				#elif SHAPE_OCTOHEDRON 
					sdOctahedron(pos, 0.35);
				#elif SHAPE_TRIPRISM 
					sdTriPrism(pos, float2(0.3, 0.05));
				#elif SHAPE_ELLIPSOID
					sdEllipsoid(pos, float3(0.2, 0.25, 0.05));
				#elif SHAPE_RHOMBUS 
					sdRhombus((pos).xzy, 0.15, 0.25, 0.04, 0.08);
				#elif SHAPE_OCTOGONPRISM
					sdOctogonPrism(pos, 0.2, 0.05);
				#else
					SphereDistance(pos, 0.5 * size);
				#endif

				//dist = OpSmoothSubtraction(dist, length(pos - camPos) - 0.5, 0.01);

				return  dist;
			}

			float SdfShadow(in float3 ro, float3 camPos, float size)
			{
				float3 rd = mul(unity_WorldToObject, float4(normalize(_WorldSpaceLightPos0.xyz), 0)).xyz;
				float res = 1.0;
				float t = 0.01;//mint;

				for (int i = 0; i < 100; i++)
				{
					float h = SampleSDF(ro + rd * t, camPos, size);
					res = min(res, 8.0 * h / t);
					t += clamp(h, 0., 0.1);
					if (t > 5000) 
						break;
				}
				return clamp(res, 0.0, 1.0);
			}

			inline float3 SdfNormal(float3 pos, float3 camPos, float size) 
			{
				float EPSILON = 0.01f;
				float center = SampleSDF(float3(pos.x, pos.y, pos.z), camPos, size);
				return normalize(float3(
					center - SampleSDF(float3(pos.x - EPSILON, pos.y, pos.z), camPos, size),
					center - SampleSDF(float3(pos.x, pos.y - EPSILON, pos.z), camPos, size),
					center - SampleSDF(float3(pos.x, pos.y, pos.z - EPSILON), camPos, size)));
			}

			fixed4 frag(v2f i) : SV_TARGET
			{
				float3 viewDir = normalize(i.viewDir.xyz);
				float2 screenUv = i.screenPos.xy / i.screenPos.w;

				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUv);
				float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));

				float4 ray = mul(unity_CameraInvProjection, float4 (screenUv * 2.0 - 1.0, 1.0, 1.0));

				float3 wCamPosObjSpace;
				float3 vDirObjSpace;
				float size;
				#if MESH_POS
					size = i.meshSize.x;
					float4 q = i.meshQuaternion;
					float3 pos = i.meshPos;
					vDirObjSpace = -normalize(RotateVec(viewDir, q));
					wCamPosObjSpace = RotateVec(_WorldSpaceCameraPos - pos,q);

					float depth01 = Linear01Depth(depth);
					float trueDist = length((ray.xyz / ray.w) * depth01);

					float viewPosConvert = length(trueDist * viewDir);

					float4 inverseQuaternion = float4(-q.x, -q.y, -q.z, q.w);
				#else
					size = 1;
					vDirObjSpace = -normalize(i.objViewDir);
					wCamPosObjSpace = i.objCamPos;
				#endif


				float3 ro = wCamPosObjSpace; //+ (noise.rgb - 0.5) * 0.0005;
				float3 rd = vDirObjSpace;
				
				float totalDistance = 0;
				float dist = 0;

				const float MAX_DISTANCE = 10000;

				float minDist = MAX_DISTANCE;
			

				for (int ind = 0; ind < 100; ind++)
				{
					dist = SampleSDF(ro, wCamPosObjSpace, size);

					#if !EFFECT_NONE
						dist *= 0.5;
					#endif

					ro += dist * rd;

					totalDistance += dist;

					#if SURFC_GLOW
					minDist = min(dist, minDist);
					#endif

					if (abs(dist - (MAX_DISTANCE * 0.5 + 0.001))> MAX_DISTANCE*0.5)
					{
						ind = 999;
						#if !SURFC_GLOW
							clip(MAX_DISTANCE  - 10 - dist);
						#endif
					}
				}

				float3 normal;
				float3 newPos;
#if MESH_POS
				newPos = pos + RotateVec(ro, inverseQuaternion);
				float distance = length(_WorldSpaceCameraPos - newPos); // -_ProjectionParams.z; // -mul(UNITY_MATRIX_V, float4(newPos, 1)).z;
				float alpha = smoothstep(0, distance * 0.01, viewPosConvert - distance);

				normal = normalize(RotateVec(float4(SdfNormal(ro, wCamPosObjSpace, size), 0), inverseQuaternion));
				
#else
				normal = normalize(mul(unity_ObjectToWorld, float4(SdfNormal(ro, wCamPosObjSpace, size), 0)));
				newPos = mul(unity_ObjectToWorld, float4(ro, 1)).xyz;
				float distance = -mul(UNITY_MATRIX_V, float4(newPos, 1)).z;
				float alpha = smoothstep(0, distance * 0.01, sceneZ - distance);
#endif


			

				float fresnel = dot(viewDir, normal);
				float4 col = i.color;
#if SURFC_MATT 
				float outOfBounds;
				float4 vol = SampleVolume(newPos, outOfBounds);

				float3 ambientCol = lerp(vol, GetAvarageAmbient(normal), outOfBounds);

				float direct = saturate((dot(normal, _WorldSpaceLightPos0.xyz)));
				float3 lightColor = GetDirectional() * direct;
				

				float2 topdownUv = (newPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;
				float4 tdUv = float4(topdownUv + normal.xz * _RayTracing_TopDownBuffer_Position.w, 0, 0);

				float4 topDown = tex2D(_RayTracing_TopDownBuffer, topdownUv);
				float4 topDownRefl = tex2Dlod(_RayTracing_TopDownBuffer, tdUv);

				float topDownVisible = (1 - outOfBounds) * smoothstep(3, 0, abs(_RayTracing_TopDownBuffer_Position.y - newPos.y));
				topDown *= topDownVisible;
				topDownRefl *= topDownVisible;
				float ambientBlock = max(0.25f, 1 - topDown.a);
				ambientCol *= ambientBlock;
				ambientCol.rgb += topDown.rgb + topDownRefl.rgb;
			
				
				col.rgb *= ambientCol + lightColor;

				//alpha *= smoothstep(0, 0.05, fresnel);
#elif SURFC_MIRROR

				float3 reflectedRay = reflect(-viewDir, normal);

				float2 MIN_MAX = float2(0.0001, MAX_DIST_EDGE);
				float3 normalTmp;

				float3 sky = getSkyColor(reflectedRay);

				float4 mat = float4(sky, 1); // RGB = color

				float3 startPos = newPos; 

				float3 res = worldhit(startPos, reflectedRay, MIN_MAX, normalTmp, mat);
				float reflectedDistance = res.y;
				float3 reflectionPos = startPos + reflectedRay * reflectedDistance;

				
				float outOfBounds;
				float4 sdfNnD = SampleSDF(reflectionPos, outOfBounds);
				
				normalTmp = sdfNnD.rgb;

				float outOfBoundsRefl;
				float4 bakeReflected = SampleVolume_CubeMap(reflectionPos, normalTmp, outOfBoundsRefl);

				float3 colorReflected = _RayMarchSkyColor * (1 + max(0, reflectedRay.y)) * 0.5;
				float reflectedDirectional = max(0, dot(normalTmp, _WorldSpaceLightPos0.xyz));
				colorReflected += (unity_FogColor) * 0.075;
				bakeReflected.rgb = lerp(bakeReflected.rgb, sky, outOfBoundsRefl); 

				float2 topdownUv = (reflectionPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;
				float4 tdUv = float4(topdownUv + normal.xz * _RayTracing_TopDownBuffer_Position.w, 0, 0);
				float4 topDown = (tex2Dlod(_RayTracing_TopDownBuffer, tdUv) + tex2D(_RayTracing_TopDownBuffer, topdownUv)) * 0.5;
				float topDownVisible = (1 - outOfBoundsRefl) * smoothstep(3, 0, abs(_RayTracing_TopDownBuffer_Position.y - reflectionPos.y));
				topDown *= topDownVisible;
				float ambientBlock = max(0.25f, 1 - topDown.a);
				bakeReflected *= ambientBlock;
				bakeReflected.rgb += topDown.rgb;

				col.rgb = bakeReflected.rgb;
#elif SURFC_GLOW

				float glow = smoothstep(0.1,0, minDist);
				col *= min(smoothstep(1,0.5,fresnel), pow(glow, 3)) * alpha;
				return col;
#endif

				ApplyBottomFog(col.rgb, newPos, viewDir.y);

				col.a = alpha;
				col.rgb *= alpha;

				return col;
			}

			ENDCG
		}
	}
}