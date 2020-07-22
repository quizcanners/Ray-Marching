Shader "RayTracing/Baker/Marched Ambient"
{
	Properties{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
	}

	SubShader{

		Tags{
			"Queue" = "Geometry"
			"IgnoreProjector" = "True"
			"RenderType" = "Opaque"
		}

		ColorMask RGB
		Cull Back
		ZWrite Off
		ZTest On

		Pass{

			CGPROGRAM

			#define _qc_AMBIENT_SIMULATION
			#define RENDER_DYNAMICS
			#include "PrimitivesScene.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase // useful to have shadows 
			#pragma shader_feature_local ____ _DEBUG 

			#pragma target 3.0

			struct v2f {
				float4 pos : 		SV_POSITION;
				float3 viewDir: 	TEXCOORD1;
				float4 screenPos : 	TEXCOORD2;
				float2 texcoord :	TEXCOORD3;
			};

			sampler2D _MainTex;

			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.screenPos = ComputeScreenPos(o.pos);
				o.texcoord = v.texcoord.xy;
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				return o;
			}

			float4 frag(v2f o) : COLOR{

				o.viewDir.xyz = normalize(o.viewDir.xyz);

				float3 position = volumeUVtoWorld(o.texcoord.xy, _RayMarchingVolumeVOLUME_POSITION_N_SIZE, _RayMarchingVolumeVOLUME_H_SLICES); //VOLUME_POSITION_N_SIZE_BRUSH, VOLUME_H_SLICES_BRUSH);

				float3 noise = tex2Dlod(_Global_Noise_Lookup, float4(o.texcoord.xy * 13.5 + float2(_SinTime.w, _CosTime.w) * 32, 0, 0)).rgb - 0.5;

				float3 direction = normalize(noise);

				float totalDistance = 0;

				float s0;
				float s1;
				float dist;
				float dott = 1;

				_MaxRayMarchDistance += 1;

				for (int i = 0; i < _maxRayMarchSteps; i++) {

					dist = SceneSdf(position);

					position += dist * direction;

					totalDistance += dist;

					if (dist < 0.01) {
						i = 999;
					}
				}

				float3 normal = EstimateNormal(position);
				float outOfBounds;
				float4 bake = SampleVolume(_RayMarchingVolume
					, position,
					_RayMarchingVolumeVOLUME_POSITION_N_SIZE,
					_RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);

				float3 lightSource = RayMarchLight_0.xyz;

				float3 toCenterVec = lightSource - position;

				float toCenter = length(toCenterVec);

				float3 lightDir = normalize(toCenterVec);

				float lightRange = RayMarchLight_0_Size.x + 1;
				float deLightRange = 1 / lightRange;

				float lightBrightness = max(0, lightRange - toCenter) * deLightRange;

				float deFog = saturate(1 - totalDistance / _MaxRayMarchDistance);
				deFog *= deFog;

				float precision = 1 + deFog * deFog * _maxRayMarchSteps;


				float shadow = 0;

				if (lightRange > toCenter)
					shadow = Softshadow(position, lightDir, 5, _RayMarchShadowSoftness, precision);

				float toview = max(0, dot(normal, o.viewDir.xyz));

				float3 reflected = normalize(o.viewDir.xyz - 2 * (toview)*normal);

				float lightRelected = pow(max(0, dot(-reflected, lightDir)), 1 + bake.a * 128);

				float reflectedDistance;

				float3 reflectionPos;

				// Reflection


				float reflectedSky = Reflection(position, -reflected, 0.1, 1,
					reflectedDistance, reflectionPos, precision);

				//reflectedSky = reflectedSky * deDott + 0.5 * dott;

				float3 reflectedNormal = EstimateNormal(reflectionPos);

				float reflectedDott = max(0, dot(reflected, reflectedNormal));

				//	return reflectedDott;

				float4 bakeReflected = SampleVolume(_qcPp_DestBuffer//_RayMarchingVolume
					, reflectionPos,
					_RayMarchingVolumeVOLUME_POSITION_N_SIZE,
					_RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);

				float3 toCenterVecRefl = lightSource - reflectionPos;

				float toCenterRefl = length(toCenterVecRefl);

				float3 lightDirRef = normalize(toCenterVecRefl);

				float lightAttenRef = max(0, dot(lightDirRef, reflectedNormal));

					//return lightAttenRef;

					float reflectedShadow = 0;

					precision = 1 + precision * max(0, 1 - reflectedDistance / _MaxRayMarchDistance) * 0.5f;

					//return precision/ _maxRayMarchSteps;

					if (lightRange > toCenterRefl)
						reflectedShadow = Softshadow(reflectionPos, lightDirRef, 2,
							_RayMarchShadowSoftness, precision);

					float lightAtten = max(0, dot(lightDir, normal));

					float4 col = 1;

					float lightBrightnessReflected = max(0, lightRange - toCenterRefl) *deLightRange;

					shadow *= lightAtten;

					//return lightAtten;

					col.rgb = bake.rgb* (RayMarchLight_0_Mat.rgb * 2 * shadow *
						lightBrightness);

					float reflectedFog = max(0, 1 - reflectedDistance / _MaxRayMarchDistance);

					float reflAmount = pow(deFog * reflectedFog, 1);

					reflectedFog *= reflAmount;

					reflectedSky = reflectedSky * (reflAmount)+(1 - reflAmount);

					lightBrightnessReflected *= reflAmount;

					float3 reflCol = (RayMarchLight_0_Mat.rgb * reflectedShadow * lightAttenRef *
						lightBrightnessReflected *
						bakeReflected.rgb);

						//return shadow;

					col.rgb += (1 + dott) * 0.5 *  (
						reflCol * (1 - reflectedSky) +
						_RayMarchSkyColor.rgb * reflectedSky +
						lightRelected * 64 * shadow
						) * unity_FogColor.rgb * bake.a;


					col.rgb = col.rgb * deFog + _RayMarchSkyColor.rgb *(1 - deFog);

					col.rgb += noise.rgb*col.rgb*0.2;

						return 	col;


				}
				ENDCG
			}
		}
		Fallback "Legacy Shaders/Transparent/VertexLit"
	}