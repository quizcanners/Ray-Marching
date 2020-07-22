Shader "RayTracing/Geometry/Skinned GPU Instanced"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}



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

            #include "Assets/Ray-Marching/Shaders/PrimitivesScene_Sampler.cginc"
            #include "Assets/Ray-Marching/Shaders/Signed_Distance_Functions.cginc"
            #include "Assets/Ray-Marching/Shaders/RayMarching_Forward_Integration.cginc"
            #include "Assets/Ray-Marching/Shaders/Sampler_TopDownLight.cginc"

                #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdInclude.cginc"
                #pragma shader_feature_vertex GPUI_CA_TEXTURE
                #pragma multi_compile _ GPUI_CA_BINDPOSEOFFSET
                #pragma target 3.0

            // -------------------------------------

            #pragma shader_feature _NORMALMAP
          

            #pragma multi_compile_fwdbase
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:setupGPUI
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex  vert//vertBaseGPUI
            //#pragma fragment fragBaseAllGPUI
            #pragma fragment frag

            #include "UnityStandardCoreForward.cginc"
            #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdStandardInclude.cginc"

                struct v2f {
                    float4 pos			: SV_POSITION;
                    float4 tex          : TEXCOORD0;
                    float2 texcoord		: TEXCOORD1;
                    float3 worldPos		: TEXCOORD2;
                    float3 normal	: TEXCOORD3;
                    float3 viewDir		: TEXCOORD4;
                    float2 topdownUv : TEXCOORD5;
                    SHADOW_COORDS(6)
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
              //  half3 eyeVec = normalize(posWorld.xyz - _WorldSpaceCameraPos);
                o.normal.xyz = UnityObjectToWorldNormal(v.normal);
                TRANSFER_TOP_DOWN(o);
              //  o.normalWorld.xyz = normalWorld;
            //    o.eyeVec.xyz = eyeVec;

                TRANSFER_SHADOW(o);


                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            float4 frag(v2f i) : COLOR
            {
                float3 viewDir = normalize(i.viewDir.xyz);

                float gotVolume;
                float4 bake = SampleVolume(i.worldPos, gotVolume);



                float shadow = SHADOW_ATTENUATION(i) * SampleSkyShadow(i.worldPos);
                float direct = shadow * smoothstep(0, 1, dot(i.normal.xyz, _WorldSpaceLightPos0.xyz));
                float3 lightColor = GetDirectional() * direct;

                ApplyTopDownLightAndShadow(i.topdownUv, i.normal.xyz, i.worldPos, gotVolume, bake);

             //   return bake;

                float3 col = lightColor
                    + 
                    bake.rgb;

                float3 tex = tex2D(_MainTex, i.texcoord.xy).rgb;

                ColorCorrect(tex);
                col.rgb *= tex;

                ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

                return  float4(col, 1);
            }

            ENDCG
        }
            // ------------------------------------------------------------------
            //  Additive forward pass (one light per pass)

            Pass
            {
                Name "FORWARD_DELTA"
                Tags { "LightMode" = "ForwardAdd" }
                Blend[_SrcBlend] One
                Fog { Color(0,0,0,0) } // in additive pass fog should be black
                ZWrite Off
                ZTest LEqual

                CGPROGRAM
                #include "UnityCG.cginc"
                #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdInclude.cginc"
                #pragma shader_feature_vertex GPUI_CA_TEXTURE
                #pragma multi_compile _ GPUI_CA_BINDPOSEOFFSET
                #pragma target 3.0

            // -------------------------------------
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature _PARALLAXMAP

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:setupGPUI
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertAddGPUI
            #pragma fragment fragAdd
            //#pragma fragment fragAddAllGPUI

            #include "UnityStandardCoreForward.cginc"
            #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdStandardInclude.cginc"

            ENDCG
        }

            // ------------------------------------------------------------------
            //  Shadow rendering pass

            Pass {
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
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature _PARALLAXMAP
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

            // ------------------------------------------------------------------
            //  Deferred pass
            Pass
            {
                Name "DEFERRED"
                Tags { "LightMode" = "Deferred" }

                CGPROGRAM
                #include "UnityCG.cginc"
                #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdInclude.cginc"
                #pragma shader_feature_vertex GPUI_CA_TEXTURE
                #pragma multi_compile _ GPUI_CA_BINDPOSEOFFSET
                #pragma target 3.0
                #pragma exclude_renderers nomrt


            // -------------------------------------

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature _PARALLAXMAP

            #pragma multi_compile_prepassfinal
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:setupGPUI
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertDeferredGPUI
            #pragma fragment fragDeferredGPUI

            #include "UnityStandardCore.cginc"
            #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdStandardInclude.cginc"

            ENDCG
        }

            // ------------------------------------------------------------------
            // Extracts information for lightmapping, GI (emission, albedo, ...)
            // This pass it not used during regular rendering.
            Pass
            {
                Name "META"
                Tags { "LightMode" = "Meta" }

                Cull Off

                CGPROGRAM
                #include "UnityCG.cginc"
                #include "Assets\GPUInstancer-CrowdAnimations\Shaders\Include\GPUICrowdInclude.cginc"
                #pragma shader_feature_vertex GPUI_CA_TEXTURE
                #pragma multi_compile _ GPUI_CA_BINDPOSEOFFSET
                #pragma vertex vert_meta
                #pragma fragment frag_meta

                #pragma shader_feature _EMISSION
                #pragma shader_feature _METALLICGLOSSMAP
                #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #pragma shader_feature ___ _DETAIL_MULX2
                #pragma shader_feature EDITOR_VISUALIZATION
                #pragma multi_compile_instancing
                #pragma instancing_options procedural:setupGPUI

                #include "UnityStandardMeta.cginc"
                ENDCG
            }
        }


            FallBack "GPUInstancer/VertexLit"
         //   CustomEditor "StandardShaderGUI"
}
