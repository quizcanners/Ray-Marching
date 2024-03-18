Shader "RayTracing/Effect/Easy Fog"
{
	Properties{
		[HDR] _TintColor("Tint Color", Color) = (0.5,0.5,0.5,0.5)
		_MainTex("Mask (R)", 2D) = "white" {}
		_BumpMap("Bump (Y-Flipped)", 2D) = "norm" {}
		_Fade("Soft Particles Factor", Range(1,1000)) = 1.0
		_FadeRange("Fade When near", Range(0.1,1000)) = 50
		_NoiseTex("Noise (R)", 2D) = "white" {}
	}

	Category
	{

		Tags
		  {
			  "Queue" = "Transparent+1"
			  "IgnoreProjector" = "True"
			  "RenderType" = "Transparent"
			  "PreviewType" = "Plane"
			  "LightMode" = "ForwardBase"
		  }

		  Blend SrcAlpha OneMinusSrcAlpha

		 Cull Off
		 ZWrite Off

		  SubShader
		  {
			  Pass
			  {

				  CGPROGRAM

			//	 #pragma multi_compile __ RT_FROM_CUBEMAP 
				#define RENDER_DYNAMICS

				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler.cginc"
			//#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"
				#pragma multi_compile ___ _qc_IGNORE_SKY

				   #pragma multi_compile ___ qc_LAYARED_FOG
			 	#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Transparent.cginc"

				  #pragma vertex vert
				  #pragma fragment frag

				  struct v2f {
					  float4 vertex : SV_POSITION;
					  fixed4 color : COLOR;
					  float2 texcoord : TEXCOORD0;
					  float4 screenPos : TEXCOORD1;
					  float3 worldPos	: TEXCOORD2;
					  float3 viewDir	: TEXCOORD3;
					  float3 normal		: TEXCOORD4;
					  float4 wTangent	: TEXCOORD5;
					  UNITY_VERTEX_OUTPUT_STEREO
				  };

				  float4 _MainTex_ST;
				  fixed4 _TintColor;
				  v2f vert(appdata_full v)
				  {
					  v2f o;
					UNITY_SETUP_INSTANCE_ID(v); //Insert
					  UNITY_INITIALIZE_OUTPUT(v2f, o); //Insert
					  UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); //Insert
					  o.vertex = UnityObjectToClipPos(v.vertex);
					  o.screenPos = ComputeScreenPos(o.vertex);
					  COMPUTE_EYEDEPTH(o.screenPos.z);

					  o.color = v.color *_TintColor;

					  o.texcoord = TRANSFORM_TEX(v.texcoord.xy, _MainTex);

					  float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					  o.worldPos = worldPos;
					  o.viewDir = WorldSpaceViewDir(v.vertex);

					  o.normal.xyz = UnityObjectToWorldNormal(v.normal);
					  TRANSFER_WTANGENT(o)
					

					  return o;
				  }

				  float _Fade;
				  float _FadeRange;
				  sampler2D _NoiseTex;

				  sampler2D _MainTex;
				  float4 _MainTex_TexelSize;
				  sampler2D _BumpMap;

				float4 TextureBicubic(float2 texCoords, float4 texelSize) 
				{

					float2 texSize = texelSize.zw;//textureSize(sampler, 0);
					float2 invTexSize = texelSize.xy;///1.0 / texSize;

					texCoords = texCoords * texSize - 0.5;

					float2 fxy = texCoords % 1;

					texCoords -= fxy;

					float4 xcubic = cubic_Interpolation(fxy.x);
					float4 ycubic = cubic_Interpolation(fxy.y);

					float4 c = texCoords.xxyy + float2(-0.5, +1.5).xyxy;

					float4 s = float4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);

					float4 offset = c + float4(xcubic.yw, ycubic.yw) / s;

					offset *= invTexSize.xxyy;

					float4 sample0 = tex2Dlod(_MainTex, float4(offset.xz, 0, 0));
					float4 sample1 = tex2Dlod(_MainTex, float4(offset.yz, 0, 0));
					float4 sample2 = tex2Dlod(_MainTex, float4(offset.xw, 0, 0));
					float4 sample3 = tex2Dlod(_MainTex, float4(offset.yw, 0, 0));

					float sx = s.x / (s.x + s.y);
					float sy = s.z / (s.z + s.w);

					return lerp(	lerp(sample3, sample2, sx), lerp(sample1, sample0, sx), sy);
				}

				  fixed4 frag(v2f i) : SV_Target
				  {
					  //return float4(i.color.xyz, 1);
					  UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i); //Insert

						float3 viewDir = normalize(i.viewDir.xyz);
					  float2 screenUV = i.screenPos.xy / i.screenPos.w;

					  float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
					  float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
					  float partZ = i.screenPos.z;

					    float dott = dot(viewDir, i.normal.xyz);

					  float fade = smoothstep(0.2, 0.5, abs(dott)) * smoothstep(0, _Fade, sceneZ - partZ) * smoothstep(0.1, _FadeRange, length(i.worldPos - _WorldSpaceCameraPos.xyz));

					  float isBackface = smoothstep(0, -0.001, dott);

					  i.normal.xyz = lerp(i.normal.xyz, -i.normal.xyz, isBackface);


					  float4 bumpMap = tex2D(_BumpMap, i.texcoord);

					 

					  float3 tnormal =UnpackNormal(bumpMap);

					  tnormal.y = - tnormal.y;

					  float3 normal = i.normal.xyz;

					  ApplyTangent(normal, tnormal, i.wTangent);

						

						//  float outOfBounds;
						//  float4 bake = SampleVolume(i.worldPos, outOfBounds);
						//  i.worldPos.y *= 0.5;

					#if _qc_IGNORE_SKY

						float3 lightColor = 0;

					#else
						float shadow = SampleSkyShadow(i.worldPos);

						float direct = shadow * smoothstep(0, 1, dot(normal, _WorldSpaceLightPos0.xyz));
					
						float3 sunColor = GetDirectional();

						float3 lightColor = sunColor * direct;
					#endif

					//TopDownSample(i.worldPos, bake.rgb, outOfBounds);

		
				

					//float turblance = 1 / (0.1 +alpha);

					float noise = 
						tex2D(_NoiseTex, i.texcoord * 0.3 - tnormal.xy*0.02  + _Time.x*0.4).r
						*
						tex2D(_NoiseTex, i.texcoord *1.2 + tnormal.zx * 0.02  - _Time.x*0.3).r
						;

					

					float alpha = 	TextureBicubic( i.texcoord + noise*0.02, _MainTex_TexelSize).r;//
					//tex2D(_MainTex, i.texcoord + noise*0.02).r;

					alpha *= lerp(1, noise*7, (1 - alpha*alpha));

					alpha = smoothstep(0,1, alpha * fade) * 0.5;

					float3 col = //i.color;
					
					GetAvarageAmbient(normal) + lightColor * 0.5; // smoothstep(0, 1, col.rgb * (GetAvarageAmbient(normal) + lightColor));

					ApplyBottomFog(col.rgb, i.worldPos.xyz, viewDir.y);

						float4 result = float4(col, alpha);

						ApplyLayeredFog_Transparent(result, screenUV, i.worldPos);

						  return result;
					  }
					  ENDCG
				  }
			  }
	  }
}
