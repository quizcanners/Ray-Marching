using QuizCanners.CfgDecode;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.IsItAGame;
using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using Object = UnityEngine.Object;

namespace QuizCanners.RayTracing
{

    [Serializable]
    public class RayRandering_SceneManager : IPEGI, ILinkedLerping, ICfgCustom, IPEGI_ListInspect
    {
        [SerializeField] public RayRendering_SceneConfigs Configs;
        [SerializeField] private GodMode _godModeCamera;
        [SerializeField] private RayTracingSceneBase _sceneElements;
        [SerializeField] private GameObject _rayTraceResult;
        [SerializeField] private RawImage _accumulatedResult;

        [NonSerialized] public float _stableFrames;
        [NonSerialized] private Vector3 _previousCamPosition = Vector3.zero;
        [NonSerialized] private Quaternion _previousCamRotation = Quaternion.identity;
        [NonSerialized] public float _cameraShakeDebug;

        public Camera MainCamera => _godModeCamera ? _godModeCamera.MainCam : null;
        protected RayRenderingManager Mgmt => RayRenderingManager.instance;

        public void OnSetBakingDirty() => _stableFrames = 0;
        
        public void OnSwap(RenderTexture currentTargetBuffer) 
        {
            if (MainCamera)
                MainCamera.targetTexture = currentTargetBuffer;
            if (_accumulatedResult)
                _accumulatedResult.texture = currentTargetBuffer;
        }

        public void ManagedUpdate(out int stableFrames, out List<VolumeShapeDraw> shapes) 
        {
            if (_sceneElements)
                shapes = _sceneElements.VolumeShapeDraws;
            else
                shapes = null;

            var isScreen = Mgmt.TargetIsScreenBuffer;

            if (MainCamera)
            {
                var tf = MainCamera.transform;

                if (isScreen)
                {
                    var position = tf.position;
                    var rotation = tf.rotation;
                    _cameraShakeDebug = (_previousCamPosition - position).magnitude * 10 +
                                       Quaternion.Angle(_previousCamRotation, rotation);

                    _previousCamPosition = position;
                    _previousCamRotation = rotation;

                    _cameraShakeDebug = 1 - Mathf.Clamp01(_cameraShakeDebug);

                    _stableFrames = _stableFrames * _cameraShakeDebug + _cameraShakeDebug;
                }
                else
                    _stableFrames += 1;

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

            if (_rayTraceResult)
                _rayTraceResult.SetActive(isScreen);

            if (_accumulatedResult)
                _accumulatedResult.gameObject.SetActive(isScreen);

            stableFrames = (int)_stableFrames;

        }

        #region Linked Lerp
        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (_sceneElements)
                _sceneElements.Lerp(ld, canSkipLerp);

            if (_godModeCamera)
                _godModeCamera.Lerp(ld, canSkipLerp);

            if (ld.Done)
            {
                if (_godModeCamera)
                    _godModeCamera.mode = GodMode.Mode.FPS;
            }
        }

        public void Portion(LerpData ld)
        {
            if (_sceneElements)
                _sceneElements.Portion(ld);

            if (_godModeCamera)
                _godModeCamera.Portion(ld);
        }
        #endregion

        #region Encode & Decode
        public void Decode(string key, CfgData data)
        {
            switch (key)
            {
                case "se": _sceneElements.DecodeFull(data); break;
                case "gm": _godModeCamera.Decode(data); break;
                case "depth": MainCamera.depthTextureMode = (DepthTextureMode)data.ToInt(); break;
            }
        }

        public CfgEncoder Encode()
        {
            var cody = new CfgEncoder()
                .Add("se", _sceneElements)
                .Add("gm", _godModeCamera);

            if (MainCamera)
                cody.Add("depth", (int)MainCamera.depthTextureMode);

            return cody;
        }

        public void Decode(CfgData data)
        {
            new CfgDecoder(data).DecodeTagsFor(this);

            if (_godModeCamera)
                _godModeCamera.mode = GodMode.Mode.LERP;

            Mgmt.RequestLerps();
        }
        #endregion

        #region Inspector

        public void InspectInList(ref int edited, int ind)
        {
            if (icon.Enter.Click() || "Scene".ClickLabel())
                edited = ind;

            if (!_godModeCamera)
                pegi.edit(ref _godModeCamera);
            else if (!_sceneElements)
                pegi.edit(ref _sceneElements);
            else if (!_accumulatedResult)
                pegi.edit(ref _accumulatedResult);
            else if (!_rayTraceResult)
                "Ray Trace Result".edit(ref _rayTraceResult);


            if (!Configs)
                "CFG".edit(60, ref Configs);
            else
                Configs.InspectShortcut();
        }

        public void Inspect()
        {
            pegi.nl();

            "RAY-INTERSECTION [frms: {0} | stability: {1}]".F((int)_stableFrames, _cameraShakeDebug)
                .nl(PEGI_Styles.ListLabel);

            pegi.nl();

            if (!MainCamera)
            {
                "God Mode".edit(ref _godModeCamera);

                if (icon.Search.Click().nl())
                    _godModeCamera = Object.FindObjectOfType<GodMode>();

                return;
            }

            if (MainCamera)
            {
                var depthMode = MainCamera.depthTextureMode;

                if ("Depth Mode".editEnumFlags(90, ref depthMode).nl())
                    MainCamera.depthTextureMode = depthMode;
            }


            "This will save setup of current scene objects".writeHint();

            "Scene Elements Collection".edit(ref _sceneElements).nl();

            if (!_accumulatedResult)
                "Accumulated Result".edit(ref _accumulatedResult).nl();

            if (!_rayTraceResult)
                "Ray-Tracing result".edit(ref _rayTraceResult).nl();
            else if (!Mgmt.RayTracingResultUiMask.Contains(_rayTraceResult.layer))
            {
                "Tracing Result Mask Doesn't Contain Tracer's Layer".writeWarning();
                _rayTraceResult.ClickHighlight();
                pegi.nl();
            }

            if (_godModeCamera && _godModeCamera.mode == GodMode.Mode.STATIC && "Edit Camera".Click().nl())
                _godModeCamera.mode = GodMode.Mode.FPS;

            ConfigurationsSO_Base.Inspect(ref Configs);
        }
        
        #endregion
    }
}
