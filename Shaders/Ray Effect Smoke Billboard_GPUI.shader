Shader "GPUInstancer/RayTracing/Effect/Smoke Billboard"
{
	Properties
	{
		_MainTex("Particle Texture", 2D) = "white" {}
		_InvFade("Soft Particles Factor", Range(0.01,0.5)) = 0.1
		_Color("Color", Color) = (1,1,1,1)
		_Heat("_Heat", Range(0,5)) = 0.1
		_Dissolve("_Dissolve", Range(0,1)) = 0.5
		_Seed("_Seed", Range(0,1)) = 0.5
	}

	Category
	{
		Tags
		{
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
		}

		SubShader 
		{
			Pass 
			{
				Blend SrcAlpha OneMinusSrcAlpha
				ColorMask RGB
				Cull Off
				ZWrite Off

				CGPROGRAM
#include "UnityCG.cginc"
#include "./../../GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
#pragma instancing_options procedural:setupGPUI
#pragma multi_compile_instancing

				#pragma vertex vert
				#pragma fragment frag
						#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
				#pragma multi_compile __ _qc_IGNORE_SKY 

			 	#include "Assets/Ray-Marching/Shaders/Savage_Sampler_Debug.cginc"
				#include "Assets/Ray-Marching/Shaders/Savage_DepthSampling.cginc"

			   struct appdata_t 
				{
				 float4 vertex : POSITION;
				 fixed4 color : COLOR;
				 float2 texcoord : TEXCOORD0;
				 float3 normal : NORMAL;
				  UNITY_VERTEX_INPUT_INSTANCE_ID
			   };

			   struct v2f 
			   {
					float4 vertex : POSITION;
					UNITY_VERTEX_INPUT_INSTANCE_ID // use this to access instanced properties in the fragment shader.
					float2 texcoord: TEXCOORD0;
					float4 screenPos : TEXCOORD1;
					float3 viewDir	: TEXCOORD2;
					float3 worldPos : TEXCOORD3;
					float tracedShadows : TEXCOORD4;
					fixed4 color : COLOR;
				
			   };

				UNITY_INSTANCING_BUFFER_START(Props)
				UNITY_DEFINE_INSTANCED_PROP(float, _Heat)
				UNITY_DEFINE_INSTANCED_PROP(float, _Dissolve)
				UNITY_DEFINE_INSTANCED_PROP(float, _Seed)
				UNITY_INSTANCING_BUFFER_END(Props)

				sampler2D _MainTex;
				float4 _MainTex_ST;
				float4 _Color;
				float _InvFade;

				v2f vert(appdata_full v)
				{
					 v2f o;

					 UNITY_SETUP_INSTANCE_ID(v);
					 UNITY_TRANSFER_INSTANCE_ID(v, o);
			 
					 o.vertex = UnityObjectToClipPos(v.vertex);
					 o.worldPos = mul(unity_ObjectToWorld, v.vertex);
					 o.screenPos = ComputeScreenPos(o.vertex);
					 o.texcoord = v.texcoord;
					 o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
					 o.color = v.color * _Color;

					 o.tracedShadows = SampleRayShadow(o.worldPos) * SampleSkyShadow(o.worldPos);

					 COMPUTE_EYEDEPTH(o.screenPos.z);
					 return o;
				}

			float Gyrid(float3 pos) 
			{ 
				return abs(dot(sin(pos), cos(pos.zxy)));
			}

			float4 frag(v2f i) : COLOR
			{
				UNITY_SETUP_INSTANCE_ID(i);
				//float heat = UNITY_ACCESS_INSTANCED_PROP(Props, _Heat);
				float dissolve = UNITY_ACCESS_INSTANCED_PROP(Props, _Dissolve);
				float seed = UNITY_ACCESS_INSTANCED_PROP(Props, _Seed); 

				float2 screenUV = i.screenPos.xy / i.screenPos.w;
				 i.viewDir.xyz = normalize(i.viewDir.xyz);

				float2 offUv = i.texcoord - 0.5;
				float2 sphereUv = offUv * offUv; 

				float offCenter = smoothstep(0, 0.25, sphereUv.x + sphereUv.y); 

				float2 randomUv = offUv * 0.5 * (1 + seed - dissolve) + seed; 

				float tex = 0.1/(0.1 + offCenter) + 
					tex2D(_MainTex, Rotate(randomUv, seed * 4)  + _Time.x).r;

				//return tex;

				float3 forNormal = -i.viewDir.xyz;
				forNormal.y = 0;
				forNormal = normalize(forNormal);

				float3 normal = (cross(float3(0, 1, 0), -forNormal) * offUv.x); // X component
				normal.y = offUv.y;

				normal = lerp(normalize(normal), -i.viewDir.xyz, pow(1-offCenter, (1.01 - tex) * 4));

				normal = normalize(normal);

				//float3 ambientCol = SampleVolume_CubeMap(i.worldPos, normal);

				float ao;
				float3 ambientCol = SampleAmbientLight(i.worldPos, ao);

				ambientCol += GetPointLight_Transpaent(i.worldPos, -normal);

			//	TopDownSample(i.worldPos, ambientCol);
		
				float topShadow = smoothstep(0.3, 0.5 + tex*0.5, i.texcoord.y);

				float4 col = i.color;// *(2 - dissolve) * 0.5;

				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
				float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
				float partZ = i.screenPos.z;
				float differ = sceneZ - partZ;
				float fade = smoothstep(0,1, _InvFade * (sceneZ - partZ));
				float toCamera = smoothstep(0,1, length(_WorldSpaceCameraPos - i.worldPos.xyz) - _ProjectionParams.y);

				col.a = min(1, tex * (1- offCenter)  
				* fade //* (1 + contact)
					* (1 - dissolve) * toCamera) * 0.5;

				//float offset = i.viewDir.xyz * 0.1 * (0.1 + sin(col.a*10));

				//float3 shadowPos = i.worldPos + i.viewDir.xyz * 2 * col.a;

				float shadow = i.tracedShadows/* (
						SampleRayShadow(shadowPos + offset*0.5) +
						SampleRayShadow(shadowPos + offset) +
						SampleRayShadow(shadowPos - offset)
						) * 0.33*/
					//* SampleSkyShadow(i.worldPos)
					;

				//return shadow;

				col.rgb *= ambientCol * ao + topShadow * 0.5 * shadow * GetDirectional();

				ApplyBottomFog(col.rgb, i.worldPos.xyz, i.viewDir.y);

				 return col;

			   }
		   ENDCG
		 }
	   }
   }
}
