Shader "RayTracing/Smoke"
{
	Properties{
	   _MainTex("Particle Texture", 2D) = "white" {}
	   _InvFade("Soft Particles Factor", Range(0.01,3.0)) = 1.0
	}

	Category{
		Tags { "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent"  }
		Blend SrcAlpha OneMinusSrcAlpha
		ColorMask RGB
		Cull Off 
		ZWrite Off


	   SubShader {
		 Pass {

		   CGPROGRAM
		   #pragma vertex vert
		   #pragma fragment frag
		   #pragma fragmentoption ARB_precision_hint_fastest
		   #pragma multi_compile_particles

		   #include "UnityCG.cginc"
		   #include "PrimitivesScene.cginc"

		   sampler2D _MainTex;

		   struct appdata_t {
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
			 float4 projPos : TEXCOORD2;
			 //float3 VL		: TEXCOORD3;
			 float3 normal	: TEXCOORD4;
			 //float3 ViewT	: TEXCOORD5;
			 float3 viewDir	: TEXCOORD6;
			 float3 worldPos : TEXCOORD7;
		   };

		   float4 _MainTex_ST;
		  // float4 _Dist_ST;

		   v2f vert(appdata_full v)
		   {
			 v2f o;
			 o.pos = UnityObjectToClipPos(v.vertex);

			 o.projPos = ComputeScreenPos(o.pos);
			 COMPUTE_EYEDEPTH(o.projPos.z);

			 o.color = v.color;
			 o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
			 o.screenPos = ComputeScreenPos(o.pos);
			 o.normal = UnityObjectToWorldNormal(v.normal);
			 //o.ViewT = normalize(ObjSpaceViewDir(v.vertex));
			 //o.VL = ShadeVertexLights(v.vertex, dot(o.normal,o.ViewT));
			 o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
			 o.worldPos = mul(unity_ObjectToWorld, v.vertex);

			 return o;
		   }

		   sampler2D _CameraDepthTexture;
		   float _InvFade;


		   fixed4 frag(v2f i) : COLOR
		   {
				float2 screenUV = i.screenPos.xy / i.screenPos.w;

				float toCamera = length(_WorldSpaceCameraPos - i.worldPos.xyz);

			   i.viewDir.xyz = normalize(i.viewDir.xyz);

				float dott = max(0, dot(i.viewDir.xyz, i.normal.xyz));


			 //float4 tex = tex2D(_MainTex, i.texcoord);

		


			 float4 depth = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos));

			 float sceneZ = LinearEyeDepth( UNITY_SAMPLE_DEPTH(depth));
			 float partZ = i.projPos.z;
			 float fade = saturate(_InvFade * (sceneZ - partZ));

			 float3 noise = tex2Dlod(_Global_Noise_Lookup, float4(screenUV * 13.5 + float2(_SinTime.w, _CosTime.w) * 32, 0, 0));


			 float4 tex = SampleVolume(_RayMarchingVolume, i.worldPos
				 - i.viewDir.xyz * _RayMarchingVolumeVOLUME_POSITION_OFFSET.w * noise.r * 4
				 , _RayMarchingVolumeVOLUME_POSITION_N_SIZE
				 , _RayMarchingVolumeVOLUME_H_SLICES);

			 float4 tex2 = SampleVolume(_RayMarchingVolume, i.worldPos
				 - i.viewDir.xyz * _RayMarchingVolumeVOLUME_POSITION_OFFSET.w *(1 + noise.g * 4)
				 //+ i.normal.xyz * _RayMarchingVolumeVOLUME_POSITION_OFFSET.w
				 , _RayMarchingVolumeVOLUME_POSITION_N_SIZE
				 , _RayMarchingVolumeVOLUME_H_SLICES);

			 tex = (tex + tex2) * 0.5;

			 tex.a = fade * min(1, toCamera * 0.4)  * smoothstep(0, 2, dott);

			 return tex;

		   }
		   ENDCG
		 }
	   }

   }
}
