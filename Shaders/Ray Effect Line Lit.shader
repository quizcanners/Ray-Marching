Shader "RayTracing/Effect/Blood Trail Streak" {
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

		SubShader
		{

			 CGINCLUDE
			#include "Assets/Ray-Marching/Shaders/Savage_Sampler_Debug.cginc"
			#include "Assets/Ray-Marching/Shaders/Savage_DepthSampling.cginc"

        ENDCG


			Pass{

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				//#pragma multi_compile_fwdbase
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
					float traced : TEXCOORD5;
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
				float3 normal = UnityObjectToWorldNormal(v.normal);
				o.traced = GetQcShadow(o.worldPos);
				//GetTraced_Subsurface_Vertex(o.worldPos, normalize(o.viewDir.xyz), normal.xyz);//GetTraced_Glassy_Vertex(o.worldPos, normalize(o.viewDir.xyz), normal.xyz);
				//SampleVolume_CubeMap(worldPos, -normal);
				COMPUTE_EYEDEPTH(o.screenPos.z);

				return o;
			}


			float4 frag(v2f i) : COLOR
			{
                float3 viewDir = normalize(i.viewDir);
				float2 screenUV = i.screenPos.xy / i.screenPos.w;

				#if _DIR_HORISONTAL
					float2 uv = i.texcoord.xy;
				#elif _DIR_VERTICAL
					float2 uv = i.texcoord.yx;
				#endif

				float2 width = fwidth(uv);

				float2 off = abs(uv.xy - 0.5);

				float visibility = smoothstep (0.45, 0, off.y);

				float4 col = 1;//  ;

				visibility *= smoothstep(0.5, 0.25, off.y) * smoothstep(0.5, 0.5 - width.y * 10, off.x); // edge caps

				float4 tex =
					tex2D(_MainTex, uv + float2(uv.y, 0) + float2(_Time.x, - _Time.x * 5))
					* 
					tex2D(_MainTex, uv - float2(uv.y, 0) - float2(_Time.x, -_Time.x * 5))
					;

					col.a = visibility * tex.r; 

			

				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
				float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
				float partZ = i.screenPos.z;
				float fade = smoothstep(0, 1, _InvFade * (sceneZ - partZ));

				float toCamera = length(_WorldSpaceCameraPos - i.worldPos.xyz) - _ProjectionParams.y;


				col.a *=
					fade
					* saturate((toCamera) * 0.4)
					;

					clip(col.a-0.1);

				float3 normal = -viewDir.xyz;
				normal.y = 0;
				normal = normalize(normal);



				
				float3 volumeSamplePosition = i.worldPos; //+ i.normal.xyz / _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;

				//	float fresnel = 1-col.a;// 1-saturate(dot(normal,viewDir));

					//float specular =0.8;

				

    	//float ao = 1;

					float3 refractedRay =  refract(-viewDir, normal, 0.75);

					//float translucentSun =  smoothstep(0.8,1, dot(_WorldSpaceLightPos0.xyz, refractedRay));//GetDirectionalSpecular(-normal, viewDir, specular * 0.95);// pow(dott, power) * brightness;

					float3 bake = SampleVolume_CubeMap(i.worldPos, refractedRay);

					TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
					float4 topDownAmbientSpec = SampleTopDown_Specular(topdownUv, refractedRay, i.worldPos, normal, 0.95);

				float ao = topDownAmbientSpec.a;
				bake += topDownAmbientSpec.rgb;

			float shadow = i.traced; 
					
					bake *= ao;

					bake += GetTranslucent_Sun(refractedRay) * shadow;

					col.rgb *= _qc_BloodColor.rgb * bake;





				ApplyBottomFog(col.rgb, i.worldPos.xyz, i.viewDir.y);


				return col;
			}
			ENDCG

		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}
}

