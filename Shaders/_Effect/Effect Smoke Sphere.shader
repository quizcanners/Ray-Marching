Shader "RayTracing/Effect/Smoke Sphere"
{
	Properties
	{
		_MainTex("Particle Texture", 2D) = "white" {}
		_InvFade("Soft Particles Factor", Range(0.01,5)) = 0.1
		//_Visibility ("Visibility", Range(0,1)) = 1.0
		//_Color("Color", Color) = (1,1,1,1)
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
				Cull Back

				ZWrite Off


			   CGPROGRAM
				#pragma multi_compile ___ _qc_IGNORE_SKY
			   #pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
			     #pragma multi_compile ___ qc_LAYARED_FOG
			   #include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Transparent.cginc"

			   #pragma vertex vert
			   #pragma fragment frag
			   #pragma multi_compile_instancing

			   struct appdata_t {
				 float4 vertex : POSITION;
				  UNITY_VERTEX_INPUT_INSTANCE_ID
				 fixed4 color : COLOR;
				 float2 texcoord : TEXCOORD0;
				 float3 normal : NORMAL;
			   };


		   struct v2f {
			 float4 pos : POSITION;
			  UNITY_VERTEX_INPUT_INSTANCE_ID // use this to access instanced properties in the fragment shader.
			 fixed4 color : COLOR;
			 float2 texcoord: TEXCOORD0;
			 float4 screenPos : TEXCOORD1;
			 float3 normal	: TEXCOORD2;
			 float3 viewDir	: TEXCOORD3;
			 float3 worldPos : TEXCOORD4;
			 float2 noiseUV :	TEXCOORD5;
			// float tracedShadows : TEXCOORD6;
	
		   };

		    UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_DEFINE_INSTANCED_PROP(float, _Visibility)
		    UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
            UNITY_INSTANCING_BUFFER_END(Props)

		   sampler2D _MainTex;
		   float4 _MainTex_ST;
		 

		 //  sampler2D _CameraDepthTexture;
		   float _InvFade;




		   v2f vert(appdata_full v)
		   {
			 v2f o;
			 UNITY_SETUP_INSTANCE_ID(v);
             UNITY_TRANSFER_INSTANCE_ID(v, o);

			 o.worldPos = mul(unity_ObjectToWorld, v.vertex);

			 float outsideVolume;
			 float4 scene = SampleSDF(o.worldPos , outsideVolume);

			 o.normal = UnityObjectToWorldNormal(v.normal);

			// float perpendicular = 1-abs(dot(o.normal.xyz, scene.xyz));

			// o.worldPos += o.normal.xyz * perpendicular * smoothstep(0,3,scene.a);

			//v.vertex = mul(unity_WorldToObject, float4(o.worldPos.xyz, v.vertex.w));

			 o.pos = UnityObjectToClipPos(v.vertex);
			 o.screenPos = ComputeScreenPos(o.pos);
			 COMPUTE_EYEDEPTH(o.screenPos.z);

			 o.color = v.color;
			 o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
			 o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
			 o.noiseUV = o.texcoord * (123.12345678) + float2(_SinTime.x, _CosTime.y) * 32.12345612;
			// o.tracedShadows = SampleRayShadow(o.worldPos) * SampleSkyShadow(o.worldPos);



			 return o;
		   }

	

		   float4 frag(v2f i) : COLOR
		   {
		   		UNITY_SETUP_INSTANCE_ID(i);
				float visibility = UNITY_ACCESS_INSTANCED_PROP(Props, _Visibility);
				float4 vColor = UNITY_ACCESS_INSTANCED_PROP(Props, _Color);

				float2 screenUV = i.screenPos.xy / i.screenPos.w;

			    float3 viewDir = normalize(i.viewDir.xyz);

				float dott = abs(dot(viewDir, i.normal.xyz));

			 float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
			 float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
			 float partZ = i.screenPos.z;
			 float fade = smoothstep(0,1, _InvFade * (sceneZ - partZ)) ;

			 float toCamera = length(_WorldSpaceCameraPos - i.worldPos.xyz) - _ProjectionParams.y;

			 float alpha =   
				 fade 
				 * saturate((toCamera ) * 0.4) 
				 * smoothstep(0, 1, dott) 
				 * visibility
				 //* 0.5
				 ;


			 float4 col = float4(vColor.rgb, alpha);

			 float shadow = GetShadowVolumetric(i.worldPos, i.screenPos.z, viewDir);  

			col.rgb = TransparentLightStandard(col, i.worldPos, i.normal.xyz, viewDir, shadow);

			ApplyBottomFog(col.rgb, i.worldPos.xyz, viewDir.y);

			 ApplyLayeredFog_Transparent(col, screenUV, toCamera);

			 return col;

		   }
		   ENDCG
		 }
	   }

   }
}
