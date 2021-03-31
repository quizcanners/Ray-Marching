using QuizCanners.CfgDecode;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Prototype;
using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace QuizCanners.RayTracing
{

    [Serializable]
    public class RayRandering_SceneManager : IPEGI, ILinkedLerping, ICfg, ICfgCustom
    {
        [SerializeField] public GodMode godModeCamera;
        [SerializeField] public RayTracingSceneBase sceneElements;
        [SerializeField] public RayRendering_SceneConfigs configs;
        [SerializeField] public GameObject rayTraceResult;
        [SerializeField] public RawImage accumulatedResult;
        private List<PrimitiveObjectPostBlit> All => PrimitiveObjectPostBlit.allCurrentObjects;

        public float StableFrames = 0;
        private Vector3 _previousCamPosition = Vector3.zero;
        private Quaternion _previousCamRotation = Quaternion.identity;
        public float CameraShakeDebug;

        public Camera MainCamera => godModeCamera ? godModeCamera.MainCam : null;
        protected RayRenderingManager Mgmt => RayRenderingManager.instance;

    

        public void Swap(RenderTexture tex) 
        {
            if (MainCamera)
                MainCamera.targetTexture = tex;
            if (accumulatedResult)
                accumulatedResult.texture = tex;
        }

        public void Decode(string key, CfgData data)
        {
            switch (key) 
            {
                case "se": sceneElements.DecodeFull(data); break;
                case "gm": godModeCamera.Decode(data); break;
                case "depth": MainCamera.depthTextureMode = (DepthTextureMode)data.ToInt(0); break;
            }    
        }

        public CfgEncoder Encode()
        {
            var cody = new CfgEncoder()
                .Add("se", sceneElements)
                .Add("gm", godModeCamera);

            if (MainCamera)
                cody.Add("depth", (int)MainCamera.depthTextureMode);

            return cody;
        }
  
        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (sceneElements)
                sceneElements.Lerp(ld, canSkipLerp);

            if (godModeCamera)
                godModeCamera.Lerp(ld, canSkipLerp);

            if (ld.MinPortion == 1)
            {
                if (godModeCamera && godModeCamera.mode != GodMode.Mode.FPS)
                    godModeCamera.mode = GodMode.Mode.FPS;
            }
        }

        public void Portion(LerpData ld)
        {
            if (sceneElements)
                sceneElements.Portion(ld);

            if (godModeCamera)
                godModeCamera.Portion(ld);
        }

        public void ManagedUpdate() 
        {
            var isScreen = Mgmt.TargetIsScreenBuffer;




            if (MainCamera)
            {
                var tf = MainCamera.transform;

                if (isScreen)
                {
                    CameraShakeDebug = (_previousCamPosition - tf.position).magnitude * 10 +
                                       Quaternion.Angle(_previousCamRotation, tf.rotation);

                    _previousCamPosition = tf.position;
                    _previousCamRotation = tf.rotation;

                    CameraShakeDebug = 1 - Mathf.Clamp01(CameraShakeDebug);

                    if (Mgmt.PauseAccumulation)
                        StableFrames = 0;
                    else
                        StableFrames = StableFrames * CameraShakeDebug + CameraShakeDebug;
                }
                else
                    StableFrames += 1;

                if (Mgmt.Target == RayRenderingTarget.Volume)
                    MainCamera.cullingMask = Mgmt.VolumeTracingCameraMask;

                if (isScreen)
                {
                    MainCamera.cullingMask = Mgmt.RayTracingResultMask;

                    MainCamera.clearFlags = CameraClearFlags.Nothing;

                    MainCamera.enabled = true;//!baked;

                    if (MainCamera.enabled)
                    {
                        Mgmt.Swap();
                    }
                }
                else
                {
                    MainCamera.clearFlags = CameraClearFlags.SolidColor;
                    MainCamera.targetTexture = null;
                    MainCamera.enabled = true;
                }
            }

            if (rayTraceResult)
                rayTraceResult.SetActive(isScreen);

            if (accumulatedResult)
                accumulatedResult.gameObject.SetActive(isScreen);

        }

        public void SetDirty() 
        {
            StableFrames = 0;
        }

        public void Inspect()
        {
            if (!MainCamera)
            {
                "God Mode".edit(ref godModeCamera);

                if (icon.Search.Click().nl())
                    godModeCamera = GameObject.FindObjectOfType<GodMode>();

                return;
            }

            if (MainCamera)
            {
                var depthMode = MainCamera.depthTextureMode;

                if ("Depth Mode".editEnumFlags(90, ref depthMode).nl())
                    MainCamera.depthTextureMode = depthMode;
            }


            "This will save setup of current scene objects".writeHint();

            "Scene Elements Collection".edit(ref sceneElements).nl();

            if (!accumulatedResult)
                "Accumulated Result".edit(ref accumulatedResult).nl();

            if (!rayTraceResult)
                "Ray-Tracing result".edit(ref rayTraceResult).nl();
            else if (!Mgmt.RayTracingResultMask.Contains(rayTraceResult.layer))
            {
                "Tracing Result Mask Doesn't Contain Tracer's Layer".writeWarning();
                rayTraceResult.ClickHighlight();
                pegi.nl();
            }

            if (godModeCamera && godModeCamera.mode == GodMode.Mode.STATIC && "Edit Camera".Click().nl())
                godModeCamera.mode = GodMode.Mode.FPS;

            ConfigurationsListBase.Inspect(ref configs);

           

        }

        public void Decode(CfgData data)
        {
            new CfgDecoder(data).DecodeTagsFor(this);

            if (godModeCamera)
                godModeCamera.mode = GodMode.Mode.LERP;

            Mgmt.RequestLerps();
        }
    }
}
