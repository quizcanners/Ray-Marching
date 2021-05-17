using System;
using UnityEngine;
using QuizCanners.CfgDecode;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using System.Collections.Generic;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace QuizCanners.RayTracing
{
    [ExecuteAlways]
    public class RayRenderingManager : MonoBehaviour , IPEGI, ILinkedLerping, ICfg
    {
        public static RayRenderingManager instance;

        [SerializeField] internal RayRandering_BuffersManager buffersManager = new RayRandering_BuffersManager();
        [SerializeField] internal RayRandering_TracerManager tracerManager = new RayRandering_TracerManager();
        [SerializeField] internal RayRandering_SceneManager sceneManager = new RayRandering_SceneManager();
        [SerializeField] internal RayRandering_LightsManager lightsManager = new RayRandering_LightsManager();
        [SerializeField] internal VolumeTracingBaker volumeTracingBaker;

        [SerializeField] internal CfgData _lastState;

        [Header("Common")]
        [SerializeField] internal LayerMask RayTracingResultUiMask;
        [SerializeField] internal LayerMask GeometryCameraMask;

        public RayRenderingTarget Target => tracerManager.Target;

        internal void Swap()
        {
            buffersManager.OnSwap(out RenderTexture targetBuffer);
            sceneManager.OnSwap(currentTargetBuffer: targetBuffer);
        }

        internal bool TargetIsScreenBuffer => Target == RayRenderingTarget.RayIntersection || Target == RayRenderingTarget.RayMarching;

        private void OnEnable()
        {
            instance = this;
            tracerManager.OnConfigurationChanged();
            this.DecodeFull(_lastState);
        }

        private void OnDisable()
        {
            _lastState = Encode().CfgData;
        }

        public void SetBakingDirty(string reason = "?")
        {
            sceneManager.OnSetBakingDirty();
            _setDirtyReason = reason;
        }

        #region Encode & Decode
        public CfgEncoder Encode() => new CfgEncoder()
                .Add("tM", tracerManager.configs)
                .Add("lM", lightsManager.Configs)
                .Add("sM", sceneManager.Configs);

        public void Decode(string key, CfgData data)
        {
            switch (key) 
            {
                case "tM": tracerManager.configs.DecodeFull(data); break;
                case "lM": lightsManager.Configs.DecodeFull(data); break;
                case "sM": sceneManager.Configs.DecodeFull(data); break;
            }
        }
        #endregion

        #region Updates & Lerp

        public void Update()
        {
            if (Application.isPlaying == false) 
            {
                return;
            }

            if (!lerpFinished)
            {
                _lerpData.Reset();
                Portion(_lerpData);
                Lerp(_lerpData, false);
            }

            
            sceneManager.ManagedUpdate(out int stableFrames, out List<VolumeShapeDraw> shapes);
            buffersManager.ManagedUpdate(stableFrames: stableFrames);

            if (volumeTracingBaker)
            {
                volumeTracingBaker.enabled = Target == RayRenderingTarget.Volume;

                if (volumeTracingBaker.enabled)
                {
                    volumeTracingBaker.ManagedUpdate(shapes: shapes, stableFrames);
                  
                }
            }
        }

        private bool lerpFinished;
        private readonly LerpData _lerpData = new LerpData();

        public void RequestLerps() => lerpFinished = false;
        
        public void Portion(LerpData ld)
        {
            if (lerpFinished)
                return;

            tracerManager.Portion(ld);
            lightsManager.Portion(ld);
            sceneManager.Portion(ld);
        }
        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (lerpFinished)
                return;

            lightsManager.Lerp(ld, canSkipLerp);
            tracerManager.Lerp(ld, canSkipLerp);
            sceneManager.Lerp(ld, canSkipLerp);
            
            if (ld.Done)
                lerpFinished = true;
            
        }

        #endregion

        #region Inspector
        private string _setDirtyReason;
        private int _inspectedStuff = -1;

        public void Inspect()
        {

            var changed = pegi.ChangeTrackStart();

            pegi.toggleDefaultInspector(this);

            pegi.nl();

            tracerManager.enter_Inspect_AsList(ref _inspectedStuff, 1, exitLabel: "Tracer Manager").nl();

            lightsManager.enter_Inspect_AsList(ref _inspectedStuff, 2, exitLabel: "Lights Manager").nl();

            sceneManager.enter_Inspect_AsList(ref _inspectedStuff, 3, exitLabel: "Scene Manager").nl();

            buffersManager.enter_Inspect_AsList(ref _inspectedStuff, 4, exitLabel: "Buffers Manager").nl();

            "Volume".edit_enter_Inspect(ref volumeTracingBaker, ref _inspectedStuff, 5).nl();

            if ("Dependencies".isEntered(ref _inspectedStuff, 10).nl())
            {
                "Geometry layer (Usually Default)".edit_Property(() => GeometryCameraMask, this).nl();

                "A UI Layer that is used when Main Camera is used for Tracing (Maybe create one) ".edit_Property(() => RayTracingResultUiMask, this).nl();
            }

            if (changed)
            {
                lerpFinished = false;
                SetBakingDirty(reason: "Inspector Changes");
                this.SkipLerp(_lerpData);
            }

            if (_inspectedStuff == -1)
            {
                if (!lerpFinished)
                {
                    "Lerp is Active".writeWarning();
                    "Dominant: {0} [{1}]".F(_lerpData.dominantParameter, _lerpData.MinPortion).nl();
                    pegi.nl();
                }
                else
                {
                    if (icon.Refresh.Click())
                        RequestLerps();

                    "Lerp Done: {0} [{1}] | Dirty from: {2}".F(_lerpData.dominantParameter, _lerpData.MinPortion, _setDirtyReason).nl();
                }
            }
        }

        public string NameForDisplayPEGI() => "Ray Rendering";

        #endregion
    }



    public enum RayRenderingTarget { Disabled = 0, RayIntersection = 1, RayMarching = 2, Volume = 3 }

#if UNITY_EDITOR
    [CustomEditor(typeof(RayRenderingManager))] internal class RayMarchingManagerDrawer : PEGI_Inspector { }
#endif

}