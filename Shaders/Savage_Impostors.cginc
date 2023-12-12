	#include "Assets\AmplifyImpostors\Plugins\EditorResources\Shaders\Runtime\AmplifyImpostors.cginc"

	
	inline void OctaImpostorFragment_My(inout SurfaceOutputStandardSpecular o, out float4 clipPos, out float3 worldPos, float4 uvsFrame1, float4 uvsFrame2, float4 uvsFrame3, float4 octaFrame, float4 interpViewPos)
		{
			float depthBias = -1.0;
			float textureBias = _TextureBias;

			// Weights
			float2 fraction = frac(octaFrame.xy);
			float2 invFraction = 1 - fraction;
			float3 weights;
			weights.x = min(invFraction.x, invFraction.y);
			weights.y = abs(fraction.x - fraction.y);
			weights.z = min(fraction.x, fraction.y);

			float4 parallaxSample1 = tex2Dbias(_Normals, float4(uvsFrame1.zw, 0, depthBias));
			float2 parallax1 = ((0.5 - parallaxSample1.a) * uvsFrame1.xy) + uvsFrame1.zw;
			float4 parallaxSample2 = tex2Dbias(_Normals, float4(uvsFrame2.zw, 0, depthBias));
			float2 parallax2 = ((0.5 - parallaxSample2.a) * uvsFrame2.xy) + uvsFrame2.zw;
			float4 parallaxSample3 = tex2Dbias(_Normals, float4(uvsFrame3.zw, 0, depthBias));
			float2 parallax3 = ((0.5 - parallaxSample3.a) * uvsFrame3.xy) + uvsFrame3.zw;

			// albedo alpha
			float4 albedo1 = tex2Dbias(_Albedo, float4(parallax1, 0, textureBias));
			float4 albedo2 = tex2Dbias(_Albedo, float4(parallax2, 0, textureBias));
			float4 albedo3 = tex2Dbias(_Albedo, float4(parallax3, 0, textureBias));
			float4 blendedAlbedo = albedo1 * weights.x + albedo2 * weights.y + albedo3 * weights.z;

			// early clip
			o.Alpha = (blendedAlbedo.a - _ClipMask);
			clip(o.Alpha);

#if AI_CLIP_NEIGHBOURS_FRAMES
			float t = ceil(fraction.x - fraction.y);
			float4 cornerDifference = float4(t, 1 - t, 1, 1);

			float2 step_1 = (parallax1 - octaFrame.zw) * _Frames;
			float4 step23 = (float4(parallax2, parallax3) - octaFrame.zwzw) * _Frames - cornerDifference;

			step_1 = step_1 * (1 - step_1);
			step23 = step23 * (1 - step23);

			float3 steps;
			steps.x = step_1.x * step_1.y;
			steps.y = step23.x * step23.y;
			steps.z = step23.z * step23.w;
			steps = step(-steps, 0);

			float final = dot(steps, weights);

			clip(final - 0.5);
#endif

#ifdef EFFECT_HUE_VARIATION
			half3 shiftedColor = lerp(blendedAlbedo.rgb, _HueVariation.rgb, interpViewPos.w);
			half maxBase = max(blendedAlbedo.r, max(blendedAlbedo.g, blendedAlbedo.b));
			half newMaxBase = max(shiftedColor.r, max(shiftedColor.g, shiftedColor.b));
			maxBase /= newMaxBase;
			maxBase = maxBase * 0.5f + 0.5f;
			shiftedColor.rgb *= maxBase;
			blendedAlbedo.rgb = saturate(shiftedColor);
#endif
			o.Albedo = blendedAlbedo.rgb;

			// Emission Occlusion
			/*float4 mask1 = tex2Dbias(_Emission, float4(parallax1, 0, textureBias));
			float4 mask2 = tex2Dbias(_Emission, float4(parallax2, 0, textureBias));
			float4 mask3 = tex2Dbias(_Emission, float4(parallax3, 0, textureBias));
			float4 blendedMask = mask1 * weights.x + mask2 * weights.y + mask3 * weights.z;*/
			o.Emission = 0; // blendedMask.rgb;
			o.Occlusion = 0; // blendedMask.a;

			// Specular Smoothness
		

			// Diffusion Features
#if defined(AI_HD_RENDERPIPELINE) && ( AI_HDRP_VERSION >= 50702 )
			float4 feat1 = _Features.SampleLevel(SamplerState_Point_Repeat, parallax1, 0);
			o.Diffusion = feat1.rgb;
			o.Features = feat1.a;
			float4 test1 = _Specular.SampleLevel(SamplerState_Point_Repeat, parallax1, 0);
			o.MetalTangent = test1.b;
#endif

			// normal depth
			float4 normals1 = tex2Dbias(_Normals, float4(parallax1, 0, textureBias));
			float4 normals2 = tex2Dbias(_Normals, float4(parallax2, 0, textureBias));
			float4 normals3 = tex2Dbias(_Normals, float4(parallax3, 0, textureBias));
			float4 blendedNormal = normals1 * weights.x + normals2 * weights.y + normals3 * weights.z;

			float3 localNormal = blendedNormal.rgb * 2.0 - 1.0;
			float3 worldNormal = normalize(mul((float3x3)ai_ObjectToWorld, localNormal));
			o.Normal = worldNormal;

			float3 viewPos = interpViewPos.xyz;
			float depthOffset = ((parallaxSample1.a * weights.x + parallaxSample2.a * weights.y + parallaxSample3.a * weights.z) - 0.5 /** 2.0 - 1.0*/) /** 0.5*/ * _DepthSize * length(ai_ObjectToWorld[2].xyz);

#if !defined(AI_RENDERPIPELINE) // no SRP
#if defined(SHADOWS_DEPTH)
			if (unity_LightShadowBias.y == 1.0) // get only the shadowcaster, this is a hack
			{
				viewPos.z += depthOffset * _AI_ShadowView;
				viewPos.z += -_AI_ShadowBias;
			}
			else // else add offset normally
			{
				viewPos.z += depthOffset;
			}
#else // else add offset normally
			viewPos.z += depthOffset;
#endif
#elif defined(AI_RENDERPIPELINE) // SRP
#if ( defined(SHADERPASS) && (SHADERPASS == SHADERPASS_SHADOWS) ) || defined(UNITY_PASS_SHADOWCASTER)
			viewPos.z += depthOffset * _AI_ShadowView;
			viewPos.z += -_AI_ShadowBias;
#else // else add offset normally
			viewPos.z += depthOffset;
#endif
#endif

			worldPos = mul(UNITY_MATRIX_I_V, float4(viewPos.xyz, 1)).xyz;
			clipPos = mul(UNITY_MATRIX_P, float4(viewPos, 1));

#if !defined(AI_RENDERPIPELINE) // no SRP
#if defined(SHADOWS_DEPTH)
			clipPos = UnityApplyLinearShadowBias(clipPos);
#endif
#elif defined(AI_RENDERPIPELINE) // SRP
#if defined(UNITY_PASS_SHADOWCASTER) && !defined(SHADERPASS)
#if UNITY_REVERSED_Z
			clipPos.z = min(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
#else
			clipPos.z = max(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
#endif
#endif
#endif

			clipPos.xyz /= clipPos.w;

			if (UNITY_NEAR_CLIP_VALUE < 0)
				clipPos = clipPos * 0.5 + 0.5;
		}
