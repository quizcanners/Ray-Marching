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
    public class RayRenderingManager :MonoBehaviour , IPEGI, ILinkedLerping
    {
        public static RayRenderingManager instance;

        public RayRandering_TracerManager TracerManager = new RayRandering_TracerManager();
        public RayRandering_SceneManager SceneManager = new RayRandering_SceneManager();
        public RayRandering_LightsManager LightsManager = new RayRandering_LightsManager();

        public VolumeTracingBaker volumeTracingBaker;


        [Header("Common")]
        public bool PauseAccumulation;
        [SerializeField] public LayerMask RayTracingResultUiMask;
        [SerializeField] public LayerMask GeometryCameraMask;

        [SerializeField] protected int stopUpdatingAfter = 500;

        private bool firstIsSourceBuffer;
        public RenderTexture[] twoBuffers;
     

        [Header("PROCESS CONTROLLERS")]
        private readonly ShaderProperty.FloatValue _RayTraceTraparency = new ShaderProperty.FloatValue("_RayTraceTransparency");
        private readonly ShaderProperty.ShaderKeyword MOTION_TRACING = new ShaderProperty.ShaderKeyword("RT_MOTION_TRACING");
        private readonly ShaderProperty.ShaderKeyword DENOISING = new ShaderProperty.ShaderKeyword("RT_DENOISING");
        private readonly ShaderProperty.TextureValue PathTracingSourceBuffer = new ShaderProperty.TextureValue("_RayTracing_SourceBuffer", set_ScreenFillAspect: true);
        private readonly ShaderProperty.TextureValue PathTracingTargetBuffer = new ShaderProperty.TextureValue("_RayTracing_TargetBuffer", set_ScreenFillAspect: true);

        public RayRenderingTarget Target => TracerManager.Target;

        public bool TargetIsScreenBuffer => Target == RayRenderingTarget.RayIntersection || Target == RayRenderingTarget.RayMarching;

        public void Swap()
        {
            firstIsSourceBuffer = !firstIsSourceBuffer;

            var targBuff = TargetBuffer;

            PathTracingSourceBuffer.GlobalValue = SourceBuffer;
            PathTracingTargetBuffer.GlobalValue = targBuff;
            SceneManager.Swap(targBuff);
        }
        private RenderTexture SourceBuffer => firstIsSourceBuffer ? twoBuffers[0] : twoBuffers[1];
        private RenderTexture TargetBuffer => firstIsSourceBuffer ? twoBuffers[1] : twoBuffers[0];

        public void OnEnable()
        {
            instance = this;
            TracerManager.OnConfigurationChanged();
        }

        public void SetDirty(string reason = "?")
        {
            SceneManager.SetDirty();
            _setDirtyReason = reason;
        }

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

            if (volumeTracingBaker)
            {
                volumeTracingBaker.bakingEnabled =  TracerManager.Target == RayRenderingTarget.Volume;
            }

            SceneManager.ManagedUpdate();

            var stableFrames = SceneManager.StableFrames;

            _RayTraceTraparency.GlobalValue = stableFrames < 2 ? 1f : Mathf.Clamp(2f / stableFrames, 0.001f, 0.5f);

            DENOISING.Enabled = stableFrames < 16;//(_stopUpdatingAfter * 0.25f);

            MOTION_TRACING.Enabled = stableFrames < 2;

            bool baked = stableFrames > stopUpdatingAfter;

            if (!baked && volumeTracingBaker)
                volumeTracingBaker.SetBakeDirty();

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

        public static RayRenderingManager inspected;

        protected bool _showDependencies;
        private int _inspectedStuff = -1;

        public void Inspect()
        {


            var changed = pegi.ChangeTrackStart();

            inspected = this;

            pegi.toggleDefaultInspector(this);

            pegi.toggle(ref PauseAccumulation, icon.Play, icon.Pause);

            pegi.nl();

            TracerManager.enter_Inspect_AsList(ref _inspectedStuff, 1, exitLabel: "Tracer Manager").nl();

            LightsManager.enter_Inspect_AsList(ref _inspectedStuff, 2, exitLabel: "Lights Manager").nl();

            SceneManager.enter_Inspect_AsList(ref _inspectedStuff, 3, exitLabel: "Scene Manager").nl();

            if ("Dependencies".IsEntered(ref _inspectedStuff, 4).nl())
            {
                if (!volumeTracingBaker)
                    "Volume".edit(60, ref volumeTracingBaker).nl();

                "Geometry layer (Usually Default)".edit_Property(() => GeometryCameraMask, this).nl();

                "A UI Layer that is used when Main Camera is used for Tracing (Maybe create one) ".edit_Property(() => RayTracingResultUiMask, this).nl();
            }

            if (changed)
            {
                lerpFinished = false;
                SceneManager.StableFrames = 0;
                this.SkipLerp(lerpData);

            }

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

        public string NameForDisplayPEGI() => "Ray Rendering";

        #endregion

    }



    public enum RayRenderingTarget { Disabled = 0, RayIntersection = 1, RayMarching = 2, Volume = 3 }

#if UNITY_EDITOR
    [CustomEditor(typeof(RayRenderingManager))] internal class RayMarchingManagerDrawer : PEGI_Inspector_Mono<RayRenderingManager> { }
#endif

}