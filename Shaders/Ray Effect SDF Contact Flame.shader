Shader "RayTracing/Effect/Contact Flame"
{
	Properties{
	   _MainTex("Particle Texture", 2D) = "white" {}
	   _InvFade("Soft Particles Factor", Range(0.01,3.0)) = 1.0
		   _Color("Color", Color) = (1,1,1,1)
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
		   #pragma multi_compile_fwdbase
		   #pragma multi_compile_instancing

		   #include "Assets/Ray-Marching/Shaders/PrimitivesScene.cginc"

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
			 float3 normal	: TEXCOORD2;
			 float3 viewDir	: TEXCOORD3;
			 float3 worldPos : TEXCOORD4;
		   };

		   sampler2D _MainTex;
		   float4 _MainTex_ST;
		   float4 _Color;

		   v2f vert(appdata_full v)
		   {
			 v2f o;
			 UNITY_SETUP_INSTANCE_ID(v);
			 o.pos = UnityObjectToClipPos(v.vertex);

			 //o.projPos = ComputeScreenPos(o.pos);
			 o.screenPos = ComputeScreenPos(o.pos);
			 COMPUTE_EYEDEPTH(o.screenPos.z);

			 o.color = v.color;
			 o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
			
			 o.normal = UnityObjectToWorldNormal(v.normal);
			 //o.ViewT = normalize(ObjSpaceViewDir(v.vertex));
			 //o.VL = ShadeVertexLights(v.vertex, dot(o.normal,o.ViewT));
			 o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
			 o.worldPos = mul(unity_ObjectToWorld, v.vertex);
			 UNITY_SETUP_INSTANCE_ID(v);

			 //TRANSFER_SHADOW(o);
			 return o;
		   }

		   sampler2D _CameraDepthTexture;
		   float _InvFade;

		   fixed4 frag(v2f i) : COLOR
		   {
				float2 screenUV = i.screenPos.xy / i.screenPos.w;

				i.viewDir.xyz = normalize(i.viewDir.xyz);

				float dott = abs(dot(i.viewDir.xyz, i.normal.xyz));

				float VOL_SIZE = _RayMarchingVolumeVOLUME_POSITION_OFFSET.w;

				float4 normalAndDist = SdfNormalAndDistance(i.worldPos + VOL_SIZE);

				float dist = normalAndDist.a;

				float proximity = saturate(normalAndDist.w * VOL_SIZE);

				float3 normOffset = normalAndDist.xyz * VOL_SIZE * 2  / (1+normalAndDist.w);


				float2 uv1 = tex2D(_MainTex, float2( i.worldPos.x, dist - _Time.y));
				float2 uv2 = tex2D(_MainTex, float2(dist - _Time.y, i.worldPos.y));


				float4 col =
					tex2D(_MainTex, uv1)
					//* tex2D(_MainTex, uv2)
					* _Color
					;


				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
				float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
				float partZ = i.screenPos.z;
				float fromDepthDist = _InvFade * (sceneZ - partZ);
				float fade = smoothstep(0, 0.75 + col.a, fromDepthDist);

				float toCamera = length(_WorldSpaceCameraPos - i.worldPos.xyz);
				float contact = smoothstep(2, 1, normalAndDist.a);

				contact = max(contact, 1 - fromDepthDist);


				float2 off = abs(i.texcoord - 0.5);

				float edges = smoothstep(0.5, 0.3, off.x) * smoothstep(0.5, 0.3, off.y);

			
				//return dott * dott;


				col.a *= edges 
					//* contact 
					//* proximity 
					* fade
					* smoothstep(0,1,(toCamera - _ProjectionParams.y) * 0.4)
					* smoothstep(0, 1, pow(dott,3));

				return col;

		   }
		   ENDCG
		 }
	   }

   }
}
