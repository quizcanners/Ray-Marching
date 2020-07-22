using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace UniStorm.Utility
{
    public class UniStormClouds : Singleton.BehaniourBase
    {
        public Material skyMaterial;
        public Material cloudsMaterial;
        public Light sun => RenderSettings.sun;
      
        public enum CloudPerformance { Low = 0, Medium = 1, High = 2, Ultra = 3 }
         private int[] presetResolutions = { 1024, 2048, 2048, 2048 };
         private string[] keywordsA = { "LOW", "MEDIUM", "HIGH", "ULTRA" };

         public enum CloudType { TwoD = 0, Volumetric}
         private string[] keywordsB = { "TWOD", "VOLUMETRIC" };
         public CloudType cloudType = CloudType.Volumetric;
         public CloudPerformance performance = CloudPerformance.High;
         public int CloudShadowResolutionValue = 256;
         [Range(0, 1)] public float cloudTransparency = 0.85f;
         [Range(0, 6)] public int shadowBlurIterations;
         public CommandBuffer cloudsCommBuff;
        //
        //public int numRendersPerFrame = 1;
        private int frameCount = 0;

        private int frameIndex = 0;
        private int haltonSequenceIndex = 0;

        private int fullBufferIndex = 0;
        private RenderTexture[] fullCloudsBuffer;
        private RenderTexture lowResCloudsBuffer;
        private RenderTexture[] cloudShadowsBuffer;
        
        public RenderTexture PublicCloudShadowTexture;

        private float baseCloudOffset;
        private float detailCloudOffset;


        [NonSerialized] private bool _cloudsInitialized = false;

        UniStormSystem MGMT => Singleton.Get<UniStormSystem>();

        public void Initialize() 
        {
            SetCloudDetails(performance, cloudType);
            GetComponent<MeshRenderer>().enabled = true;

            GenerateNoise.GenerateBaseCloudNoise();
            GenerateNoise.GenerateCloudDetailNoise();
            GenerateNoise.GenerateCloudCurlNoise();

            GetComponent<MeshFilter>().sharedMesh = ProceduralHemispherePolarUVs.Hemisphere;
            GetComponentsInChildren<MeshFilter>()[1].sharedMesh = ProceduralHemispherePolarUVs.HemisphereInv;
            skyMaterial.SetFloat("_uLightningTimer", 0.0f);

            if (CloudShadowResolutionValue == 0)
            {
                CloudShadowResolutionValue = 256;
            }

            if (cloudsCommBuff == null)
            {
                const string BUFFER_NAME = "Render Clouds";


                CameraEvent camEvent;

                if (MGMT.VRStateData.VREnabled && MGMT.VRStateData.StereoRenderingMode == VRState.StereoRenderingModes.SinglePass)
                {
                    camEvent = CameraEvent.BeforeImageEffects;
                }
                else
                {
                    camEvent = CameraEvent.AfterSkybox;
                }

                var buffs = MGMT.PlayerCamera.GetCommandBuffers(camEvent);

                foreach (var b in buffs)
                {
                    if (b.name == BUFFER_NAME)
                        cloudsCommBuff = b;
                }

                if (cloudsCommBuff == null)
                {
                    cloudsCommBuff = new CommandBuffer
                    {
                        name = BUFFER_NAME
                    };

                    MGMT.PlayerCamera.AddCommandBuffer(camEvent, cloudsCommBuff);
                }
            }

            skyMaterial.Set(BASE_NOISE, GenerateNoise.baseNoiseTexture);
            skyMaterial.Set(DETAIL_NOISE, GenerateNoise.detailNoiseTexture);
            skyMaterial.Set(CURL_NOISE, GenerateNoise.curlNoiseTexture);


            int size = presetResolutions[(int)performance];

            EnsureArray(ref fullCloudsBuffer, 2);
            EnsureArray(ref cloudShadowsBuffer, 2);
            EnsureRenderTarget(ref fullCloudsBuffer[0], size, size, RenderTextureFormat.ARGBHalf, FilterMode.Bilinear, "fullCloudBuff0");
            EnsureRenderTarget(ref fullCloudsBuffer[1], size, size, RenderTextureFormat.ARGBHalf, FilterMode.Bilinear, "fullCloudBuff1");
            EnsureRenderTarget(ref cloudShadowsBuffer[0], CloudShadowResolutionValue, CloudShadowResolutionValue, RenderTextureFormat.ARGBHalf, FilterMode.Bilinear, "cloudShadowBuff0");
            EnsureRenderTarget(ref cloudShadowsBuffer[1], size, size, RenderTextureFormat.ARGBHalf, FilterMode.Bilinear, "cloudShadowBuff1");
            EnsureRenderTarget(ref lowResCloudsBuffer, size / 4, size / 4, RenderTextureFormat.ARGBFloat, FilterMode.Point, "quarterCloudBuff");

            _cloudsInitialized = true;
        }

        #region Helper Functions and Variables
        public void EnsureArray<T>(ref T[] array, int size, T initialValue = default(T))
        {
            if (array == null || array.Length != size)
            {
                array = new T[size];
                for (int i = 0; i != size; i++)
                    array[i] = initialValue;
            }
        }

        public bool EnsureRenderTarget(ref RenderTexture rt, int width, int height, RenderTextureFormat format, FilterMode filterMode, string name, int depthBits = 0, int antiAliasing = 1)
        {
            if (rt != null && (rt.width != width || rt.height != height || rt.format != format || rt.filterMode != filterMode || rt.antiAliasing != antiAliasing))
            {
                RenderTexture.ReleaseTemporary(rt);
                rt = null;
            }
            if (rt == null)
            {
                rt = RenderTexture.GetTemporary(width, height, depthBits, format, RenderTextureReadWrite.Default, antiAliasing);
                rt.name = name;
                rt.filterMode = filterMode;
                rt.wrapMode = TextureWrapMode.Repeat;
                return true;// new target
            }

#if UNITY_ANDROID || UNITY_IPHONE
            rt.DiscardContents();
#endif

            return false;// same target
        }

        static int[] haltonSequence = {
            8, 4, 12, 2, 10, 6, 14, 1
        };

        static int[,] offset = {
                    {2,1}, {1,2 }, {2,0}, {0,1},
                    {2,3}, {3,2}, {3,1}, {0,3},
                    {1,0}, {1,1}, {3,3}, {0,0},
                    {2,2}, {1,3}, {3,0}, {0,2}
                };

        static int[,] bayerOffsets = {
            {0,8,2,10 },
            {12,4,14,6 },
            {3,11,1,9 },
            {15,7,13,5 }
        };
        #endregion



        void ClearBuffers() 
        {
            if (cloudShadowsBuffer.IsNullOrEmpty() == false)
            {
                cloudShadowsBuffer[0].Release();
                cloudShadowsBuffer[1].Release();
            }

            if (lowResCloudsBuffer != null)
                lowResCloudsBuffer.Release();

            if (fullCloudsBuffer.IsNullOrEmpty() == false)
            {
                fullCloudsBuffer[0].Release();
                fullCloudsBuffer[1].Release();
            }

            frameCount = 0;
        }

        private CloudPerformance Performance 
        {
          //  get => performance;
            set 
            {
                ClearBuffers();
                performance = value;
                UpdateKeywords();
            }
        }

        private CloudType Type
        {
           // get => cloudType;
            set
            {
                ClearBuffers();
                cloudType = value;
                UpdateKeywords();
            }
        }


        public void SetCloudDetails(CloudPerformance performance, CloudType cloudType, bool forceRecreateTextures = false)
        {
            if (this.performance != performance || this.cloudType != cloudType || forceRecreateTextures)
            {
                ClearBuffers();
            }

            this.performance = performance;
            this.cloudType = cloudType;

            UpdateKeywords();
        }

        void UpdateKeywords() 
        {
            foreach (string s in skyMaterial.shaderKeywords)
                skyMaterial.DisableKeyword(s);

            skyMaterial.EnableKeyword(keywordsA[(int)performance]);
            skyMaterial.EnableKeyword(keywordsB[(int)cloudType]);
        }

#if UNITY_EDITOR
        private void OnValidate()
        {
            SetCloudDetails(performance, cloudType, true);
        }
#endif

        void Update()
        {
            if (_cloudsInitialized)
            {
                CloudsUpdate();
            }
        }

        private readonly ShaderProperty.Feature PREWARM = new("PREWARM");
        private readonly ShaderProperty.TextureValue BASE_NOISE = new("_uBaseNoise");
        private readonly ShaderProperty.TextureValue DETAIL_NOISE = new("_uDetailNoise");
        private readonly ShaderProperty.TextureValue CURL_NOISE = new("_uCurlNoise");
        private readonly ShaderProperty.FloatValue CLOUD_MOVEMENT_SPEED = new("_uCloudsMovementSpeed");
        private readonly ShaderProperty.FloatValue CLOUD_TURBULANCE_SPEED = new("_uCloudsTurbulenceSpeed");
        private readonly ShaderProperty.FloatValue BASE_CLOUD_OFFSET = new("_uBaseCloudOffset");
        private readonly ShaderProperty.FloatValue DETAIL_CLOUD_OFFSET = new("_uDetailCloudOffset");


        void CloudsUpdate()
        {
            frameIndex = (frameIndex + 1) % 16;

            if (frameIndex == 0)
                haltonSequenceIndex = (haltonSequenceIndex + 1) % haltonSequence.Length;
            fullBufferIndex = fullBufferIndex ^ 1;

            float offsetX = offset[frameIndex, 0];
            float offsetY = offset[frameIndex, 1];

            frameCount++;
            if (frameCount < 32)
                PREWARM.Enabled = true;//skyMaterial.EnableKeyword("PREWARM");
            else if (frameCount == 32)
                PREWARM.Enabled = false;
           // skyMaterial.DisableKeyword("PREWARM");

            int size = presetResolutions[(int)performance];

            baseCloudOffset += skyMaterial.Get(CLOUD_MOVEMENT_SPEED) * Time.deltaTime;
            detailCloudOffset += skyMaterial.Get(CLOUD_TURBULANCE_SPEED) * Time.deltaTime;

            skyMaterial.Set(BASE_CLOUD_OFFSET, baseCloudOffset);
            skyMaterial.Set(DETAIL_CLOUD_OFFSET, detailCloudOffset);

            skyMaterial.SetFloat("_uSize", size);
            skyMaterial.SetInt("_uCount", frameCount);
            skyMaterial.SetVector("_uJitter", new Vector2(offsetX, offsetY));
            skyMaterial.SetFloat("_uRaymarchOffset", (haltonSequence[haltonSequenceIndex] / 16.0f + bayerOffsets[offset[frameIndex, 0], offset[frameIndex, 1]] / 16.0f));

            skyMaterial.SetVector("_uSunDir", sun.transform.forward);
            skyMaterial.SetVector("_uMoonDir", Vector3.Normalize(-sun.transform.forward));
            skyMaterial.SetVector("_uWorldSpaceCameraPos", MGMT.PlayerCamera.transform.position);

            #region Command Buffer
            cloudsCommBuff.Clear();

            // 1. Render the first clouds buffer - lower resolution
            cloudsCommBuff.Blit(null, lowResCloudsBuffer, skyMaterial, 0);

            // 2. Blend between low and hi-res
            cloudsCommBuff.SetGlobalTexture("_uLowresCloudTex", lowResCloudsBuffer);
            cloudsCommBuff.SetGlobalTexture("_uPreviousCloudTex", fullCloudsBuffer[fullBufferIndex]);
            cloudsCommBuff.Blit(fullCloudsBuffer[fullBufferIndex], fullCloudsBuffer[fullBufferIndex ^ 1], skyMaterial, 1);
            cloudsCommBuff.SetGlobalFloat("_uLightning", 0.0f);
            #endregion

            // 3. Set to material for the sky (not in the command buffer)
            cloudsMaterial.SetTexture("_MainTex", fullCloudsBuffer[fullBufferIndex ^ 1]);
        }


        #region Inspector

        public override void Inspect() 
        {
            pegi.Nl();

            if ("Performance".PegiLabel().Edit_Enum(ref performance).Nl())
                Performance = performance;

            if ("Cloud Type".PegiLabel().Edit_Enum(ref cloudType).Nl())
                Type = cloudType;
        }


        #endregion

    }

    [PEGI_Inspector_Override(typeof(UniStormClouds))] internal class UniStormCloudsDrawer : PEGI_Inspector_Override { }
}
 