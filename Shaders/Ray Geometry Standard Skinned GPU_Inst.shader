Shader "RayTracing/Geometry/Skinned GPU Instanced"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}

        _SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
        _BumpMap("Normal Map", 2D) = "bump" {}

        [KeywordEnum(MADS, None, Separate)] _AO("AO Source", Float) = 0
        _OcclusionMap("Ambient Map", 2D) = "white" {}

        [Toggle(_AMBIENT_IN_UV2)] ambInuv2("Ambient mapped to UV2", Float) = 0
        [Toggle(_COLOR_R_AMBIENT)] colAIsAmbient("Vert Col is Ambient", Float) = 0


        [Toggle(_SUB_SURFACE)] subSurfaceScattering("SubSurface Scattering", Float) = 0
        _SubSurface("Sub Surface Scattering", Color) = (1,0.5,0,0)
        _SkinMask("Skin Mask (_UV2)", 2D) = "white" {}

        _Overlay("Overlay (RGBA)", 2D) = "white" {}
		_OverlayTiling("Overlay Tiling", float) = 1

        // Blending state
        [HideInInspector] _Mode("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
    }

    CGINCLUDE
    #define UNITY_SETUP_BRDF_INPUT MetallicSetup



    ENDCG

    SubShader
    {
        Tags { "RenderType" = "GPUICA_Opaque" "PerformanceChecks" = "False" }
        LOD 300


        // ------------------------------------------------------------------
        //  Base forward pass (directional light, emission, lightmaps, ...)
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]

            CGPROGRAM
            //#include "UnityCG.cginc"

          //  #pragma multi_compile __ RT_FROM_CUBEMAP 
            #pragma multi_compile ___ _qc_USE_RAIN

            #pragma shader_feature_local ___ _AMBIENT_IN_UV2
            #pragma shader_feature_local _AO_MADS  _AO_NONE   _AO_SEPARATE
            #pragma shader_feature_local ___ _COLOR_R_AMBIENT


            #include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Debug.cginc"
            #include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"

            #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdInclude.cginc"
            #pragma shader_feature_vertex GPUI_CA_TEXTURE
            #pragma multi_compile _ GPUI_CA_BINDPOSEOFFSET
            #pragma target 3.0

            // -------------------------------------

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature_local ___ _SUB_SURFACE

            #pragma multi_compile_fwdbase
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:setupGPUI
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE
            

            #pragma vertex  vert//vertBaseGPUI
            //#pragma fragment fragBaseAllGPUI
            #pragma fragment frag

            #include "UnityStandardCoreForward.cginc"
            #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdStandardInclude.cginc"

            struct v2f 
            {
                float4 pos			: SV_POSITION;
                float4 tex          : TEXCOORD0;
                float2 texcoord		: TEXCOORD1;
                float3 worldPos		: TEXCOORD2;
                float3 normal	: TEXCOORD3;
                float3 viewDir		: TEXCOORD4;
                float4 wTangent		: TEXCOORD5;
                SHADOW_COORDS(6)
                    fixed4 color : COLOR;
            };

            v2f vert(appdata_full v)
            {
                UNITY_SETUP_INSTANCE_ID(v);
                GPUI_CROWD_VERTEX(v);
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.tex = TexCoordsGPUI(v);
                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.viewDir = WorldSpaceViewDir(v.vertex);
                o.normal.xyz = UnityObjectToWorldNormal(v.normal);
                o.color = v.color;

                TRANSFER_SHADOW(o);
                TRANSFER_WTANGENT(o);
               // UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            sampler2D _SkinMask;
            float4 _SubSurface;


          //  sampler2D _BumpMap;
            sampler2D _SpecularMap;

            /*
#if _AO_SEPARATE
            sampler2D _OcclusionMap;
#endif
*/
            float4 frag(v2f i) : COLOR
            {
                float3 viewDir = normalize(i.viewDir.xyz);
                float rawFresnel = smoothstep(1, 0, dot(viewDir, i.normal.xyz));

                float2 uv = i.texcoord.xy;

                float4 madsMap = tex2D(_SpecularMap, uv);
                float displacement = madsMap.b;

             
                float3 tnormal = UnpackNormal(tex2D(_BumpMap, uv));
                float3 normal = i.normal.xyz;


                float ao;

#if _AO_SEPARATE
#	if _AMBIENT_IN_UV2
                ao = tex2D(_OcclusionMap, o.texcoord1.xy).r;
#	else
                ao = tex2D(_OcclusionMap, uv).r;
#	endif
#elif _AO_MADS
                ao = madsMap.g;
#else 
                ao = 1;
#endif


#if _COLOR_R_AMBIENT
                ao *= (0.25 + o.color.r * 0.75);
#endif

                ApplyTangent(normal, tnormal, i.wTangent);

                // ********************** Contact Shadow

	//ao *=SampleContactAO(i.worldPos, normal);

                // ********************** WATER

                float water = 0;
                float shadow = SHADOW_ATTENUATION(i);
#if _qc_USE_RAIN || _DAMAGED

                float rain = GetRain(i.worldPos, normal, i.normal, shadow);

                float flattenWater = ApplyWater(water, rain, ao, displacement, madsMap, tnormal, i.worldPos, i.normal.y);

                normal = lerp(normal, i.normal.xyz, flattenWater);
               // normal = i.normal.xyz;
               // ApplyTangent(normal, tnormal, i.wTangent);
#endif

                // **************** light

    float3 worldPosAdjusted = i.worldPos;
	ao *= SampleContactAO_OffsetWorld(worldPosAdjusted, normal);



                float metal = madsMap.r;
                float fresnel = 1 - saturate(dot(normal, viewDir));
                float specular = GetSpecular(madsMap.a, fresnel, metal);

            

                float3 lightColor = Savage_GetDirectional_Opaque(shadow, ao, normal, i.worldPos);

                float3 volumeSamplePosition;
                float3 bake = Savage_GetVolumeBake(worldPosAdjusted, normal, i.normal, volumeSamplePosition);

                TOP_DOWN_SETUP_UV(topdownUv, i.worldPos);
                float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, normal, i.worldPos);
                ao *= topDownAmbient.a;
                bake.rgb += topDownAmbient.rgb;

                float4 tex = tex2D(_MainTex, i.texcoord.xy);

                ModifyColorByWetness(tex.rgb, water, madsMap.a);

                float3 reflectionColor = 0;
                float3 pointLight = GetPointLight(volumeSamplePosition, normal, ao, viewDir, specular, reflectionColor);


                float3 col = tex.rgb * (pointLight + lightColor + bake.rgb * ao);

                //return water float4(col, 1);

                // ***************** Reflection

#if RT_FROM_CUBEMAP || _SUB_SURFACE

                float3 reflectedRay = reflect(-viewDir, i.normal.xyz);


             

                float4 topDownAmbientSpec = SampleTopDown_Specular(topdownUv, reflectedRay, i.worldPos, i.normal.xyz, specular);
                ao *= topDownAmbientSpec.a;
                reflectionColor += topDownAmbientSpec.rgb;
                  reflectionColor *= ao;

                reflectionColor += GetBakedAndTracedReflection(volumeSamplePosition, reflectedRay, specular, ao);
              

                reflectionColor += GetDirectionalSpecular(normal, viewDir, specular * 0.9) * lightColor;

                MixInSpecular(col, reflectionColor, tex, metal, specular, fresnel);


#				if _SUB_SURFACE

                float4 skin = tex2D(_SkinMask, i.texcoord.xy) * _SubSurface;

                ApplySubSurface(col, skin, volumeSamplePosition, viewDir, specular, rawFresnel, shadow);


              /** float4 skin = tex2D(_SkinMask, i.texcoord.xy);
                float subSurface = _SubSurface.a * skin.a * (2 - rawFresnel) * 0.5;

                col *= 1 - subSurface;

                float4 forwardBake = GetBakedAndTracedReflection(volumeSamplePosition, -viewDir, specular);

                float sun = 1 / (0.1 + 1000 * smoothstep(1, 0, dot(_WorldSpaceLightPos0.xyz, -viewDir)));

                col.rgb += subSurface * skin.rgb * _SubSurface.rgb * (forwardBake.rgb + GetDirectional() * (1 + sun) * shadow);*/

#				endif

#endif


                ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

                return  float4(col, 1);
            }
        ENDCG
    }


      Pass
        {
            Name "FORWARD"
           Tags
			{
				"LightMode" = "ForwardBase"
				"Queue" = "Transparent"
				"PreviewType" = "Plane"
				"IgnoreProjector" = "True"
				"RenderType" = "Transparent"
			}

            ZWrite Off
            Cull Front
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM

           //	#pragma multi_compile __ RT_FROM_CUBEMAP 
           
            #include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Debug.cginc"
             #include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"

            #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdInclude.cginc"
            #pragma shader_feature_vertex GPUI_CA_TEXTURE
            #pragma multi_compile _ GPUI_CA_BINDPOSEOFFSET
            #pragma target 3.0

            // -------------------------------------

            #pragma multi_compile_fwdbase
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:setupGPUI
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE
            

            #pragma vertex  vert//vertBaseGPUI
            //#pragma fragment fragBaseAllGPUI
            #pragma fragment frag

            #include "UnityStandardCoreForward.cginc"
            #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdStandardInclude.cginc"


        


            struct v2f 
            {
                float4 pos			: SV_POSITION;
                float4 tex          : TEXCOORD0;
                float2 texcoord		: TEXCOORD1;
                float3 worldPos		: TEXCOORD2;
                float3 normal	: TEXCOORD3;
                float3 viewDir		: TEXCOORD4;
                float4 wTangent		: TEXCOORD5;
                SHADOW_COORDS(6)
                float4 screenPos : TEXCOORD7;
                    fixed4 color : COLOR;
            };

            v2f vert(appdata_full v)
            {
                UNITY_SETUP_INSTANCE_ID(v);
                GPUI_CROWD_VERTEX(v);
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                  o.normal.xyz = UnityObjectToWorldNormal(v.normal);

                o.worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

                float toCum = (0.5 + smoothstep(0,10, length(_WorldSpaceCameraPos - o.worldPos)))*0.04;

                v.vertex = mul(unity_WorldToObject, float4(o.worldPos + o.normal*toCum, v.vertex.w));

               // o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.tex = TexCoordsGPUI(v);
                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.viewDir = WorldSpaceViewDir(v.vertex);
              
              	o.screenPos = ComputeScreenPos(o.pos); 
					  COMPUTE_EYEDEPTH(o.screenPos.z);

                o.color = v.color;

                TRANSFER_SHADOW(o);
                TRANSFER_WTANGENT(o);
               // UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            sampler2D _SkinMask;
            sampler2D	_Overlay;
			float _OverlayTiling;



            float4 frag(v2f i) : COLOR
            {
            	i.normal = normalize(i.normal);

               	float4 col = tex2D(_Overlay, i.tex * _OverlayTiling);

				float3 viewDir = normalize(i.viewDir.xyz);
				float2 screenUV = i.screenPos.xy / i.screenPos.w;

				float3 normal = -viewDir;

                float3 bake = SampleVolume_CubeMap(i.worldPos, normal);

				TopDownSample(i.worldPos, bake);

               	bake.rgb += GetPointLight_Transpaent(i.worldPos, -viewDir);

                float3 shadowPos = i.worldPos;
                float shadow = SampleRayShadow(shadowPos); // * SampleSkyShadow(i.worldPos);

                col.rgb *= bake + shadow * GetDirectional() * 0.5;

				float fresnel =  smoothstep(0 ,1, dot(-viewDir, i.normal));
			
			    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
			    float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
			    float fade = smoothstep(2 ,3, (sceneZ - i.screenPos.z));
			
				ApplyBottomFog(col.rgb, i.worldPos.xyz, viewDir.y);

				col.a *= fresnel * fade;

				return col;
            }
        ENDCG
    }

        Pass 
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            CGPROGRAM
            #include "UnityCG.cginc"
            #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdInclude.cginc"
            #pragma shader_feature_vertex GPUI_CA_TEXTURE
            #pragma multi_compile _ GPUI_CA_BINDPOSEOFFSET
            #pragma target 3.0

            // -------------------------------------
          //  #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
          //  #pragma shader_feature _METALLICGLOSSMAP
          //  #pragma shader_feature _PARALLAXMAP
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:setupGPUI
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertShadowCasterGPUI
            #pragma fragment fragShadowCaster
            #include "UnityStandardShadow.cginc"
            #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdStandardShadowInclude.cginc"

            ENDCG
        }



    }

    FallBack "GPUInstancer/VertexLit"
        //   CustomEditor "StandardShaderGUI"
}
