// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "RayTracing/Geometry/Decal"
{
	Properties
	{
		[NoScaleOffset] _MainTex("Texture", 2D) = "white" {}
		//[KeywordEnum(None, Regular, Combined)] _BUMP("Combined Map", Float) = 0
		_Map("Bump/Combined Map (or None)", 2D) = "gray" {}
	}

	SubShader{
		Tags
		{ 
			"Queue" = "Geometry+400"
			"RenderType" = "Opaque" 
			"DisableBatching" = "True"
			"LightMode" = "ForwardBase"
		}

		Blend SrcAlpha OneMinusSrcAlpha
		ZWrite off
		ZTest off

		Pass{
			Tags {"LightMode" = "ForwardBase"}
			CGPROGRAM

			#include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			//#pragma shader_feature_local  _BUMP_NONE  _BUMP_REGULAR _BUMP_COMBINED

			sampler2D _MainTex;
			sampler2D _Map;

			sampler2D_float _CameraDepthTexture;

			struct appdata {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct v2f {
				float4 pos: SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float3 viewDir		: TEXCOORD2;
				SHADOW_COORDS(3)
				float3 normal	: TEXCOORD4;
			};

			//the vertex shader function
			v2f vert(appdata v) {
				v2f o;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.pos = UnityWorldToClipPos(o.worldPos);
				o.screenPos = ComputeScreenPos(o.pos);
				o.viewDir = WorldSpaceViewDir(v.vertex);
				o.normal = UnityObjectToWorldNormal(v.normal);

				COMPUTE_EYEDEPTH(o.screenPos.z);
				TRANSFER_SHADOW(o);
				UNITY_SETUP_INSTANCE_ID(v);
				return o;
			}


			fixed4 frag(v2f i) : SV_TARGET
			{
				i.viewDir.xyz = normalize(i.viewDir.xyz);

				float2 screenUv = i.screenPos.xy / i.screenPos.w;

				float3 ray = i.worldPos - _WorldSpaceCameraPos;

				float distanceToProjector = length(ray);

				ray = normalize(ray);

				float orthoToPresp = dot(ray, -UNITY_MATRIX_V[2].xyz);

				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUv);

				//float ch = fwidth(depth);
			//	float fadeMe = smoothstep(0.001, 0.002, ch);

				depth = Linear01Depth(depth) * _ProjectionParams.z / orthoToPresp;
		
				float3 projectedPos = _WorldSpaceCameraPos + ray * depth;
				float3 cubeSpace = mul(unity_WorldToObject, float4(projectedPos, 1)).xyz;

				//float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
				//float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
				//float partZ = i.screenPos.z;
				//float fade = saturate(_InvFade * (1 + gyr) * (sceneZ - partZ));
				//float shadowMatch = saturate((depth - distanceToProjector)*1000);

				float2 uv = cubeSpace.xz + 0.5;
			
				float4 bumpMap = tex2D(_Map, uv);
				bumpMap.rg = (bumpMap.rg - 0.5) * 2;
				float ambient = bumpMap.a;
				float smoothness = bumpMap.b;

				float4 col = tex2D(_MainTex, uv);

				cubeSpace.y *= 0.5;  // Weird hack to allow the geometry to provide shadow
				cubeSpace.xz *= 1.5;
				float3 cut = max(0, 0.5 - abs(cubeSpace));
				float alpha = smoothstep(0.001, 0.0011 + ambient *0.01, cut.x * cut.y * cut.z);

				

				float3 textureNormal = mul(float3(bumpMap.r, 0.1, bumpMap.g), unity_WorldToObject); // Conversion is incorrect when scale is not (1,1,1)

				float3 normal = i.normal;//normalize(cross(ddy(projectedPos), ddx(projectedPos)));

				float3 normalInObject = mul(unity_WorldToObject, normal); //mul(unity_WorldToObject, normal);

				//float edge = 1; // dot(normalInObject, float3(0, 1, 0));
				

				//return edge;//float4 ((normalInObject + 1)*0.5, 1);

				normal = normalize(normal + textureNormal * 2);

				// Fade when normal mismatches projection

				float shadow =// lerp(1,
					SHADOW_ATTENUATION(i)
					//, shadowMatch)
					;

				float outOfBounds;
				float4 vol = SampleVolume(projectedPos + normal * (smoothness + 0.5) * 0.5 * _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w, outOfBounds);
				float gotVolume = smoothstep(0.5, 0, outOfBounds);
				float fogged = 1 - gotVolume;

				float direct = saturate((dot(normal, _WorldSpaceLightPos0.xyz)));

				//return direct;

				direct = saturate(direct * shadow - (1 - ambient) * (1 - direct));

				float3 ambientCol = lerp(GetAvarageAmbient(normal), vol, gotVolume);

				float3 lightColor =  GetDirectional() 
					* direct;

				//return float4(lightColor,1 );

				float3 lcol = (lightColor + ambientCol);// *deSmoothness;

				col.rgb *= lcol;

				float3 halfDirection = normalize(i.viewDir.xyz + _WorldSpaceLightPos0.xyz);
				float NdotH = max(0.01, (dot(normal, halfDirection)));
				float power = smoothness * 12;
				float normTerm = pow(NdotH, power) * power;

				//return normTerm;

				col.rgb += normTerm * lightColor * MATCH_RAY_TRACED_SUN_LIGH_GLOSS;


				ApplyBottomFog(col.rgb, i.worldPos.xyz, i.viewDir.y);

				col.a = alpha;// *(1 - fadeMe);
				
				return col;
			}

			ENDCG
		}
		//UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
	}
}