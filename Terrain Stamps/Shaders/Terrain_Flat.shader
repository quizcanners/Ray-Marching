Shader "QcRendering/Terrain/Flat"
{
    Properties
    {
       
    }
    SubShader
    {
        Tags 
        { 
           "RenderType"="Geometry" 
            "Queue" = "Geometry+10"
        }
        LOD 100

        CGINCLUDE
        #pragma multi_compile_instancing
        #include "Qc_TerrainCommon.cginc"

        ENDCG

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fwdbase
			#pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

            #pragma multi_compile ___ _qc_USE_RAIN 
			#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
			#pragma multi_compile ___ _qc_IGNORE_SKY 

            #include "UnityCG.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"

            struct v2f
            {
                float4 pos			: SV_POSITION;
                float3 worldPos : 	TEXCOORD1;
                float3 viewDir : TEXCOORD2;
                float4 screenPos :		TEXCOORD3;
                SHADOW_COORDS(4)
            };

            v2f vert (appdata_full v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                o.pos = UnityObjectToClipPos(v.vertex);
                float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
                o.worldPos = worldPos;
                TRANSFER_SHADOW(o);
                o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
                o.screenPos = ComputeScreenPos(o.pos);
                return o;
            }

            sampler2D _BumpMap;
            sampler2D _AmbientMap;
            float _BlendHeight;
            float _BlendSharpness;


            	struct FragColDepth
				{
					float4 col: SV_Target;
					float depth : SV_Depth;
				};
            FragColDepth frag(v2f i)
            //fixed4 frag (v2f i) : SV_Target
            {
              float3 viewDir = normalize(i.viewDir.xyz);
            
              float2 screenUv = i.screenPos.xy / i.screenPos.w;

              float3 rawNormal;
              float4 control = Ct_SampleTerrainAndNormal(i.worldPos, rawNormal);

            //  return float4(rawNormal,1);

                float rawFresnel = saturate(1- dot(viewDir, rawNormal));

              float height;
              GetTerrainHeight(control, height);

           

                float4 madsMap;
                float3 normal;
                float3 tex;
                GetTerrainBlend(i.worldPos, control, rawNormal , normal, tex, madsMap);

                //return float4(tex,1);

                float shadow = SHADOW_ATTENUATION(i);

              //  i.worldPos.y = height;

                float displacement = madsMap.b;

                float4 illumination;

			    float ao = SampleSS_Illumination( screenUv, illumination);

			    shadow *= saturate(1-illumination.b);

                ao *= madsMap.g + (1-madsMap.g) * rawFresnel;


          //  return float4(rawNormal, 1);
               // ao = 1;

                float metal = madsMap.r;
				float fresnel = GetFresnel_FixNormal(normal, rawNormal, viewDir);//GetFresnel(normal, viewDir) * ao;

				MaterialParameters precomp;
					
				precomp.shadow = shadow;
				precomp.ao = ao;
				precomp.fresnel = fresnel;
				precomp.tex = tex;
				
				precomp.reflectivity = 0.5;
				precomp.metal = metal;
				precomp.traced = 0;
				precomp.water = 0;
				precomp.smoothsness = madsMap.a;

				precomp.microdetail = 0.5;
				precomp.metalColor = 0; //lerp(tex, _MetalColor, _MetalColor.a);

				precomp.microdetail.a = 0;
			
				float3 col = GetReflection_ByMaterialType(precomp, normal, rawNormal, viewDir, i.worldPos);


				ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

                float offsetAmount = (1 + rawFresnel * rawFresnel * 4);


                	FragColDepth result;
					result.depth = calculateFragmentDepth(i.worldPos + (displacement - 0.5) * viewDir * offsetAmount  * 0.1); // * _HeightOffset);
					result.col =  float4(col, 1);

					return result;

                // return float4(col,1);
            }



            ENDCG
        }



         UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

    }
}
