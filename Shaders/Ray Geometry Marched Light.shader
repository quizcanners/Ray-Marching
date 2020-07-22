Shader "RayTracing/Geometry/Marched Light"
{
	Properties{
		 _MainTex("Albedo (RGB)", 2D) = "white" {}
		[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_Map("Bump/Combined Map (or None)", 2D) = "gray" {}
	}

	SubShader{

		Tags{
			"Queue" = "Geometry"
			"IgnoreProjector" = "True"
			"RenderType" = "Opaque"
		}

		ColorMask RGB
		Cull Back
		//ZWrite Off
		ZTest On
		//Blend SrcAlpha OneMinusSrcAlpha

		Pass{

			CGPROGRAM

			//#include "UnityCG.cginc"
			//#include "Lighting.cginc"
			//#include "PrimitivesScene.cginc"
			#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
			

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase // useful to have shadows 
			#pragma shader_feature_local  _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED 

			#pragma target 3.0

			struct v2f {
				float4 pos : 		SV_POSITION;
				float3 worldPos : 	TEXCOORD0;
				float3 normal : 	TEXCOORD1;
				float3 viewDir: 	TEXCOORD3;
				float4 screenPos : 	TEXCOORD4;
				float2 texcoord		: TEXCOORD5;
				float4 wTangent		: TEXCOORD6;
				float4 color: 		COLOR;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Map;
			
			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);

				o.wTangent.xyz = UnityObjectToWorldDir(v.tangent.xyz);
				o.wTangent.w = v.tangent.w * unity_WorldTransformParams.w;

				o.normal.xyz = UnityObjectToWorldNormal(v.normal);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.screenPos = ComputeScreenPos(o.pos);
				o.color = v.color;
				return o;
			}


			float4 frag(v2f o) : COLOR
			{
				o.viewDir.xyz = normalize(o.viewDir.xyz);

				float3 position = o.worldPos.xyz;

				float3 normalVector = o.normal.xyz;
#if _BUMP_NONE
				float4 bumpMap = DEFAULT_COMBINED_MAP;
				float4 bumpMapMip = DEFAULT_COMBINED_MAP;
#else
				float4 bumpMap = tex2D(_Map, o.texcoord.xy);

				float3 tnormal;
#if _BUMP_REGULAR
				tnormal = UnpackNormal(bumpMap);
				bumpMap = DEFAULT_COMBINED_MAP;
#else
				bumpMap.rg = (bumpMap.rg - 0.5) * 2;
				tnormal = float3(bumpMap.r, bumpMap.g, 0.75);
#endif
				ApplyTangent(normalVector, tnormal, o.wTangent * 0.001);
#endif

				float3 direction = -o.viewDir.xyz; // reflect(-o.viewDir.xyz, normalVector);


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

				float4 bake = 0.5;
						
					/*SampleVolume(_RayMarchingVolume
					, position,
					_RayMarchingVolumeVOLUME_POSITION_N_SIZE,
					_RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);*/

				float deDott = max(0, dot(-direction, normal));

				dott = 1 - deDott;
			
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
					
				if (lightRange> toCenter)
					shadow = Softshadow(position, lightDir, 5, _RayMarchShadowSoftness, precision);

				//return shadow;

				float toview = max(0, dot(normal, o.viewDir.xyz));

				float3 reflected = normalize(o.viewDir.xyz - 2 * (toview)*normal);

				float lightRelected = pow(max(0, dot(-reflected, lightDir)), 1+bake.a*128);

				//return lightRelected;

				float reflectedDistance;

				float3 reflectionPos;

				// Reflection

				
				float reflectedSky = Reflection(position, -reflected, 0.1, 1, 
					reflectedDistance, reflectionPos, precision);

	
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
					
				precision = 1 + precision * max(0, 1 - reflectedDistance/ _MaxRayMarchDistance) * 0.5f;

				//return precision/ _maxRayMarchSteps;

				if (lightRange> toCenterRefl)
					reflectedShadow = Softshadow(reflectionPos, lightDirRef, 2,
						_RayMarchShadowSoftness, precision);

				float lightAtten = max(0, dot(lightDir, normal));

				float4 col = 1;

				float lightBrightnessReflected = max(0, lightRange - toCenterRefl) *deLightRange;

				shadow *= lightAtten;

				//return lightAtten;

				col.rgb = bake.rgb* (RayMarchLight_0_Mat.rgb * 2 *  shadow *
					lightBrightness);

				float reflectedFog = max(0, 1 - reflectedDistance / _MaxRayMarchDistance);

				float reflAmount = pow(deFog * reflectedFog, 1);

				reflectedFog *= reflAmount;

				reflectedSky = reflectedSky * (reflAmount) + (1 - reflAmount);

				lightBrightnessReflected *= reflAmount;

				float3 reflCol = (RayMarchLight_0_Mat.rgb * reflectedShadow * lightAttenRef *
					lightBrightnessReflected *
					bakeReflected.rgb );

				//return shadow;

				col.rgb += (1+dott) * 0.5 *  (
					reflCol * (1 - reflectedSky) +
					_RayMarchSkyColor.rgb * reflectedSky +
					lightRelected * 64 * shadow
					) * unity_FogColor.rgb * bake.a;
					

				col.rgb = col.rgb * deFog + _RayMarchSkyColor.rgb *(1-deFog);

				// gamma correction
				col = max(0, col - 0.004);
				col = (col*(6.2*col + .5)) / (col*(6.2*col + 1.7) + 0.06);

				//col.rgb += noise.rgb*col.rgb*0.2;

				return 	col;


			}
			ENDCG
		}
	}
	 Fallback "Legacy Shaders/Transparent/VertexLit"

					//CustomEditor "CircleDrawerGUI"
}