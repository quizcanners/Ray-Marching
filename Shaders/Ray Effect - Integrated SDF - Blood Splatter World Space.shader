Shader "RayTracing/Integrated SDF/Volumetric Blood Splatter World Space"
{
	Properties
	{
		_Down("_Down", Range(0,5)) = 1
		_Test("Test", Range(0.01,2)) = 1
		_RndSeed ("Random", float) = 0.5
	}

	SubShader
	{
		Tags
		{ 
			"RenderType" = "Opaque"
			"Queue" = "Geometry+2"
		}


		CGINCLUDE
			#define RENDER_DYNAMICS
			#define IGNORE_FLOOR

			#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
			#pragma multi_compile __ _qc_IGNORE_SKY 

			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Debug.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"
			
		

			float _Down;
			float4 _Effect_Time;
			float _RndSeed;
			float _Test;

			float SampleSDF(float3 pos, float4 sphere)
			{
				float3 centerPos = sphere.xyz;
				float size = sphere.w;

				float deSize = 1/size;

				float3 segmentPos = (pos - centerPos) * deSize;

				float3 worldPos = pos * deSize;

				float dist = 9999;
				float smoothness = 2;
				float edges = 0.2;

				float deDyn = 1; // smoothstep(0.5,0,dynamics);

				float t = _Effect_Time.x * 0.5 + _RndSeed + deDyn * 0.01;

				float3 gyroidPos = segmentPos;

				float gyr = sdGyroid(gyroidPos //worldPos //gyroidPos
				//+ pos * 0.05 
				+ float3(_RndSeed * 10, _RndSeed * 4, -_RndSeed)   
				- float3(0, -t, 0)
				, 20   , 0.1, 1.5 );

				//return gyr * size;

					float upscale = lerp (2 * _Test / (1 //+ _Down * 2
					),3, deDyn);

				float tmpScale = (3 + upscale * 2) ;



				float tinyGyr = sdGyroid(gyroidPos * tmpScale
				- float3(0, t, 0), 13  , 0.1 , 1) / tmpScale;
				gyr = CubicSmin(tinyGyr, abs(gyr) - 0.07 ,  0.2 );



				float subtractiveGyr = sdGyroid(gyroidPos
				+ float3(0, t * 2, 0), 25* 0.4 , 0.1  , 1.5); // General shape decision
				gyr = SmoothIntersection(gyr,  subtractiveGyr, 0.15 //* _Down 
					);


				

				
				float cone = sdRoundCone(segmentPos);
				dist = SmoothIntersection(gyr, cone, 0.18); // * (2.5 - _Down)  );

					float subtractiveGyrB = sdGyroid(gyroidPos 
				- float3(0, +t * 2, 0), 25 , 0.2 , 0.6); //

				dist = SmoothIntersection(dist, subtractiveGyrB, 0.13 );

				float oobSDF;
				float scene = SampleSDF(pos , oobSDF).a;
				scene += oobSDF * 1000;
				scene *= deSize;

				dist = CubicSmin (dist , scene + 0.04	, 0.25  );

				//dist = OpSmoothSubtraction(dist, dynamics,  1);

				dist = OpSmoothSubtraction(dist, SphereDistance(segmentPos, 0.1), 0.1); // Subtract internal sphere

				float sphered = SphereDistance(segmentPos, 0.5);

				dist = SmoothIntersection(dist, sphered, 0.1  / (1 +deDyn));

				return dist * size;
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

			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase_fullshadows
			

			struct v2f 
			{
				float4 pos: SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float3 viewDir		: TEXCOORD1;
				float4 centerPos : TEXCOORD2;
				//float tracedShadows : TEXCOORD3;
				fixed4 color : COLOR;
			};

			float4 _Global_Noise_Lookup_TexelSize;

			v2f vert(appdata_full v) 
			{
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);
				o.pos = UnityWorldToClipPos(mul(unity_ObjectToWorld, v.vertex));
				o.screenPos = ComputeScreenPos(o.pos);
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.color = v.color;
				o.centerPos = PositionAndSizeFromMatrix();

				//o.tracedShadows = SampleSkyShadow(o.centerPos);

				return o;
			}


			FragColDepth frag(v2f i)
			{
				MARCH_FROM_DEPTH(newPos, spherePos, shadow, viewDir, screenUv);
				INIT_SDF_NORMAL(normal, newPos, spherePos, SampleSDF);

				float3 volumeSamplePosition = newPos;
				float fresnel = 1 - saturate(dot(normal, viewDir));

				float ao = 1;

				float3 reflectedRay = reflect(-viewDir, normal);
				float3 bakeReflected = GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, BLOOD_SPECULAR, ao);//SampleReflection(o.worldPos, viewDir, normal, shadow, hit);

				
				

				float3 refractedRay =  refract(-viewDir, normal, 0.75);
				float3 bakeStraight = GetBakedAndTracedReflection(volumeSamplePosition, refractedRay, BLOOD_SPECULAR, ao);
			
				#if !_qc_IGNORE_SKY 
				bakeStraight += GetTranslucent_Sun(refractedRay) * shadow; //translucentSun * shadow * GetDirectional() * 4; 
				bakeReflected += GetDirectionalSpecular(normal, viewDir, 0.85) * GetDirectional();
				#endif

				float4 col = 1;

				float showStright = (1 - fresnel);

				float3 	reflectedPart = lerp(bakeReflected.rgb, bakeStraight.rgb, showStright);// + specularReflection * lightColor;

				float outsideVolume;
				float4 scene = SampleSDF(newPos , outsideVolume);

				float far = smoothstep(0,1, scene.a);

				col.rgb = _qc_BloodColor.rgb * (1 + far)*0.5 * reflectedPart;

				ApplyBottomFog(col.rgb, newPos, viewDir.y);

				FragColDepth result;
				result.depth = calculateFragmentDepth(newPos);
				result.col =  col;

				//	result.col =  scene.a * 0.1;

				return result;
			}
			ENDCG
		}

		Pass
		{
			Tags {"LightMode" = "Shadowcaster"}
			ZWrite On
			ZTest  Off
			ZTest LEqual
			Cull Front
			CGPROGRAM
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing
			#pragma vertex vert
			#pragma fragment frag

			v2fMD vert(appdata_full v)
			{
				v2fMD o;
				UNITY_SETUP_INSTANCE_ID(v);
				INITIALIZE_DEPTH_MARCHER(o);
				return o;
			}

			float frag(v2fMD i) : SV_Depth
			{
				MARCH_DEPTH(SampleSDF);
			}

			ENDCG
		}
	}
}