using QuizCanners.CfgDecode;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Prototype;
using QuizCanners.Utils;
using System;
using UnityEngine;
using UnityEngine.UI;
using Object = UnityEngine.Object;

namespace QuizCanners.RayTracing
{

    [Serializable]
    public class RayRandering_SceneManager : IPEGI, ILinkedLerping, ICfgCustom, IPEGI_ListInspect
    {
        [SerializeField] public GodMode godModeCamera;
        [SerializeField] public RayTracingSceneBase sceneElements;
        [SerializeField] public RayRendering_SceneConfigs configs;
        [SerializeField] public GameObject rayTraceResult;
        [SerializeField] public RawImage accumulatedResult;

        public float StableFrames;
        private Vector3 _previousCamPosition = Vector3.zero;
        private Quaternion _previousCamRotation = Quaternion.identity;
        public float CameraShakeDebug;

        public Camera MainCamera => godModeCamera ? godModeCamera.MainCam : null;
        protected RayRenderingManager Mgmt => RayRenderingManager.instance;

        public void SetDirty()
        {
            StableFrames = 0;
        }

        public void Swap(RenderTexture tex) 
        {
            if (MainCamera)
                MainCamera.targetTexture = tex;
            if (accumulatedResult)
                accumulatedResult.texture = tex;
        }

        public void ManagedUpdate() 
        {
            var isScreen = Mgmt.TargetIsScreenBuffer;

            if (MainCamera)
            {
                var tf = MainCamera.transform;

                if (isScreen)
                {
                    var position = tf.position;
                    var rotation = tf.rotation;
                    CameraShakeDebug = (_previousCamPosition - position).magnitude * 10 +
                                       Quaternion.Angle(_previousCamRotation, rotation);

                    _previousCamPosition = position;
                    _previousCamRotation = rotation;

                    CameraShakeDebug = 1 - Mathf.Clamp01(CameraShakeDebug);

                    if (Mgmt.PauseAccumulation)
                        StableFrames = 0;
                    else
                        StableFrames = StableFrames * CameraShakeDebug + CameraShakeDebug;
                }
                else
                    StableFrames += 1;

                if (Mgmt.Target == RayRenderingTarget.Volume)
                    MainCamera.cullingMask = Mgmt.GeometryCameraMask;

                if (isScreen)
                {
                    MainCamera.cullingMask = Mgmt.RayTracingResultUiMask;

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

        #region Linked Lerp
        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (sceneElements)
                sceneElements.Lerp(ld, canSkipLerp);

            if (godModeCamera)
                godModeCamera.Lerp(ld, canSkipLerp);

            if (ld.Done)
            {
                if (godModeCamera)
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
        #endregion

        #region Encode & Decode
        public void Decode(string key, CfgData data)
        {
            switch (key)
            {
                case "se": sceneElements.DecodeFull(data); break;
                case "gm": godModeCamera.Decode(data); break;
                case "depth": MainCamera.depthTextureMode = (DepthTextureMode)data.ToInt(); break;
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

        public void Decode(CfgData data)
        {
            new CfgDecoder(data).DecodeTagsFor(this);

            if (godModeCamera)
                godModeCamera.mode = GodMode.Mode.LERP;

            Mgmt.RequestLerps();
        }
        #endregion

        #region Inspector

        public void InspectInList(int ind, ref int edited)
        {
            if (icon.Enter.Click() || "Scene".ClickLabel())
                edited = ind;

            if (!godModeCamera)
                pegi.edit(ref godModeCamera);


            if (!configs)
                "CFG".edit(60, ref configs);
            else
                configs.InspectShortcut();
        }

        public void Inspect()
        {
            pegi.nl();

            "RAY-INTERSECTION [frms: {0} | stability: {1}]".F((int)StableFrames, CameraShakeDebug)
                .nl(PEGI_Styles.ListLabel);

            pegi.nl();

            if (!MainCamera)
            {
                "God Mode".edit(ref godModeCamera);

                if (icon.Search.Click().nl())
                    godModeCamera = Object.FindObjectOfType<GodMode>();

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
            else if (!Mgmt.RayTracingResultUiMask.Contains(rayTraceResult.layer))
            {
                "Tracing Result Mask Doesn't Contain Tracer's Layer".writeWarning();
                rayTraceResult.ClickHighlight();
                pegi.nl();
            }

            if (godModeCamera && godModeCamera.mode == GodMode.Mode.STATIC && "Edit Camera".Click().nl())
                godModeCamera.mode = GodMode.Mode.FPS;

            ConfigurationsSO_Base.Inspect(ref configs);
        }


        #endregion
    }
}
