Shader "GPUInstancer/RayTracing/Effect/Smoke Billboard"
{
	Properties
	{
		_MainTex("Particle Texture", 2D) = "white" {}
		_MainTex2("Particle Texture 2", 2D) = "white" {}
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
			"RenderType" = "Transparent"
			"LightMode" = "ForwardBase"
		}

		SubShader 
		{

		
        	CGINCLUDE

				#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
				#pragma multi_compile __ _qc_IGNORE_SKY 
			 	#pragma multi_compile ___ qc_LAYARED_FOG
				#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Transparent.cginc"
			

				UNITY_INSTANCING_BUFFER_START(Props)
				UNITY_DEFINE_INSTANCED_PROP(float, _Heat)
				UNITY_DEFINE_INSTANCED_PROP(float, _Dissolve)
				UNITY_DEFINE_INSTANCED_PROP(float, _Seed)
				UNITY_INSTANCING_BUFFER_END(Props)


				sampler2D _MainTex;
				sampler2D _MainTex2;
				float4 _MainTex_ST;
				float4 _MainTex2_ST;

			float SampleAlpha(float2 uv, float dissolve, float seed )
			{
				float2 offUv = (uv - 0.5) ;
				float2 sphereUv = offUv * offUv; 

				float2 randomUv = offUv  * (1 - dissolve*0.75) + seed; 

				float texA = tex2D(_MainTex, Rotate(randomUv * _MainTex_ST.xy, seed * 4 + _Time.x)).r;
				float texB = tex2D(_MainTex2, Rotate(randomUv * _MainTex2_ST.xy, seed * 3.1 - _Time.x)).r;

				float offCenter = smoothstep(0, 0.25, sphereUv.x + sphereUv.y); 

				//float fullDissolve = smoothstep(1, 0.9, dissolve);

				float textureSoftening = lerp(texA * texB, 1, dissolve);

				return (1-dissolve) * smoothstep(dissolve*0.2, 0.1+dissolve, textureSoftening * (1- offCenter));
			}

			ENDCG

			Pass 
			{
				Blend SrcAlpha OneMinusSrcAlpha
				ColorMask RGBA
				Cull Off
				ZWrite Off
				ZTest Off

				CGPROGRAM
#include "UnityCG.cginc"
#include "./../../../GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
#pragma instancing_options procedural:setupGPUI
#pragma multi_compile_instancing

				#pragma vertex vert
				#pragma fragment frag
				//#pragma multi_compile_fwdbase
				//#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING
				

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
					fixed4 color : COLOR;
				
			   };



				float4 _Color;
				float _InvFade;


				v2f vert(appdata_full v)
				{
					 v2f o;

					 UNITY_SETUP_INSTANCE_ID(v);
					 UNITY_TRANSFER_INSTANCE_ID(v, o);
			 
			 		 o.vertex = GetBillboardPos(v.vertex,  o.worldPos);

					// o.worldPos = ClipToWorldPos(o.vertex);
					 
					 // mul(unity_ObjectToWorld , float4(v.vertex.xyz,1));
					 o.screenPos = ComputeScreenPos(o.vertex);
					 o.texcoord = v.texcoord;
					 o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
					 o.color = v.color * _Color;

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

				float2 offUv = (i.texcoord - 0.5) ;

				float tex =SampleAlpha(i.texcoord,  dissolve,  seed );// smoothstep(dissolve*0.2, 0.1+dissolve*0.41, lerp(texA * texB, (texA + texB)*0.5, dissolve) * (1- offCenter));

				i.viewDir.xyz = normalize(i.viewDir.xyz);

				float3 forNormal = -i.viewDir.xyz;
				forNormal.y = 0;
				forNormal = normalize(forNormal);

				float3 normal = (cross(float3(0, 1, 0), -forNormal) * offUv.x); // X component
				normal.y = offUv.y;
				normal = normalize(normal);

				float4 col = i.color;

				float2 screenUV = i.screenPos.xy / i.screenPos.w;

				float distToCamera;
				float fade = GetSoftParticleFade(screenUV, i.screenPos.z, i.worldPos.xyz, _InvFade, distToCamera);
			
				col.a = min(1, tex 	* fade);

				float shadow = GetShadowVolumetric(i.worldPos, i.screenPos.z, i.viewDir);

				float topShadow = smoothstep(0.3, 0.5 + tex*0.5, i.texcoord.y);
				
				shadow *= topShadow;
				
				col.rgb = TransparentLightStandard(col, i.worldPos, normal, i.viewDir, shadow);

				ApplyBottomFog(col.rgb, i.worldPos.xyz, i.viewDir.y);
				ApplyLayeredFog_Transparent(col, screenUV, distToCamera);
				 return col;

			   }
		   ENDCG
		 }

		   Pass 
			{
				Name "Caster"
				Tags 
				{ 
					"LightMode" = "ShadowCaster" 
				}

				Cull Off
				CGPROGRAM
#include "UnityCG.cginc"
#include "./../../../GPUInstancer/Shaders/Include/GPUInstancerInclude.cginc"
#pragma instancing_options procedural:setupGPUI
#pragma multi_compile_instancing
				#pragma vertex vert
				#pragma fragment frag
				#pragma target 2.0
				#pragma multi_compile_shadowcaster

				struct v2f 
				{
					V2F_SHADOW_CASTER;
                    float2 uv : TEXCOORD0;
					UNITY_VERTEX_OUTPUT_STEREO
				};


		
				v2f vert( appdata_full v )
				{
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
					TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
					o.uv = v.texcoord.xy;

					return o;
				}



				float4 frag( v2f i ) : SV_Target
				{
					float dissolve = UNITY_ACCESS_INSTANCED_PROP(Props, _Dissolve);
					float seed = UNITY_ACCESS_INSTANCED_PROP(Props, _Seed); 

				
			
					float col= SampleAlpha(i.uv, dissolve, seed);

					clip(col - 0.5);

					SHADOW_CASTER_FRAGMENT(i)
				}
				ENDCG
			}


	   }
   }
}
