using System;
using UnityEngine;
using QuizCanners.CfgDecode;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Utils;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace QuizCanners.RayTracing
{
    [ExecuteAlways]
    public class RayRenderingManager : MonoBehaviour , IPEGI, ILinkedLerping, ICfg
    {
        public static RayRenderingManager instance;

        public RayRandering_BuffersManager BuffersManager = new RayRandering_BuffersManager();
        public RayRandering_TracerManager TracerManager = new RayRandering_TracerManager();
        public RayRandering_SceneManager SceneManager = new RayRandering_SceneManager();
        public RayRandering_LightsManager LightsManager = new RayRandering_LightsManager();

        [SerializeField] private CfgData _lastState;

        [Header("Common")]
        [SerializeField] public LayerMask RayTracingResultUiMask;
        [SerializeField] public LayerMask GeometryCameraMask;

        public void Swap()
        {
            BuffersManager.OnSwap(out RenderTexture targetBuffer);
            SceneManager.OnSwap(currentTargetBuffer: targetBuffer);
        }
     
        public RayRenderingTarget Target => TracerManager.Target;

        public bool TargetIsScreenBuffer => Target == RayRenderingTarget.RayIntersection || Target == RayRenderingTarget.RayMarching;

        public void OnEnable()
        {
            instance = this;
            TracerManager.OnConfigurationChanged();
            this.DecodeFull(_lastState);
        }

        public void OnDisable()
        {
            _lastState = Encode().CfgData;
        }

        public void SetDirty(string reason = "?")
        {
            SceneManager.SetDirty();
            _setDirtyReason = reason;
        }

        #region Encode & Decode
        public CfgEncoder Encode() => new CfgEncoder()
                .Add("tM", TracerManager.configs)
                .Add("lM", LightsManager.Configs)
                .Add("sM", SceneManager.Configs);

        public void Decode(string key, CfgData data)
        {
            switch (key) 
            {
                case "tM": TracerManager.configs.DecodeFull(data); break;
                case "lM": LightsManager.Configs.DecodeFull(data); break;
                case "sM": SceneManager.Configs.DecodeFull(data); break;
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
                lerpData.Reset();
                Portion(lerpData);
                Lerp(lerpData, false);
            }

            SceneManager.ManagedUpdate(out int stableFrames);
            BuffersManager.ManagedUpdate(stableFrames: stableFrames);
        }

        private bool lerpFinished;

        public void RequestLerps() => lerpFinished = false;
        
        private LerpData lerpData = new LerpData();
        public void Portion(LerpData ld)
        {
            if (lerpFinished)
                return;

            TracerManager.Portion(ld);
            LightsManager.Portion(ld);
            SceneManager.Portion(ld);
        }
        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (lerpFinished)
                return;

            LightsManager.Lerp(ld, canSkipLerp);
            TracerManager.Lerp(ld, canSkipLerp);
            SceneManager.Lerp(ld, canSkipLerp);
            
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

            TracerManager.enter_Inspect_AsList(ref _inspectedStuff, 1, exitLabel: "Tracer Manager").nl();

            LightsManager.enter_Inspect_AsList(ref _inspectedStuff, 2, exitLabel: "Lights Manager").nl();

            SceneManager.enter_Inspect_AsList(ref _inspectedStuff, 3, exitLabel: "Scene Manager").nl();

            BuffersManager.enter_Inspect_AsList(ref _inspectedStuff, 4, exitLabel: "Buffers Manager").nl();

            if ("Dependencies".isEntered(ref _inspectedStuff, 10).nl())
            {
                "Geometry layer (Usually Default)".edit_Property(() => GeometryCameraMask, this).nl();

                "A UI Layer that is used when Main Camera is used for Tracing (Maybe create one) ".edit_Property(() => RayTracingResultUiMask, this).nl();
            }

            if (changed)
            {
                lerpFinished = false;
                SceneManager.StableFrames = 0;
                this.SkipLerp(lerpData);
            }

            if (_inspectedStuff == -1)
            {
                if (!lerpFinished)
                {
                    "Lerp is Active".writeWarning();
                    "Dominant: {0} [{1}]".F(lerpData.dominantParameter, lerpData.MinPortion).nl();
                    pegi.nl();
                }
                else
                {
                    if (icon.Refresh.Click())
                        RequestLerps();

                    "Lerp Done: {0} [{1}] | Dirty from: {2}".F(lerpData.dominantParameter, lerpData.MinPortion, _setDirtyReason).nl();
                }
            }
        }

        public string NameForDisplayPEGI() => "Ray Rendering";

        #endregion
    }



    public enum RayRenderingTarget { Disabled = 0, RayIntersection = 1, RayMarching = 2, Volume = 3 }

#if UNITY_EDITOR
    [CustomEditor(typeof(RayRenderingManager))] internal class RayMarchingManagerDrawer : PEGI_Inspector_Mono<RayRenderingManager> { }
#endif

}