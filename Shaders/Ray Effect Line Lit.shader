Shader "RayTracing/Effect/Thin Lines/Straight" {
	Properties{
		[NoScaleOffset] _MainTex("Albedo (RGB)", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_Hardness("Hardness", Range(0.25,8)) = 0.4
		_InvFade("Soft Particles Factor", Range(0.01,3)) = 0.05

		[KeywordEnum(Horisontal, Vertical)]	_DIR("Direction", Float) = 0
	}

	Category{
		Tags{
			"Queue" = "Transparent"
			"PreviewType" = "Plane"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
		}

		Cull Off
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha

		SubShader{


			  CGINCLUDE
		    #include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
			#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
			#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"

		
          

        ENDCG


			Pass{

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fwdbase
				#pragma multi_compile_instancing
				#pragma target 3.0

				#pragma shader_feature_local _DIR_HORISONTAL _DIR_VERTICAL  



				sampler2D _MainTex;
				float4 _Color;
				float _Hardness;
				
				float _InvFade;

				struct v2f {
					float4 pos : SV_POSITION;
					float4 screenPos : TEXCOORD1;                   // v2f (TEXCOORD can be 0,1,2, etc - the obly rule is to avoid duplication)
					float2 texcoord : TEXCOORD2;
					float3 worldPos : TEXCOORD3;
					float3 viewDir	: TEXCOORD4;
					float3 normal	: TEXCOORD5;

						float2 topdownUv : TEXCOORD6;
					
					float4 color : COLOR;
				};

			v2f vert(appdata_full v) {
				v2f o;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.texcoord = v.texcoord.xy;
				o.color = v.color * _Color;
				o.screenPos = ComputeScreenPos(o.pos);       	// vert
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.normal = UnityObjectToWorldNormal(v.normal);

				COMPUTE_EYEDEPTH(o.screenPos.z);

					o.topdownUv = (o.worldPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;
		
				return o;
			}

			float4 frag(v2f i) : COLOR
			{
				float3 normal = normalize(i.normal);
                float3 viewDir = normalize(i.viewDir);
					float2 screenUV = i.screenPos.xy / i.screenPos.w;

				#if _DIR_HORISONTAL
					float2 uv = i.texcoord.xy;
				#elif _DIR_VERTICAL
					float2 uv = i.texcoord.yx;
				#endif

				float2 width = fwidth(uv);

				float2 off = abs(uv.xy - 0.5);

				float visibility = //width.y *_Hardness * 
					smoothstep (0.45, 0, off.y);

			
				float4 col = i.color;

				visibility *= smoothstep(0.5, 0.25, off.y) * smoothstep(0.5, 0.5 - width.y * 10, off.x); // edge caps


				//float2 sampleTex = float2(pow(0.5 - off.y, 6) + step(uv.y, 0.5) * 0.25, uv.x);

				float4 tex =
					tex2D(_MainTex, uv + float2(uv.y, 0) + float2(_Time.x, - _Time.x * 5))
					* 
					tex2D(_MainTex, uv - float2(uv.y, 0) - float2(_Time.x, -_Time.x * 5))
					;

					//visibility *= col.a;



					col. a*= visibility * tex.r; 
				//visibility *= 0.25 + smoothstep(0.01, 0.25, tex.r * visibility)*2;

				//col.a = smoothstep(0,1, col.a * visibility);


			

				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
				float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
				float partZ = i.screenPos.z;
				float fade = smoothstep(0, 1, _InvFade * (sceneZ - partZ));

				float toCamera = length(_WorldSpaceCameraPos - i.worldPos.xyz) - _ProjectionParams.y;

				float dott = abs(dot(viewDir, normal));

				//return fade;

				col.a *=
					fade
					* saturate((toCamera) * 0.4)
					//* smoothstep(0, 1, dott)
					;


				float outOfBounds;
				float4 vol = SampleVolume(i.worldPos, outOfBounds);
				TopDownSample(i.worldPos, vol.rgb, outOfBounds);

				float3 ambientCol = lerp(vol, _RayMarchSkyColor.rgb * MATCH_RAY_TRACED_SKY_COEFFICIENT, outOfBounds);
				float direct = saturate((dot(normal, _WorldSpaceLightPos0.xyz)));
				float3 lightColor = _LightColor0.rgb * direct;
				
				//float4 col = float4(0.6 , 0.005, 0.005,1);

				col.rgb *=
				 
					(ambientCol * 0.5
					+ lightColor //* shadow
					) ;

				/*float3 reflectionPos;
				float outOfBoundsRefl;
				float3 bakeReflected = SampleReflection(newPos, viewDir, normal, shadow, reflectionPos, outOfBoundsRefl);
				TopDownSample(reflectionPos, bakeReflected, outOfBoundsRefl);*/

				float shadow = 1;

				float outOfBoundsStraight;
				float3 straightHit;
				float3 bakeStraight = SampleRay(i.worldPos, normalize(-viewDir - normal*col.a * 0.5), shadow, straightHit, outOfBoundsStraight);
				TopDownSample(straightHit, bakeStraight, outOfBoundsStraight);
				

					col.rgb += 
				+ bakeStraight * (1 - col.a) * 2 * float3(1, 0.01, 0.01); //, float3(1, 0.01, 0.01), smoothstep(0,0.05 + fresnel*0.05, world)) ;
				// + bakeReflected * 0.5 *  float3(1, 0.02, 0.02) * (1.5 - showStright)


				ApplyBottomFog(col.rgb, i.worldPos.xyz, i.viewDir.y);


				return col;
			}
			ENDCG

		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}
}

