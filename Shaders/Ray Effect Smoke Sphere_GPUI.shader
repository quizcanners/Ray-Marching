Shader "GPUInstancer/RayTracing/Effect/Smoke Sphere"
{
	Properties
	{
		_MainTex("Particle Texture", 2D) = "white" {}
		_InvFade("Soft Particles Factor", Range(0.01,0.5)) = 0.1
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
#include "UnityCG.cginc"
#include "./../../GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
#pragma instancing_options procedural:setupGPUI
#pragma multi_compile_instancing

			   #include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"

			   #pragma vertex vert
			   #pragma fragment frag
			   #pragma multi_compile_fwdbase

			 

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
			 float pop : TEXCCORD6;
			 float4 nrmAndDist : TEXCOORD7;
			 float2 topdownUv : TEXCOORD8;
	
		   };

		    UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_DEFINE_INSTANCED_PROP(float, _Visibility)
		    UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
            UNITY_INSTANCING_BUFFER_END(Props)

		   sampler2D _MainTex;
		   float4 _MainTex_ST;
		 

		   sampler2D _CameraDepthTexture;
		   float _InvFade;

		   float sdGyroid(float3 pos, float scale) {

			   pos.y += _Time.y * 0.1;

			   pos *= scale;
			   return abs(dot(sin(pos), cos(pos.zxy))) / scale;
		   }


		   v2f vert(appdata_full v)
		   {
			 v2f o;
			 UNITY_SETUP_INSTANCE_ID(v);
             UNITY_TRANSFER_INSTANCE_ID(v, o);

			 o.worldPos = mul(unity_ObjectToWorld, v.vertex);

			 o.normal = UnityObjectToWorldNormal(v.normal);

			 o.pop = sdGyroid(o.worldPos * 0.5 , 2);

			 o.nrmAndDist = SdfNormalAndDistance(o.worldPos);

			// float inDir = dot(o.normal, o.nrmAndDist.xyz);

			 v.vertex.xyz += (o.normal + o.nrmAndDist.xyz * 2 //* (1 +  o.nrmAndDist.w)
			 ) 
				 * (1 + o.pop) * 0.05;

			 o.pos = UnityObjectToClipPos(v.vertex);
			 o.screenPos = ComputeScreenPos(o.pos);
			 COMPUTE_EYEDEPTH(o.screenPos.z);

			 o.color = v.color;
			 o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
			 o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
			 o.noiseUV = o.texcoord * (123.12345678) + float2(_SinTime.x, _CosTime.y) * 32.12345612;

			 o.topdownUv = (o.worldPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;

			 return o;
		   }

	

		   fixed4 frag(v2f i) : COLOR
		   {
		   		UNITY_SETUP_INSTANCE_ID(i);
				float visibility = UNITY_ACCESS_INSTANCED_PROP(Props, _Visibility);
				float4 vColor = UNITY_ACCESS_INSTANCED_PROP(Props, _Color);


				float2 screenUV = i.screenPos.xy / i.screenPos.w;

			    i.viewDir.xyz = normalize(i.viewDir.xyz);

				float dott = abs(dot(i.viewDir.xyz, i.normal.xyz));

				float4 noise = tex2Dlod(_Global_Noise_Lookup, float4(i.noiseUV, 0, 0));
				float outOfBounds;

				float VOL_SIZE = 1; 
			
				float4 normalAndDist = i.nrmAndDist; 

				float gyr = sdGyroid(i.worldPos * VOL_SIZE * (1 //- dott*0.1 
					+ normalAndDist.w * _SinTime.x * 0.01), 2 * VOL_SIZE);
			
				float3 gyrPos = i.worldPos * 0.5 + gyr * 0.1;

				gyr += sdGyroid(gyrPos, 4);

				gyr = smoothstep(0, 1, gyr);

				float3 normOffset = normalAndDist.xyz * VOL_SIZE * 2  / (1+normalAndDist.w);

				float4 bake = SampleVolume(i.worldPos
				 - i.viewDir.xyz * VOL_SIZE  * gyr //* noise.r
				 
				 //+ normOffset.yzx
				 , outOfBounds);

				float4 bake2 = SampleVolume(i.worldPos
				 - i.viewDir.xyz * VOL_SIZE *(1 + gyr)

				 + normOffset
				 //+ i.normal.xyz * _RayMarchingVolumeVOLUME_POSITION_OFFSET.w
				 , outOfBounds);

			 bake = (bake + bake2) * 0.5;


			 float4 topDown = tex2Dlod(_RayTracing_TopDownBuffer, float4(i.topdownUv //- i.normal.xz * gyr * _RayTracing_TopDownBuffer_Position.w
				 , 0, 0));
			 float topDownVisible = smoothstep(5, 0, abs(_RayTracing_TopDownBuffer_Position.y - i.worldPos.y));
			 topDown *= topDownVisible;

			 float ambientBlock = max(0.25f, 1 - topDown.a * 0.25);
			 bake.rgb *= ambientBlock;
			 bake.rgb += topDown.rgb * (0.2 + visibility * visibility / (i.pop * gyr * 0.5 + 0.5)); //5 * smoothstep(0.2,0, i.pop * gyr * 0.5));//(1 /(i.pop * gyr*0.5 + 0.1));

			 bake = lerp(bake, _RayMarchSkyColor * 0.4 + (unity_FogColor) * 0.1, outOfBounds);

			 float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
			 float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
			 float partZ = i.screenPos.z;
			 float fade = smoothstep(0,1, _InvFade * (1+gyr) * (sceneZ - partZ)) ;

			 float toCamera = length(_WorldSpaceCameraPos - i.worldPos.xyz) - _ProjectionParams.y;

			 bake.a =   
				 fade 
				 * saturate((toCamera ) * 0.4) 
				 * smoothstep(0, 1, dott) 
				 * visibility
				 * 0.5
				 ;

			// bake.rgb *= vColor.rgb;

			 ApplyBottomFog(bake.rgb, i.worldPos.xyz, i.viewDir.y);

			 return bake;

		   }
		   ENDCG
		 }
	   }

   }
}
