Shader "QcRendering/Terrain/Unity Standard" {
    Properties 
    {
        [HideInInspector] _MainTex ("BaseMap (RGB)", 2D) = "white" {}
        [HideInInspector] _Color ("Main Color", Color) = (1,1,1,1)
        [HideInInspector] _TerrainHolesTexture("Holes Map (RGB)", 2D) = "white" {}
    }

    SubShader {
        Tags {
            "Queue" = "Geometry-100"
            "RenderType" = "Opaque"
            "TerrainCompatible" = "True"
        }

        CGPROGRAM
        #pragma surface surf Standard vertex:SplatmapVertQc finalcolor:SplatmapFinalColorQc finalgbuffer:SplatmapFinalGBufferQc addshadow fullforwardshadows
        #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap forwardadd
        #pragma target 3.0
        #include "UnityPBSLighting.cginc"

        #pragma multi_compile_local __ _NORMALMAP

        #define TERRAIN_INSTANCED_PERPIXEL_NORMAL
        #define TERRAIN_SURFACE_OUTPUT SurfaceOutputStandard
        #include "TerrainSplatmapCommon.cginc"

        struct InputQc 
        {
             float4 tc;
        };
        

void SplatmapMixQc(InputQc IN, half4 defaultAlpha, out half4 splat_control, out half weight, out fixed4 mixedDiffuse, inout fixed3 mixedNormal)

{

    // adjust splatUVs so the edges of the terrain tile lie on pixel centers
    float2 splatUV = (IN.tc.xy * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
    splat_control = tex2D(_Control, splatUV);
    weight = dot(splat_control, half4(1,1,1,1));

    #if !defined(SHADER_API_MOBILE) && defined(TERRAIN_SPLAT_ADDPASS)
        clip(weight == 0.0f ? -1 : 1);
    #endif

    // Normalize weights before lighting and restore weights in final modifier functions so that the overal
    // lighting result can be correctly weighted.
    splat_control /= (weight + 1e-3f);

    float2 uvSplat0 = TRANSFORM_TEX(IN.tc.xy, _Splat0);
    float2 uvSplat1 = TRANSFORM_TEX(IN.tc.xy, _Splat1);
    float2 uvSplat2 = TRANSFORM_TEX(IN.tc.xy, _Splat2);
    float2 uvSplat3 = TRANSFORM_TEX(IN.tc.xy, _Splat3);

    mixedDiffuse = 0.0f;
        mixedDiffuse += splat_control.r * tex2D(_Splat0, uvSplat0) * half4(1.0, 1.0, 1.0, defaultAlpha.r);
        mixedDiffuse += splat_control.g * tex2D(_Splat1, uvSplat1) * half4(1.0, 1.0, 1.0, defaultAlpha.g);
        mixedDiffuse += splat_control.b * tex2D(_Splat2, uvSplat2) * half4(1.0, 1.0, 1.0, defaultAlpha.b);
        mixedDiffuse += splat_control.a * tex2D(_Splat3, uvSplat3) * half4(1.0, 1.0, 1.0, defaultAlpha.a);


    #ifdef _NORMALMAP
        mixedNormal  = UnpackNormalWithScale(tex2D(_Normal0, uvSplat0), _NormalScale0) * splat_control.r;
        mixedNormal += UnpackNormalWithScale(tex2D(_Normal1, uvSplat1), _NormalScale1) * splat_control.g;
        mixedNormal += UnpackNormalWithScale(tex2D(_Normal2, uvSplat2), _NormalScale2) * splat_control.b;
        mixedNormal += UnpackNormalWithScale(tex2D(_Normal3, uvSplat3), _NormalScale3) * splat_control.a;
#if defined(SHADER_API_SWITCH)
        mixedNormal.z += UNITY_HALF_MIN; // to avoid nan after normalizing
#else
        mixedNormal.z += 1e-5f; // to avoid nan after normalizing
#endif
    #endif

    #if defined(INSTANCING_ON) && defined(SHADER_TARGET_SURFACE_ANALYSIS) && defined(TERRAIN_INSTANCED_PERPIXEL_NORMAL)
        mixedNormal = float3(0, 0, 1); // make sure that surface shader compiler realizes we write to normal, as UNITY_INSTANCING_ENABLED is not defined for SHADER_TARGET_SURFACE_ANALYSIS.
    #endif

    #if defined(UNITY_INSTANCING_ENABLED) && !defined(SHADER_API_D3D11_9X) && defined(TERRAIN_INSTANCED_PERPIXEL_NORMAL)

        #if defined(TERRAIN_USE_SEPARATE_VERTEX_SAMPLER)
            float3 geomNormal = normalize(_TerrainNormalmapTexture.Sample(sampler__TerrainNormalmapTexture, IN.tc.zw).xyz * 2 - 1);
        #else
            float3 geomNormal = normalize(tex2D(_TerrainNormalmapTexture, IN.tc.zw).xyz * 2 - 1);
        #endif

        #ifdef _NORMALMAP
            float3 geomTangent = normalize(cross(geomNormal, float3(0, 0, 1)));
            float3 geomBitangent = normalize(cross(geomTangent, geomNormal));
            mixedNormal = mixedNormal.x * geomTangent
                          + mixedNormal.y * geomBitangent
                          + mixedNormal.z * geomNormal;
        #else
            mixedNormal = geomNormal;
        #endif
        mixedNormal = mixedNormal.xzy;
    #endif
}

        void SplatmapVertQc(inout appdata_full v, out InputQc data)
        {
           //UNITY_INITIALIZE_OUTPUT(InputQc, data);

           data.tc = 0;

            #if defined(UNITY_INSTANCING_ENABLED) && !defined(SHADER_API_D3D11_9X)

                float2 patchVertex = v.vertex.xy;
                float4 instanceData = UNITY_ACCESS_INSTANCED_PROP(Terrain, _TerrainPatchInstanceData);

                float4 uvscale = instanceData.z * _TerrainHeightmapRecipSize;
                float4 uvoffset = instanceData.xyxy * uvscale;
                uvoffset.xy += 0.5f * _TerrainHeightmapRecipSize.xy;
                float2 sampleCoords = (patchVertex.xy * uvscale.xy + uvoffset.xy);

                #if defined(TERRAIN_USE_SEPARATE_VERTEX_SAMPLER)
                    float hm = UnpackHeightmap(_TerrainHeightmapTexture.SampleLevel(vertex_linear_clamp_sampler, sampleCoords, 0));
                #else
                    float hm = UnpackHeightmap(tex2Dlod(_TerrainHeightmapTexture, float4(sampleCoords, 0, 0)));
                #endif

                v.vertex.xz = (patchVertex.xy + instanceData.xy) * _TerrainHeightmapScale.xz * instanceData.z;  //(x + xBase) * hmScale.x * skipScale;
                v.vertex.y = hm * _TerrainHeightmapScale.y;
                v.vertex.w = 1.0f;

                v.texcoord.xy = (patchVertex.xy * uvscale.zw + uvoffset.zw);
                v.texcoord3 = v.texcoord2 = v.texcoord1 = v.texcoord;

                #ifdef TERRAIN_INSTANCED_PERPIXEL_NORMAL
                    v.normal = float3(0, 1, 0); // TODO: reconstruct the tangent space in the pixel shader. Seems to be hard with surface shader especially when other attributes are packed together with tSpace.
                    data.tc.zw = sampleCoords;
                #else
                    #if defined(TERRAIN_USE_SEPARATE_VERTEX_SAMPLER)
                        float3 nor = _TerrainNormalmapTexture.SampleLevel(vertex_linear_clamp_sampler, sampleCoords, 0).xyz;
                    #else
                        float3 nor = tex2Dlod(_TerrainNormalmapTexture, float4(sampleCoords, 0, 0)).xyz;
                    #endif
                    v.normal = 2.0f * nor - 1.0f;
                #endif
            #endif

                v.tangent.xyz = cross(v.normal, float3(0,0,1));
                v.tangent.w = -1;

                data.tc.xy = v.texcoord.xy;
                #ifdef UNITY_PASS_META
                    data.tc.xy = TRANSFORM_TEX(v.texcoord.xy, _MainTex);
                #endif


           // float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
           // data.worldPos = worldPos;
         //   data.viewDir = WorldSpaceViewDir(v.vertex);
        }

        half _Metallic0;
        half _Metallic1;
        half _Metallic2;
        half _Metallic3;

        half _Smoothness0;
        half _Smoothness1;
        half _Smoothness2;
        half _Smoothness3;


        void SplatmapFinalGBufferQc(InputQc IN, TERRAIN_SURFACE_OUTPUT o, inout half4 outGBuffer0, inout half4 outGBuffer1, inout half4 outGBuffer2, inout half4 emission)
        {
            UnityStandardDataApplyWeightToGbuffer(outGBuffer0, outGBuffer1, outGBuffer2, o.Alpha);
            emission *= o.Alpha;
        }


        void SplatmapFinalColorQc(InputQc IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 color)
        {
            color *= o.Alpha;
            
            #ifdef TERRAIN_SPLAT_ADDPASS
                UNITY_APPLY_FOG_COLOR(IN.fogCoord, color, fixed4(0,0,0,0));
            #else
                UNITY_APPLY_FOG(IN.fogCoord, color);
            #endif
        }

        void surf (InputQc IN, inout SurfaceOutputStandard o) {
            half4 splat_control;
            half weight;
            fixed4 mixedDiffuse;
            half4 defaultSmoothness = half4(_Smoothness0, _Smoothness1, _Smoothness2, _Smoothness3);
            SplatmapMixQc(IN, defaultSmoothness, splat_control, weight, mixedDiffuse, o.Normal);
            o.Albedo = mixedDiffuse.rgb;

           // ApplyBottomFog(o.Albedo, i.worldPos.xyz, viewDir.y);


            o.Alpha = weight;
            o.Smoothness = mixedDiffuse.a;
            o.Metallic = dot(splat_control, half4(_Metallic0, _Metallic1, _Metallic2, _Metallic3));
        }
        ENDCG

        UsePass "Hidden/Nature/Terrain/Utilities/PICKING"
        UsePass "Hidden/Nature/Terrain/Utilities/SELECTION"
    }

    Dependency "AddPassShader"    = "Hidden/TerrainEngine/Splatmap/Standard-AddPass"
    Dependency "BaseMapShader"    = "Hidden/TerrainEngine/Splatmap/Standard-Base"
    Dependency "BaseMapGenShader" = "Hidden/TerrainEngine/Splatmap/Standard-BaseGen"

    Fallback "Nature/Terrain/Diffuse"
}