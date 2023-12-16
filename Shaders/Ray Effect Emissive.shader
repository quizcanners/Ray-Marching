Shader "RayTracing/Effect/Emissive"
{
	Properties{
	   _MainTex("Particle Texture", 2D) = "white" {}
	   _InvFade("Soft Particles Factor", Range(0.01,3.0)) = 1.0
		[HDR]_Color("Color", Color) = (1,1,1,1)
	}

	Category{
		Tags 
		{ 
			"Queue" = "Transparent" 
			"IgnoreProjector" = "True" 
		   "RenderType" = "Transparent"  
	    }

		Blend SrcAlpha One
		ColorMask RGB
		Cull Back
		ZWrite Off

	   SubShader {
		 Pass {

		   CGPROGRAM
		   #pragma vertex vert
		   #pragma fragment frag
		   #pragma multi_compile_instancing

		   #include "Assets/Qc_Rendering/Shaders/Savage_Sampler.cginc"
		   #include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"

		   struct appdata_t 
	   {
			 float4 vertex : POSITION;
			 fixed4 color : COLOR;
			 float2 texcoord : TEXCOORD0;
			 float3 normal : NORMAL;
		   };


		   struct v2f {
			 float4 pos : POSITION;
			 fixed4 color : COLOR;
			 float2 texcoord: TEXCOORD0;
			 float4 screenPos : TEXCOORD1;
			 float3 normal	: TEXCOORD2;
			 float3 viewDir	: TEXCOORD3;
		   };

		   sampler2D _MainTex;
		   float4 _MainTex_ST;
		   float4 _Color;

		   v2f vert(appdata_full v)
		   {
			 v2f o;
			 UNITY_SETUP_INSTANCE_ID(v);
			 o.pos = UnityObjectToClipPos(v.vertex);
			 o.screenPos = ComputeScreenPos(o.pos);
			 COMPUTE_EYEDEPTH(o.screenPos.z);

			 o.color = v.color;
			 o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
			
			 o.normal = UnityObjectToWorldNormal(v.normal);
			 o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
			 UNITY_SETUP_INSTANCE_ID(v);
			 return o;
		   }

		   float _InvFade;

		   float4 frag(v2f i) : COLOR
		   {
				float2 screenUV = i.screenPos.xy / i.screenPos.w;
				i.viewDir.xyz = normalize(i.viewDir.xyz);

				float4 col = tex2D(_MainTex, i.texcoord)	* _Color;

				float volumetriEdge = _InvFade;

				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
				float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
				float fade = smoothstep(_InvFade, 0, abs(sceneZ - i.screenPos.z));

				col.a *= fade;

				return col;

		   }
		   ENDCG
		 }
	   }

   }
}
