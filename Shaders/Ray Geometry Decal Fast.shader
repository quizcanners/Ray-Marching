Shader "RayTracing/Geometry/Decal Fast"
{
	Properties
	{
		[NoScaleOffset] _MainTex("Texture", 2D) = "white" {}
		//[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_Map("Bump/Combined Map (or None)", 2D) = "gray" {}
		 _InvFade("Soft Particles Factor", Range(0.01,3.0)) = 1.0

			  _ParallaxMedium ("Parallax Medium", Range(0.3,0.95)) = 0.8
	}

	SubShader{
		Tags
		{ 
			"Queue" = "Geometry+10"
			"RenderType" = "Opaque" 
			 "IgnoreProjector" = "True"
		}

		Blend SrcAlpha OneMinusSrcAlpha


		Pass{
		
			CGPROGRAM

			#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			//#pragma shader_feature_local  _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED

			sampler2D _MainTex;
			sampler2D _Map;
			float _ParallaxMedium;

			sampler2D _CameraDepthTexture;
			float _InvFade;
			

			struct v2f {
				float4 position : SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float3 viewDir		: TEXCOORD2;
				float2 texcoord		: TEXCOORD3;
				//SHADOW_COORDS(4)
				float3 normal		: TEXCOORD5;
				//float3 tangentViewDir : TEXCOORD6; // 5 or whichever is free
			};

			//the vertex shader function
			v2f vert(appdata_full v) {
				v2f o;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.position = UnityWorldToClipPos(o.worldPos);
				o.screenPos = ComputeScreenPos(o.position);
				
				COMPUTE_EYEDEPTH(o.screenPos.z);
				o.viewDir = WorldSpaceViewDir(v.vertex);
				o.texcoord = v.texcoord;
				o.normal.xyz = UnityObjectToWorldNormal(v.normal);
			
				UNITY_SETUP_INSTANCE_ID(v);

				//TRANSFER_SHADOW(o);

			/*	float3x3 objectToTangent = float3x3(
					v.tangent.xyz,
					cross(v.normal, v.tangent.xyz) * v.tangent.w,
					v.normal
					);
					*/


				//o.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex));
				return o;
			}

			

			fixed4 frag(v2f i) : SV_TARGET
			{
				i.viewDir.xyz = normalize(i.viewDir.xyz);

				float2 screenUv = i.screenPos.xy / i.screenPos.w;

				//i.tangentViewDir = normalize(i.tangentViewDir);
				//i.tangentViewDir.xy /= (i.tangentViewDir.z + 0.42);
				// or ..... /= (abs(o.tangentViewDir.z) + 0.42); to work on both sides of a plane
			
			

				float2 uv = i.texcoord.xy;

				float4 bumpMap = tex2D(_Map, uv);

				float diff = bumpMap.a - _ParallaxMedium;

				//uv += i.tangentViewDir.xy * diff * abs(diff) * 0.5;
				bumpMap = tex2D(_Map, uv);

				bumpMap.rg = (bumpMap.rg - 0.5) * 2;
				float ambient = bumpMap.a;
				float smoothness = bumpMap.b;

				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUv);
				float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
				float partZ = i.screenPos.z;
				float fade = smoothstep(0, _InvFade, (sceneZ - partZ - (1 - ambient) * 2));

				float4 col = tex2D(_MainTex, uv);
				col.a = 1;


				float3 textureNormal = float3(bumpMap.r, 0.1, bumpMap.g); // Conversion is incorrect when scale is not (1,1,1)

				float3 normal = normalize(i.normal.xyz + textureNormal);

				float shadow = 1;//SHADOW_ATTENUATION(i);

				float outOfBounds;
				float4 vol = SampleVolume(i.worldPos.xyz + normal * (smoothness + 0.5) * 0.5 * _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w, outOfBounds);
				float insideBounds = smoothstep(0.5, 0, outOfBounds);
				float fogged = 1 - insideBounds;

				float direct = saturate((dot(normal, _WorldSpaceLightPos0.xyz)));

				direct = saturate(direct * shadow - (1 - ambient) * (1 - direct));

				float3 ambientCol = lerp(GetAvarageAmbient(normal), vol, insideBounds);

				float3 lightColor = GetDirectional() * direct;

				float3 lcol = (lightColor + ambientCol);

				col.rgb *= lcol;

				float3 halfDirection = normalize(i.viewDir.xyz + _WorldSpaceLightPos0.xyz);
				float NdotH = max(0.01, (dot(normal, halfDirection)));
				float power = smoothness * 12;
				float normTerm = pow(NdotH, power) * power;

				//return normTerm;

				col.rgb += normTerm * lightColor * MATCH_RAY_TRACED_SUN_LIGH_GLOSS;


				col.a *= fade;
				
				
				
				return col;
			}

			ENDCG
		}
		//UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
	}
}