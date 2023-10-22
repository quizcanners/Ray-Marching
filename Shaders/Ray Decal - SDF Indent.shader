Shader "RayTracing/Decal/SDF Indent"
{
	Properties
	{
		[NoScaleOffset] _MainTex("Texture", 2D) = "white" {}
		_BumpMap("Bump", 2D) = "bump" {}
	}

	SubShader
	{

		CGINCLUDE

			//#pragma multi_compile __ RT_FROM_CUBEMAP 
			#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
			#pragma multi_compile __ _qc_IGNORE_SKY 

			#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
			#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
			#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"
			#include "Assets/Ray-Marching/Shaders/Savage_DepthSampling.cginc"

		ENDCG


		Tags
		{ 
			"Queue" = "Geometry+1"
			"RenderType" = "Opaque"
			"LightMode" = "ForwardBase"
		}

		Blend SrcAlpha OneMinusSrcAlpha
		//ZWrite off
		ZTest off
		Cull Front

		Pass
		{
			CGPROGRAM


			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing

			#pragma multi_compile_fwdbase
			#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

			sampler2D _MainTex;
			sampler2D _BumpMap;

			struct v2f 
			{
				float4 pos:				SV_POSITION;
				float4 screenPos :		TEXCOORD0;
				float3 viewDir		:	TEXCOORD1;
				float3 meshPos :		TEXCOORD2;
				float4 meshSize :		TEXCOORD3;
				float4 meshQuaternion : TEXCOORD4;
				float4 centerPos :		TEXCOORD5;
				float upscaleProjection : TEXCOORD6;
			};

			//the vertex shader function
			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.screenPos = ComputeScreenPos(o.pos);
				COMPUTE_EYEDEPTH(o.screenPos.z);

				o.viewDir = WorldSpaceViewDir(v.vertex);
				o.meshPos = v.texcoord;
				o.meshSize = v.texcoord1;
				o.meshQuaternion = v.texcoord2;

				o.meshSize.w = min(o.meshSize.z, min(o.meshSize.x, o.meshSize.y));

				float maxSize = max(o.meshSize.z, max(o.meshSize.x, o.meshSize.y));

				o.centerPos = float4(o.meshPos.xyz, maxSize);


				o.upscaleProjection = 1 / min(o.meshSize.x, o.meshSize.y);

				//o.color = _Color;
				//float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
				
				//TRANSFER_TOP_DOWN(o);
				return o;
			}

			float GetSDF(float3 pos, float3 centerPos, float4 rotation, float4 meshSize)
			{
				float dist = -SphereDistance(pos - centerPos, meshSize.w * 0.45);

				float3 gyroidPos = pos;
				float gyr = sdGyroid(gyroidPos , 1, 0.5, 1.5);

				dist = lerp(dist, gyr, 0.2); /// -0.07, 0.2);

				return dist;
			}

			FragColDepth frag(v2f i)
			{
				float3 viewDir = normalize(i.viewDir.xyz);
				float2 screenUv = i.screenPos.xy / i.screenPos.w;
				float3 hitPos = GetRayPoint(viewDir, screenUv);

				float toSphere = -GetSDF(hitPos, i.centerPos.xyz, i.meshQuaternion, i.meshSize);

				float sphereRadius = i.meshSize.w * 0.5;

				float show = smoothstep(sphereRadius * 0.01,0,toSphere);

				clip(show - 0.01);

				float3 ro = hitPos; // -i.centerPos.xyz;
				float3 rd = -viewDir;
				float maxDist = (length(ro) + i.meshSize.w) * 10;

				float hitDist = 0;
				float3 newPos = ro;
				float steps = 0;

				for (int ind = 0; ind < 16; ind++) 
				{
					float step = GetSDF(newPos, i.centerPos.xyz, i.meshQuaternion, i.meshSize);
					hitDist += step * 1.25;
					newPos = ro + hitDist * rd;
					
					if (step < 0.005)
					{
						newPos -= step * 0.25 * rd;
						break; 
					}
				}

				steps = ind;

				float gotHit = smoothstep(0,-0.01, toSphere);
				newPos = lerp(hitPos, newPos,gotHit);
				INIT_SDF_NORMAL_ROT(normal, newPos, i.centerPos.xyz, GetSDF);
				//normal = -normal;

				//float3 normal;
				//float hitDist = iSphere_FrontCull(ro, rd, float2(0, maxDist), normal, sphereRadius);
				//float gotHit = smoothstep(maxDist*0.5, maxDist*0.4, hitDist);
				//gotHit *= smoothstep(0, -0.01, toSphere);
				//float3 newPos = hitPos + hitDist * rd * gotHit;

				float3 relativePosition = GetRotatedPos(newPos, i.centerPos.xyz, i.meshQuaternion);

				float3 uv = newPos * 0.1;

				float3 absNorm = abs(normal);

				float4 col = tex2D(_MainTex, uv.xy) *absNorm.z
					+ tex2D(_MainTex, uv.xz) * absNorm.y
					+ tex2D(_MainTex, uv.yz) * absNorm.x
					;

				col.rgb = lerp(0.5, col.rgb, gotHit);

				

				float nativeShadow = getShadowAttenuation(newPos);

			
#define IGNORE_FLOOR

				float tracedShadow = SampleRayShadowAndAttenuation(newPos, normal);

				float3 _lightColor = GetDirectional() * tracedShadow * lerp(nativeShadow, 1, gotHit);


				float3 vlm = SampleVolume_CubeMap(
					newPos 
#if RT_FROM_CUBEMAP 
					+ normal * sphereRadius
#endif
					, normal);
	
				

				float3 tdwnPos = newPos;
				tdwnPos.y *= 0.1;

				TopDownSample(tdwnPos, vlm);

			

				//float direct = saturate((dot(normal, _WorldSpaceLightPos0.xyz)));


			

				col.rgb *= _lightColor +vlm;

				

				//col.rgb *= smoothstep(0.9,1,show);

				//col.rgb = -toSphere;

				//col.rgb = normal;// *0.5 + 0.5;

				//col.rgb += steps*0.01;

				col.a = show;// *gotHit;

				//col.rgb = vlm.rgb;

				//col.rgb = show;

				//col.rgb = normal;

				//ApplyBottomFog(col.rgb, newPos, i.viewDir.y);

				FragColDepth mobres;
				mobres.depth = calculateFragmentDepth(newPos); // lerp(hitPos, newPos, show)); // lerp(hitPos, newPos, step(0, toSphere - 1)));
				mobres.col =  float4(saturate(col));

				//mobres.col = float4(tracedShadow, tracedShadow, tracedShadow,1);

				return mobres;
			}

			ENDCG
		}

		/*
		Pass
		{
			Name "ShadowCaster"
			Tags 
			{ 
				"LightMode" = "ShadowCaster" 
			}

			//ZWrite Off
			ZTest Off
			Cull Front

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile_shadowcaster

			#include "UnityCG.cginc"

			struct v2f
			{

				float3 viewDir		:	TEXCOORD1;
				float3 meshPos :		TEXCOORD2;
				float4 meshSize :		TEXCOORD3;
				float4 meshQuaternion : TEXCOORD4;
				float4 centerPos :		TEXCOORD5;

				V2F_SHADOW_CASTER;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert(appdata_full v)
			{
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);


				float4 pos = UnityObjectToClipPos(v.vertex);
				//o.screenPos = ComputeScreenPos(pos);

				o.viewDir = WorldSpaceViewDir(v.vertex);
				o.meshPos = v.texcoord;
				o.meshSize = v.texcoord1;
				o.meshQuaternion = v.texcoord2;

				o.meshSize.w = min(o.meshSize.z, min(o.meshSize.x, o.meshSize.y));

				float maxSize = max(o.meshSize.z, max(o.meshSize.x, o.meshSize.y));

				o.centerPos = float4(o.meshPos.xyz, maxSize);

				//float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));



				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)

				return o;
			}

			float4 frag(v2f i) : SV_Target
			{

				float3 viewDir = normalize(i.viewDir.xyz);
				//float2 screenUv = i.screenPos.xy / i.screenPos.w;
				//float3 newPos = GetRayPoint(viewDir, screenUv);

				float3 ro = _WorldSpaceCameraPos - i.centerPos.xyz;
				float3 rd = -viewDir;
				float sphereRadius = i.meshSize.w * 0.5;
				float maxDist = length(ro) + i.meshSize.w;
				float3 normal;
				float hitDist = iSphere_FrontCull(ro, rd, float2(0, maxDist), normal, sphereRadius);

				//clip(maxDist - hitDist); // Clips all
				//clip(hitDist); // Clips none

				float3 newPos = _WorldSpaceCameraPos + hitDist * rd;

				return calculateShadowDepth(newPos);
				//SHADOW_CASTER_FRAGMENT(o)
			}
			ENDCG
		}*/
		
		//UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
	}
}