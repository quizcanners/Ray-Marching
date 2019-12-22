Shader "RayTracing/Marching/Reflection"
{
	Properties{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_Gloss("Glossyness (RGB)", 2D) = "white" {}
		_Normal("Noraml (RGB)", 2D) = "bump" {}
		  [Toggle(_DEBUG)] debugOn("Debug", Float) = 0
	}

	SubShader{

		Tags{
			"Queue" = "Geometry"
			"IgnoreProjector" = "True"
			"RenderType" = "Opaque"
		}

		ColorMask RGB
		Cull Back
		ZWrite On
		ZTest On
			//Blend SrcAlpha OneMinusSrcAlpha

		Pass{

			CGPROGRAM

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "PrimitivesScene.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase // useful to have shadows 
			#pragma shader_feature ____ _DEBUG 

			#pragma target 3.0

			struct v2f {
				float4 pos : 		SV_POSITION;
				float3 worldPos : 	TEXCOORD0;
				float3 normal : 	TEXCOORD1;
				float3 viewDir: 	TEXCOORD3;
				float4 screenPos : 	TEXCOORD4;
				float2 texcoord : TEXCOORD5;
				float4 wTangent : TEXCOORD6;
				float4 color: 		COLOR;
			};


			sampler2D _MainTex;
			sampler2D _Gloss;
			sampler2D _Normal;
			float4 _Normal_ST;



			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				o.texcoord = v.texcoord.xy;
				o.normal.xyz = UnityObjectToWorldNormal(v.normal);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.screenPos = ComputeScreenPos(o.pos);
				o.color = v.color;

				o.wTangent.xyz = UnityObjectToWorldDir(v.tangent.xyz);
				o.wTangent.w = v.tangent.w * unity_WorldTransformParams.w;

				return o;
			}


			float4 frag(v2f o) : COLOR{

				float4 tex = tex2D(_MainTex, o.texcoord);
				float gloss = tex2D(_Gloss, o.texcoord).r*(0.75+tex.b*0.25);
				float3 tnormal = UnpackNormal(tex2D(_Normal, TRANSFORM_TEX(o.texcoord, _Normal)));

				//_Normal

				//_Gloss
				o.viewDir.xyz = normalize(o.viewDir.xyz);

				float3 position = o.worldPos.xyz;
				float3 direction = -o.viewDir.xyz;

				float totalDistance = length(_WorldSpaceCameraPos - position);

				

				float dist;

				float3 fromCameraRayPosition = _WorldSpaceCameraPos;

				float totalFromCameraDist = 0;

				for (int i = 0; i < _maxRayMarchSteps; i++) {

					dist = SceneSdf(fromCameraRayPosition);

					totalFromCameraDist += dist;

					fromCameraRayPosition += dist * direction;

					if (totalFromCameraDist >= totalDistance) {
						break;
					}

					if (dist < 0.01) {
						clip(-1);
					}
				}

				float4 noise = tex2Dlod(_Global_Noise_Lookup, float4(o.screenPos.xy * 13.5 + float2(_SinTime.w, _CosTime.w) * 32, 0, 0));

				noise.rgb -= 0.5;

				float3 normal = o.normal.xyz;

				ApplyTangent(normal, tnormal, o.wTangent);

				float4 bake = tex;
					
				float deDott = max(0, dot(-direction, normal));

				float dott = 1 - deDott;


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
					shadow = Softshadow(position, lightDir, 5, toCenter, _RayMarchShadowSoftness, precision);

				float toview = max(0, dot(normal, o.viewDir.xyz));

				float3 reflected = normalize(o.viewDir.xyz - 2 * (toview)*normal);

				float reflectedDistance;

				float3 reflectionPos;

				float reflectedSky = Reflection(position, -reflected, 0.1, 1,
					reflectedDistance, reflectionPos, precision);

				reflectedSky = reflectedSky * deDott + 0.5 * dott;

				float3 reflectedNormal = EstimateNormal(reflectionPos);

				float reflectedDott = max(0, dot(reflected, reflectedNormal));

				float4 bakeReflected = SampleVolume(_RayMarchingVolume
					, reflectionPos,
					_RayMarchingVolumeVOLUME_POSITION_N_SIZE,
					_RayMarchingVolumeVOLUME_H_SLICES);

				float3 toCenterVecRefl = lightSource - reflectionPos;

				float toCenterRefl = length(toCenterVecRefl);

				float3 lightDirRef = normalize(toCenterVecRefl);

				float lightAttenRef = max(0, dot(lightDirRef, reflectedNormal));

				float reflectedShadow = 0;

				precision = 1 + precision * max(0, 1 - reflectedDistance / _MaxRayMarchDistance) * 0.5f * gloss * gloss;

				if (lightRange > toCenterRefl)
					reflectedShadow = Softshadow(reflectionPos, lightDirRef, 2,
						toCenterRefl, _RayMarchShadowSoftness, precision);

				float lightAtten = max(0, dot(lightDir, normal));

				float4 col = 1;

				shadow *= lightAtten;

				float lightBrightnessReflected = max(0, lightRange - toCenterRefl) *deLightRange;

				col.rgb = (bake.rgb * (RayMarchLight_0_Mat.rgb * 2 * shadow * lightBrightness
					//+ _RayMarchSkyColor.rgb
					));

				float reflectedFog = max(0, 1 - reflectedDistance / _MaxRayMarchDistance);

				float reflAmount = pow(deFog * reflectedFog, 1);

				reflectedFog *= reflAmount;

				reflectedSky = reflectedSky * (reflAmount)+(1 - reflAmount);

				lightBrightnessReflected *= reflAmount;

				float3 reflCol = (RayMarchLight_0_Mat.rgb * reflectedShadow * lightAttenRef * lightBrightnessReflected *
					bakeReflected.rgb);

				float lightRelected = pow(max(0, dot(-reflected, lightDir)), 1 + gloss * 512);


					col.rgb += (1+dott)*0.5 * 
						(
						reflCol * (1 - reflectedSky) +
						_RayMarchSkyColor.rgb * reflectedSky + 
						lightRelected * 64 * shadow
						
						) 
						
						* unity_FogColor.rgb * gloss;


					col.rgb = col.rgb * deFog + _RayMarchSkyColor.rgb *(1 - deFog);

					col.rgb += noise.rgb*col.rgb*0.2;

					return 	col;


			}
			ENDCG
		}
	}
		Fallback "Legacy Shaders/Transparent/VertexLit"
}
