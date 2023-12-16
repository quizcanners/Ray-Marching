Shader "RayTracing/Effect/Blurred Sprite" 
{
	Properties
	{
		_MainTex("Sprite Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)

		_Force("Blur Force", Range(0,1)) = 0
        _Angle("Angle", Range(0,6.3)) = 6
		_Visibility("Visibility", Range(0,1)) = 1
	}

	Category
	{
		Tags
		{
			"Queue" = "Transparent"
			"PreviewType" = "Plane"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
		}

		Cull Off
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha
		//Blend One OneMinusSrcAlpha

		SubShader
		{
			Pass
			{

				CGPROGRAM

			

				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fwdbase
				#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

				#pragma multi_compile_instancing

				#pragma multi_compile __ RT_FROM_CUBEMAP 
				#define RENDER_DYNAMICS

				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Debug.cginc"

				//sampler2D _MainTex;

				Texture2D _MainTex;
				SamplerState my_linear_clamp_sampler;
			

				float4 _MainTex_ST;
				float4 _MainTex_TexelSize;
				float4 _Color;

				struct v2f 
				{
					float4 pos : SV_POSITION;
					float2 texcoord : TEXCOORD0;
					float4 screenPos : TEXCOORD1;
					float3 viewDir	: TEXCOORD2;
					float3 worldPos : TEXCOORD3;
					float tracedShadows : TEXCOORD4;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};

				UNITY_INSTANCING_BUFFER_START(Props)
					UNITY_DEFINE_INSTANCED_PROP(float, _Force)
					UNITY_DEFINE_INSTANCED_PROP(float, _Angle)
					UNITY_DEFINE_INSTANCED_PROP(float, _Visibility)
					UNITY_INSTANCING_BUFFER_END(Props)

				v2f vert(appdata_full v) 
				{
					v2f o;

					UNITY_SETUP_INSTANCE_ID(v);
					UNITY_TRANSFER_INSTANCE_ID(v, o);

					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
					float4 noise = Noise3D(worldPos.xyz * 0.01 + float3(0, _Time.x*0.1, _Time.x * 0.1));
					v.vertex = mul(unity_WorldToObject, float4(worldPos + noise.xyz, v.vertex.w));
					o.worldPos = mul(unity_ObjectToWorld, v.vertex);

					o.pos = UnityObjectToClipPos(v.vertex);
					o.screenPos = ComputeScreenPos(o.pos); 
					o.texcoord = v.texcoord.xy - 0.5;
					o.viewDir.xyz = WorldSpaceViewDir(v.vertex);

					       o.tracedShadows = SampleRayShadow(o.worldPos) * SampleSkyShadow(o.worldPos);


					return o;
				}

				float2 Rot(float2 uv, float angle) 
				{
					float si = sin(angle);
					float co = cos(angle);
					return float2(co * uv.x - si * uv.y, si * uv.x + co * uv.y);
				}

				float4 frag(v2f i) : COLOR
				{
					UNITY_SETUP_INSTANCE_ID(i);
					float force = UNITY_ACCESS_INSTANCED_PROP(Props, _Force);
					float angle = UNITY_ACCESS_INSTANCED_PROP(Props, _Angle);
					float visibility = UNITY_ACCESS_INSTANCED_PROP(Props, _Visibility);
					
					float3 viewDir = normalize(i.viewDir.xyz);
				

					float distToCamera = length(_WorldSpaceCameraPos - i.worldPos.xyz) - _ProjectionParams.y;

					const float FADE_START = 5;

					float fadeAmount = smoothstep(FADE_START, 0, distToCamera);

					i.texcoord *= 3 - fadeAmount *2 + force * 0.2;

					i.texcoord += 0.5;

					float2 uv =  i.texcoord;
					float2 dx = ddx(uv);
					float2 screenUV = i.screenPos.xy / i.screenPos.w; 

					// Mip Level
					float2 px = _MainTex_TexelSize.z * dx;
					float2 py = _MainTex_TexelSize.w * ddy(uv);

					float2 rotation = normalize(dx);
					float sizeOnScreen = length(fwidth(uv)); 

					float mipLevel = fadeAmount * 8; // (max(0, 0.5 * log2(max(dot(px, px), dot(py, py))))) + force;

					float2 blurVector =Rot(rotation, -angle) * sizeOnScreen *  4 * force; //_MainTex_TexelSize.x;

				//	 _MainTex.Sample(my_linear_clamp_sampler, uv);


					float4 color0 = _MainTex.Sample(my_linear_clamp_sampler, uv - blurVector);
					float4 color1 = _MainTex.Sample(my_linear_clamp_sampler, uv  );
					float4 color2 = _MainTex.Sample(my_linear_clamp_sampler, uv + blurVector);
					float4 color3 = _MainTex.Sample(my_linear_clamp_sampler, uv + blurVector *2 );
					float4 color4 = _MainTex.Sample(my_linear_clamp_sampler, uv + blurVector *3 );

					float3 col;
					col.rgb =   color0.rgb * color0.a +
								color1.rgb * color1.a+
								color2.rgb * color2.a+
								color3.rgb * color3.a+
								color4.rgb * color4.a;

					float alpha = (color0.a + color1.a + color2.a + color3.a + color4.a)/5;
					col/=5;
					
					col.rgb /= alpha + 0.001;

					col.rgb = lerp(1, col.rgb, alpha);

					col.rgb *= _Color.rgb;

					float3 normal = -viewDir.xyz;

					float3 bake = SampleVolume_CubeMap(i.worldPos, normal);

				TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
				float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, viewDir, i.worldPos);
				float ao = topDownAmbient.a;
				bake += topDownAmbient.rgb;


				float shadow = i.tracedShadows; // SampleRayShadow(i.worldPos);

				bake += GetPointLight_Transpaent(i.worldPos,viewDir);

				col.rgb *= bake * ao + shadow * 0.5 * GetDirectional();

					//alpha = 1;

				

					//return toCamera;

					alpha = smoothstep(0, 0.1 + fadeAmount * 0.9, alpha * visibility )* (1- fadeAmount);

					//col *= alpha;

					return float4(col * 4, alpha * 0.25);

				}
				ENDCG
			}
		}
		Fallback "Legacy Shaders/Transparent/VertexLit"
	}
}

