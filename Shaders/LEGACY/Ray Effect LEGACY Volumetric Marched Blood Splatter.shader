Shader "RayTracing/LEGACY/Effect/Volumetric Blood Splatter"
{
	Properties
	{
		_Down("_Down", Range(0,1)) = 1
		_Gap("_Gap", Range(1,5)) = 1
		_Size("_Size", Range(0.02,0.1)) = 0.1
		_RndSeed("_RndSeed", Range(0.02,0.1)) = 0.1
		_Test("Test", Range(0.01,2)) = 1
	}

	SubShader{
		Tags
		{ 
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent" 
			"LightMode" = "ForwardBase"
		}

		Blend One OneMinusSrcAlpha
		ZWrite off
		ZTest off
		Cull Front // Enable after Ray Marching isOn

		Pass{
			Tags {"LightMode" = "ForwardBase"}

			CGPROGRAM

			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"
			#include "Assets/Qc_Rendering/Shaders/inc/SDFoperations.cginc"
			//#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Sampler.cginc"

			
			#include "Assets/Qc_Rendering/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Qc_Rendering/Shaders/RayMarching_Forward_Integration.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			#pragma multi_compile_instancing

			struct v2f {
				float4 pos: SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float3 viewDir		: TEXCOORD2;
				
				float3 objViewDir : TEXCOORD3;
				float3 objCamPos : TEXCOORD4;
				float3 centerPos : TEXCOORD5;
				fixed4 color : COLOR;
			};

		//	sampler2D_float _CameraDepthTexture;
			
			float4 _Global_Noise_Lookup_TexelSize;

			float _Size;
			float _Gap;
			float _Down;
			float _Test;
			float4 _Effect_Time;
			float _RndSeed;

			//the vertex shader function
			v2f vert(appdata_full v) {
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);

				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.centerPos = mul(unity_ObjectToWorld, float4(0,0,0,1));

				o.centerPos.y *= 0.1f;

				o.pos = UnityWorldToClipPos(o.worldPos);
				o.screenPos = ComputeScreenPos(o.pos);

				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
			
				o.objViewDir = ObjSpaceViewDir(v.vertex);
				o.objCamPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;

				o.color = v.color;
				return o;
			}

			float SampleSDF (float3 pos, float3 centerPos, float size)
			{
				float dist = 9999; 

				float3 segemntPos = pos + centerPos * 0.1;

				float3 segemntPosB = pos + centerPos * 0.05;

				float t = _Effect_Time.x * 0.5;

				float gyr = sdGyroid(segemntPos * 0.85  - float3(0, -t,0), 14, 0.1 , 1.5);


				float tinyGyr = sdGyroid(segemntPosB * 5 - float3(0, -t, 0), 13, 0.1, 1);
				gyr = CubicSmin(tinyGyr, gyr, 0.1 );

				float subtractiveGyr = sdGyroid(segemntPos * 0.6 + float3(0, -t * 2, 0), 15, 0.1 , 1.25); // General shape decision
				gyr = SmoothIntersection(gyr, subtractiveGyr, 0.09 * _Down);

				subtractiveGyr = sdGyroid(segemntPosB * 1.2  - float3(0, +t * 2, 0) , 17, 0.2 , 1); //
				gyr = SmoothIntersection(gyr, subtractiveGyr, 0.13);


				float cone = sdRoundCone(float3(pos.x,-pos.y,pos.z));
				return  SmoothIntersection(gyr, cone, 0.15);
			}

		
			float SdfShadow(in float3 ro, float3 centerPos, float size)
			{
				float3 rd = mul(unity_WorldToObject, float4(normalize(_WorldSpaceLightPos0.xyz), 0)).xyz;
				float res = 1.0;
				float t = 0.01;

				for (int i = 0; i < 100; i++)
				{
					float h = SampleSDF(ro + rd * t, centerPos, size);
					res = min(res, 8.0 * h / t);
					t += clamp(h, 0., 0.1);
					if (t > 5000) 
						break;
				}

			//	res *= smoothstep(0, 0.1, t-size);

		

				return clamp(res, 0.0, 1.0);
			}

			inline float3 SdfNormal(float3 pos, float3 centerPos, float size) 
			{
				float EPSILON = 0.01f;
				float center = SampleSDF(float3(pos.x, pos.y, pos.z), centerPos, size);
				return normalize(float3(
					center - SampleSDF(float3(pos.x - EPSILON, pos.y, pos.z), centerPos, size),
					center - SampleSDF(float3(pos.x, pos.y - EPSILON, pos.z), centerPos, size),
					center - SampleSDF(float3(pos.x, pos.y, pos.z - EPSILON), centerPos, size)));
			}

			fixed4 frag(v2f i) : SV_TARGET
			{
				float3 viewDir = normalize(i.viewDir.xyz);
				float2 screenUv = i.screenPos.xy / i.screenPos.w;

				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUv);
				float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));

				float3 wCamPosObjSpace;
				float3 vDirObjSpace;
				float size;

				size = 1;
				vDirObjSpace = -normalize(i.objViewDir);
				wCamPosObjSpace = i.objCamPos;
	
				float3 ro = wCamPosObjSpace; 
				float3 rd = vDirObjSpace;
				
				float dist = 0;

				float4 col = i.color;

				float3 rnd = i.centerPos + _RndSeed * 20;

				// TODO: Calculate Max Distance to limit tracing

				float max_distance = length(ro); // +size * 0.5;

				for (int ind = 0; ind < 128; ind++)
				{
					dist = SampleSDF(ro, rnd, size);
					ro += dist * rd;

					if (dist < 0.0001 || dist > max_distance) //abs(dist - (MAX_DISTANCE * 0.5 + 0.0001))> MAX_DISTANCE*0.5)
					{
						ind = 999;
						clip(max_distance - dist);
					}
				}

				float shadow = SdfShadow(ro, rnd, size);

				float3 normal;
				float3 newPos;

				normal = normalize(mul(unity_ObjectToWorld, float4(SdfNormal(ro, rnd, size), 0)));
				newPos = mul(unity_ObjectToWorld, float4(ro, 1)).xyz;
				float distance = -mul(UNITY_MATRIX_V, float4(newPos, 1)).z;
				float alpha = smoothstep(0, distance * 0.01, sceneZ - distance);

				float darken = smoothstep(0, 1, sceneZ - distance);

				clip(alpha - 0.001f);

				float fresnel = smoothstep(-1, 1 , dot(viewDir, normal));
		
				//return fresnel;

				float outOfBounds;
				float4 vol = SampleVolume(newPos, outOfBounds);

				float3 ambientCol = lerp(vol, GetAvarageAmbient(normal), outOfBounds);

				float direct = saturate((dot(normal, _WorldSpaceLightPos0.xyz)));
				float3 lightColor = _LightColor0.rgb * direct;
				

				float2 topdownUv = (newPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;
				float4 tdUv = float4(topdownUv + normal.xz * _RayTracing_TopDownBuffer_Position.w, 0, 0);

				float4 topDown = tex2D(_RayTracing_TopDownBuffer, topdownUv);

				// SSS
				tdUv = float4(topdownUv - normal.xz * _RayTracing_TopDownBuffer_Position.w * 4, 0, 0);
				float4 topDownSSS = tex2D(_RayTracing_TopDownBuffer, topdownUv);

				float topDownVisible = (1 - outOfBounds) * smoothstep(3, 0, abs(_RayTracing_TopDownBuffer_Position.y - newPos.y));
				topDown *= topDownVisible;
				float ambientBlock = max(0.25f, 1 - topDown.a);
				ambientCol *= ambientBlock;
				ambientCol.rgb += topDown.rgb * (1 - fresnel * 0.5) + topDownSSS.rgb;


				col.rgb = float3(0.9 - 0.6 * fresnel, 0.01, 0.01) * 0.5 *
					(ambientCol + lightColor * shadow);

				// REFLECTION
				float3 reflectedRay = reflect(-viewDir, normal);

				float2 MIN_MAX = float2(0.0001, MAX_DIST_EDGE);
				float3 normalTmp;

				float3 sky = getSkyColor(reflectedRay);

				float4 mat = float4(sky, 1); // RGB = color

				float3 startPos = newPos;

				float3 res = worldhit(startPos, reflectedRay, MIN_MAX, normalTmp, mat);
				float reflectedDistance = res.y;
				float3 reflectionPos = startPos + reflectedRay * reflectedDistance;

					float outOfBoundsSdf;
					float4 sdfNnD = SampleSDF(reflectionPos, outOfBoundsSdf);
				normalTmp = sdfNnD.rgb;

				float3 bakeReflected = SampleVolume_CubeMap(reflectionPos, normalTmp);

				float3 colorReflected = GetAvarageAmbient(normalTmp) * (1 + max(0, reflectedRay.y)) * 0.5;
				float reflectedDirectional = max(0, dot(normalTmp, _WorldSpaceLightPos0.xyz));
				colorReflected += (unity_FogColor) * 0.075;

				
				topdownUv = (reflectionPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;
				//tdUv = float4(topdownUv + normal.xz * _RayTracing_TopDownBuffer_Position.w, 0, 0);
				topDown =// (
					tex2D(_RayTracing_TopDownBuffer, topdownUv); //+ tex2D(_RayTracing_TopDownBuffer, topdownUv)
					//) * 0.5;
				topDownVisible = smoothstep(3, 0, abs(_RayTracing_TopDownBuffer_Position.y - reflectionPos.y));
				topDown *= topDownVisible;
				ambientBlock = max(0.25f, 1 - topDown.a);
				bakeReflected *= ambientBlock;
				bakeReflected.rgb += topDown.rgb;// *(1 - fresnel);


				col.rgb += bakeReflected.rgb * 0.5f *float3(1, 0.03, 0.03);

				ApplyBottomFog(col.rgb, newPos, viewDir.y);

				col.a = alpha;
				col.rgb *= alpha * ( 1 + darken) * 0.5f;

				return col;
			}

			ENDCG
		}
	}
}