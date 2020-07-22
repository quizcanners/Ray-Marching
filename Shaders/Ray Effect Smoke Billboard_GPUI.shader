Shader "GPUInstancer/RayTracing/Effect/Smoke Billboard"
{
	Properties
	{
		_MainTex("Particle Texture", 2D) = "white" {}
		_SmokeShape("Smoke Texture", 2D) = "white" {}
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
				#pragma multi_compile_fwdbase

			 	#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
				#include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
				#include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
				#include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"

			   struct appdata_t {
				 float4 vertex : POSITION;
				 UNITY_VERTEX_INPUT_INSTANCE_ID
				 fixed4 color : COLOR;
				 float2 texcoord : TEXCOORD0;
				 float3 normal : NORMAL;
			   };


		   struct v2f 
		   {
				float4 vertex : POSITION;
				 UNITY_VERTEX_INPUT_INSTANCE_ID // use this to access instanced properties in the fragment shader.
				float2 texcoord: TEXCOORD0;
				float4 screenPos : TEXCOORD1;
				float3 viewDir	: TEXCOORD2;
				float3 worldPos : TEXCOORD3;
				fixed4 color : COLOR;
				
		   };

		    UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_DEFINE_INSTANCED_PROP(float, _Heat)
		    UNITY_DEFINE_INSTANCED_PROP(float, _Dissolve)
			UNITY_DEFINE_INSTANCED_PROP(float, _Seed)
            UNITY_INSTANCING_BUFFER_END(Props)

			  sampler2D _MainTex;
			  sampler2D _SmokeShape;
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

			// ColorCorrect(o.color.rgb);

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
            float heat = UNITY_ACCESS_INSTANCED_PROP(Props, _Heat);
			float dissolve = UNITY_ACCESS_INSTANCED_PROP(Props, _Dissolve);
			float seed = UNITY_ACCESS_INSTANCED_PROP(Props, _Seed); 

			float2 screenUV = i.screenPos.xy / i.screenPos.w;
			 i.viewDir.xyz = normalize(i.viewDir.xyz);

			float2 offUv = (i.texcoord - 0.5);
			float2 sphereUv = offUv * offUv; 

			float offCenter = smoothstep(0, 0.25, sphereUv.x + sphereUv.y); 

			float2 randomUv = offUv * (1 + seed - dissolve) + seed; 


			float tex = 0.1/(0.1 + offCenter) +
				tex2D(_MainTex,randomUv + _Time.x).r 
					*
				tex2D(_SmokeShape, Rotate(offUv, seed*4) + 0.5).a * 2
				;

			float  outOfBounds;	
			float4 vol = SampleVolume(i.worldPos, outOfBounds);
			TopDownSample(i.worldPos, vol.rgb, outOfBounds);
			float3 ambientCol = lerp(vol, _RayMarchSkyColor.rgb * MATCH_RAY_TRACED_SKY_COEFFICIENT, outOfBounds);

			float4 col = i.color * (2 - dissolve ) * 0.5;
			col.rgb *= ambientCol + GetDirectional() * outOfBounds;

			float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
			float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
			float fade = smoothstep(0,1, _InvFade * (sceneZ - i.screenPos.z));
			float toCamera = smoothstep(0,1, length(_WorldSpaceCameraPos - i.worldPos.xyz) - _ProjectionParams.y);

			//float wid = fwidth(i.texcoord.xy);

		//	float TILING = 30;

		

			col.a = min(1, tex * (1- offCenter)  
			* fade * (1-dissolve) * toCamera);


			col.rgb += heat * float3(1,0.5,0);


			col *= i.color;

			float3 mix = col.gbr + col.brg;
			col.rgb += mix * mix * 0.02;

			ApplyBottomFog(col.rgb, i.worldPos.xyz, i.viewDir.y);

			 return col;

		   }
		   ENDCG
		 }
	   }
   }
}
