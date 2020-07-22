Shader "RayTracing/Effect/Easy Fog"
{
	Properties{
		[HDR] _TintColor("Tint Color", Color) = (0.5,0.5,0.5,0.5)
		_MainTex("Mask (R)", 2D) = "white" {}
		_BumpMap("Bump (Y-Flipped)", 2D) = "norm" {}
		_Fade("Soft Particles Factor", Range(1,1000)) = 1.0
		_FadeRange("Fade When Near", Range(0.1,100)) = 20
		_NoiseTex("Noise (R)", 2D) = "white" {}
	}

		Category
	  {

		  Tags
		  {
			  "Queue" = "Transparent"
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

				  #include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
				  #include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
				  #include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
				  #include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"


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

					  o.color = v.color * _TintColor;

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
				  sampler2D _BumpMap;

				  fixed4 frag(v2f i) : SV_Target
				  {
					  //return float4(i.color.xyz, 1);
					  UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i); //Insert

						float3 viewDir = normalize(i.viewDir.xyz);
					  float2 screenUV = i.screenPos.xy / i.screenPos.w;

					  float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
					  float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
					  float partZ = i.screenPos.z;
					  float fade = smoothstep(0, _Fade, sceneZ - partZ) * smoothstep(0.1, _FadeRange, length(i.worldPos - _WorldSpaceCameraPos.xyz));

					  
					

					  float4 bumpMap = tex2D(_BumpMap, i.texcoord);

					 

					  float3 tnormal =UnpackNormal(bumpMap);

					  tnormal.y = - tnormal.y;

					  float3 normal = i.normal.xyz;

					  ApplyTangent(normal, tnormal, i.wTangent);

						

						//  float outOfBounds;
						//  float4 bake = SampleVolume(i.worldPos, outOfBounds);
						//  i.worldPos.y *= 0.5;

					float shadow = SampleSkyShadow(i.worldPos);

					float direct = shadow * smoothstep(0, 1, dot(normal, _WorldSpaceLightPos0.xyz));
					
					float3 sunColor = GetDirectional();

					float3 lightColor = sunColor * direct;

					//TopDownSample(i.worldPos, bake.rgb, outOfBounds);

					float4 col = i.color;
					
					col.rgb *= GetAvarageAmbient(normal) + lightColor; // smoothstep(0, 1, col.rgb * (GetAvarageAmbient(normal) + lightColor));

					

					//float turblance = 1 / (0.1 +alpha);

					float noise = 
						tex2D(_NoiseTex, i.texcoord * 0.3 - tnormal.xy*0.02  + _Time.x*0.4).r
						*
						tex2D(_NoiseTex, i.texcoord *1.2 + tnormal.zx * 0.02  - _Time.x*0.3).r
						;

					float alpha = tex2D(_MainTex, i.texcoord + noise*0.02).r;

					alpha *= lerp(1, noise*6, (1 - alpha*alpha));

					col.a = smoothstep(0,1, alpha * col.a * fade);

					ApplyBottomFog(col.rgb, i.worldPos.xyz, viewDir.y);

				//	col.a = 1;

					//col.rgb = direct;

						  return col;
					  }
					  ENDCG
				  }
			  }
	  }
}
