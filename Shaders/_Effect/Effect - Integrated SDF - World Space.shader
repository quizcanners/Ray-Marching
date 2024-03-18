
Shader "RayTracing/Integrated SDF/Volumetric World Space"
{
	Properties	{}

	SubShader
	{
		Tags	
		{
			"RenderType" = "Opaque"
		}

		CGINCLUDE

			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"
			#include "Assets/Qc_Rendering/Shaders/inc/SDFoperations.cginc"
						
			#include "Assets/Qc_Rendering/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Qc_Rendering/Shaders/RayMarching_Forward_Integration.cginc"

			float SampleSDF(float3 pos, float4 spherePos)
			{
				float scale = spherePos.w;
				float dist = SphereDistance(pos - spherePos.xyz ,  0.5 * scale);
				float gyr = sdGyroid(pos + float3(0, -10, 0) , 25 / scale, 0.1, 1);
				dist = SmoothIntersection(dist, gyr, 0.12);

				return  dist;
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
			//#pragma multi_compile_fwdbase_fullshadows // Check if this is ok
			

			struct v2f 
			{
				float4 vertex: SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float3 viewDir	: TEXCOORD1;
				float4 centerPos: TEXCOORD2;
				fixed4 color : COLOR;
			};

			v2f vert(appdata_full v) 
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				o.vertex = UnityWorldToClipPos(mul(unity_ObjectToWorld, v.vertex));

				o.centerPos = PositionAndSizeFromMatrix();

				o.color = v.color;
				o.screenPos = ComputeScreenPos(o.vertex);

				COMPUTE_EYEDEPTH(o.screenPos.z);

				o.viewDir = WorldSpaceViewDir(v.vertex);
				return o;
			}

			FragColDepth frag(v2f i)
			{
				MARCH_FROM_DEPTH(newPos, spherePos, shadow, viewDir, screenUv);
			
				INIT_SDF_NORMAL(normal, newPos, spherePos, SampleSDF);

				PrimitiveLight(lightColor, ambientCol, outOfBounds, newPos, normal);

				TopDownSample(newPos, ambientCol);

				float4 col = i.color;
				col.rgb *= (ambientCol + lightColor * shadow);

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
			ZTest LEqual
			Cull Front
			CGPROGRAM
			#pragma multi_compile_shadowcaster
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