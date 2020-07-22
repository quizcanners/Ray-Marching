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
		}


		CGINCLUDE
			//#define RENDER_DYNAMICS

			#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
			#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
			#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"
		

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

				float dist = 9999;
				float smoothness = 2;
				float edges = 0.2;

			//	float dynamics = SceneSdf_Dynamic(pos,  smoothness,  edges) * deSize;

				float deDyn = 1; // smoothstep(0.5,0,dynamics);

				float t = _Effect_Time.x * 0.5 + _RndSeed + deDyn * 0.01;

				float3 gyroidPos = segmentPos;

			

			

				float gyr = sdGyroid(gyroidPos
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

				dist = CubicSmin (dist, SceneSdf(pos, 0.1) * deSize, 0.15  );

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
			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase_fullshadows
			

			struct v2f 
			{
				float4 pos: SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float3 viewDir		: TEXCOORD1;
				float4 centerPos : TEXCOORD2;
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
				return o;
			}

			float4 _qc_BloodColor;

			FragColDepth frag(v2f i)
			{
				MARCH_FROM_DEPTH(newPos, spherePos, shadow, viewDir, screenUv);
				INIT_SDF_NORMAL(normal, newPos, spherePos, SampleSDF);

				float fresnel = smoothstep(0.5, 1 , dot(viewDir, normal));

				float outOfBounds;
				float4 vol = SampleVolume(newPos, outOfBounds);
				TopDownSample(newPos, vol.rgb, outOfBounds);

				float3 ambientCol = lerp(vol, _RayMarchSkyColor.rgb * MATCH_RAY_TRACED_SKY_COEFFICIENT, outOfBounds);

				float direct = saturate((dot(normal, _WorldSpaceLightPos0.xyz)));
				float3 lightColor = _LightColor0.rgb * direct;
				
				float4 col = i.color;

				col.rgb =
				(ambientCol * 0.5
					+ lightColor * shadow
					) ;

				float3 reflectionPos;
				float outOfBoundsRefl;
				float3 bakeReflected = SampleReflection(newPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);
				TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);

				float outOfBoundsStraight;
				float3 straightHit;
				float3 bakeStraight = SampleRay(newPos, normalize(-viewDir - normal*0.2), shadow, straightHit, outOfBoundsStraight);
				TopDownSample(straightHit, bakeStraight, outOfBoundsStraight);

				float world = SceneSdf(newPos, 0.1);

				float farFromSurface = smoothstep(0, 0.5, world); 
				_qc_BloodColor.rgb *= 0.25 + farFromSurface * 0.75;
				float showStright = fresnel * fresnel;

				col.rgb =  _qc_BloodColor.rgb * col.rgb 
				+ lerp(_qc_BloodColor.rgb * bakeReflected, (farFromSurface + _qc_BloodColor.rgb) * 0.5 * bakeStraight, showStright);

				ApplyBottomFog(col.rgb, newPos, viewDir.y);

				FragColDepth result;
				result.depth = calculateFragmentDepth(newPos);
				result.col = col;

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