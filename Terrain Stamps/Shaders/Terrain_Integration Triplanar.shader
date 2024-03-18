Shader "QcRendering/Terrain/Integration Triplanar"
{
    Properties
    {
        _BumpMapBig("Mesh Normal Map", 2D) = "bump" {}
        _MadsBig("MADS Big", 2D) = "bump" {}

        _BlendHeight("Blend Height", Range(0,100)) = 1
        _BlendSharpness("Blend Sharpness", Range(0,1)) = 0
    }

    Category
	{

    Tags
		{
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
			"LightMode" = "ForwardBase"
		}

    SubShader
    {



        Pass
        {
            ColorMask RGBA
			Cull Back
        
            LOD 100




            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_instancing
            // make fog work
            #pragma multi_compile_fwdbase
            #pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

            #pragma multi_compile ___ _qc_USE_RAIN 
			#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
			#pragma multi_compile ___ _qc_IGNORE_SKY 

            #include "Qc_TerrainCommon.cginc"
            #include "UnityCG.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"
				
			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_VolumetricFog.cginc"

            struct v2f
            {
                float4 pos			: SV_POSITION;
                float2 texcoord : TEXCOORD0;
                float3 worldPos : 	TEXCOORD1;
                float4 wTangent		: TEXCOORD2;
                float3 normal		: TEXCOORD3;
                float3 viewDir : TEXCOORD4;
                 float4 screenPos :		TEXCOORD5;
                SHADOW_COORDS(6)

                
					UNITY_VERTEX_INPUT_INSTANCE_ID
					UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert (appdata_full v)
            {
            	UNITY_SETUP_INSTANCE_ID(v);
                v2f o;
                UNITY_TRANSFER_INSTANCE_ID(v,o);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
               
                float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
                o.normal.xyz = UnityObjectToWorldNormal(v.normal);
                 o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.texcoord = v.texcoord;
                TRANSFER_SHADOW(o);
                o.worldPos = worldPos;
                TRANSFER_WTANGENT(o);
                 o.screenPos = ComputeScreenPos(o.pos);
                return o;
            }

           
            sampler2D _BumpMapBig;
            sampler2D _MadsBig;
            float _BlendHeight;
            float _BlendSharpness;

            fixed4 frag (v2f i) : SV_Target
            {
                float3 viewDir = normalize(i.viewDir);
                float2 screenUv = i.screenPos.xy / i.screenPos.w;

                float3 rawTerrainNormal;
                float4 terrainControl = Ct_SampleTerrainAndNormal(i.worldPos, rawTerrainNormal);

                float height;
                GetTerrainHeight(terrainControl, height);

            
                float4 terrainMads;
                float3 terrainNormal;
                float3 terrainCol;
                GetTerrainBlend(i.worldPos, terrainControl, rawTerrainNormal , terrainNormal, terrainCol, terrainMads);


               //  fixed4 objTex = tex2D(_MainTex, i.texcoord);
              //   float3 bump = UnpackNormal(tex2D(_BumpMap, i.texcoord));
               //  float4 madsMapObj = tex2D(_SpecularMap, i.texcoord);

                 float4 madsBig = tex2D(_MadsBig, i.texcoord);
                 float3 bumpBig = UnpackNormal(tex2D(_BumpMapBig, i.texcoord));
                 
                 float3 objectNormal = i.normal.xyz;
                 ApplyTangent (objectNormal, bumpBig, i.wTangent);

                 float3 objTex;
                 float3 objNormalTrip;
                 float4 madsMapObj;
                 TriplanarSampling(i.worldPos, i.normal.xyz, objTex, objNormalTrip, madsMapObj);

               

               //  objectNormal = normalize(lerp(objectNormal,objNormalTrip, 0.5));
          
                 float ao = madsBig.g;

                // return ao;

                 float showTerrain;
                 GetIntegration(terrainControl, terrainMads, madsMapObj, i.normal.xyz, i.worldPos, _BlendHeight, _BlendSharpness,  showTerrain);

            //   showTerrain = 0;

               


                float3 tex = lerp( objTex, terrainCol, showTerrain);
                float4 madsMap = lerp(madsMapObj, terrainMads, showTerrain);
                float3 rawNormal = normalize( lerp(i.normal.xyz, rawTerrainNormal, showTerrain));
                float3 projectedNormal = lerp(objNormalTrip,terrainNormal, showTerrain);

                 

                float3 normal = normalize((objectNormal + projectedNormal) * 0.5);

                 //  return float4(normal,1);

                float rawFresnel = saturate(1- dot(viewDir, rawNormal));

                ao *= madsMap.g; //, smoothstep(0.9,1,showTerrain));

               
           //    return ao;


                float shadow = SHADOW_ATTENUATION(i);

                float displacement = madsMap.b;

                float4 illumination;

			    ao *= SampleSS_Illumination( screenUv, illumination);

			    shadow *= saturate(1-illumination.b);

                ao *= madsMap.g;

                float metal =  madsMap.r;
				float fresnel =  GetFresnel_FixNormal(normal, terrainNormal, viewDir);

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
				precomp.metalColor = 0;

				precomp.microdetail.a = 0;
			
				float3 col = GetReflection_ByMaterialType(precomp, normal, rawNormal, viewDir, i.worldPos);

				ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);

                return float4(col,1);
            }

 


            ENDCG
        }


        
			Pass
			{
				Tags {"LightMode"="ShadowCaster"}
 
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_shadowcaster
				#pragma multi_compile_instancing
				#pragma multi_compile _ LOD_FADE_CROSSFADE
				#include "UnityCG.cginc"
 
				struct v2f {
					V2F_SHADOW_CASTER;
					 UNITY_VERTEX_INPUT_INSTANCE_ID // use this to access instanced properties in the fragment shader.
				};
 
				v2f vert(appdata_full v)
				{
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);
					UNITY_TRANSFER_INSTANCE_ID(v, o);

					o.pos = ComputeScreenPos(UnityObjectToClipPos(v.vertex));
					TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
					return o;
				}
 
				float4 frag(v2f i) : SV_Target
				{
				   // #ifdef LOD_FADE_CROSSFADE
					   // float2 vpos = i.pos.xy / i.pos.w * _ScreenParams.xy;
					  //  UnityApplyDitherCrossFade(vpos);
				   // #endif
					UNITY_SETUP_INSTANCE_ID(i);
					SHADOW_CASTER_FRAGMENT(i)
				}

				ENDCG
				//UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

			}

    //UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
    Fallback "Diffuse"
    }
}
