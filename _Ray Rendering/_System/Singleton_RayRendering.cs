using UnityEngine;
using QuizCanners.Migration;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using System;
using QuizCanners.SpecialEffects;

namespace QuizCanners.RayTracing
{
    [ExecuteAlways]
    internal partial class Singleton_RayRendering : Singleton.BehaniourBase, IPEGI, ILinkedLerping, ICfg, ITaggedCfg
    {
        [Header("Submanagers")]
        [SerializeField] internal BuffersManager buffersManager = new();
        [SerializeField] internal TracerManager tracerManager = new();
        [SerializeField] internal SceneManager sceneManager = new();
        [SerializeField] internal WeatherManager lightsManager = new();
        [SerializeField] internal QualityManager qualityManager = new();
        [SerializeField] internal ColorManager colorManager = new();

        [Header("Dependencies")]
     
        [SerializeField] internal ConstantValues Constants = new();

        [SerializeField] internal CfgData _lastState;

        [Serializable]
        public class ConstantValues
        {
            public int TransparentFrames = 16;
        }

        Singleton_VolumeTracingBaker VolumeTracingBaker => Singleton.Get<Singleton_VolumeTracingBaker>();
        private RayRenderingTarget Target => tracerManager.Target;
        public bool NeedScreenSpaceBaking => lightsManager.MaxRenderFrames > sceneManager.StableFrames;
        internal bool TargetIsScreenBuffer => Target == RayRenderingTarget.RayIntersection || Target == RayRenderingTarget.RayMarching || Target == RayRenderingTarget.ProgressiveRayMarching;
       
        protected override void OnAfterEnable()
        {
            this.Decode(_lastState);
            qualityManager.ManagedOnEnable();
            tracerManager.OnConfigurationChanged();
            sceneManager.ManagedOnEnable();
            lightsManager.ManagedOnEnable();
            colorManager.ManagedOnEnable();
        }

        protected override void OnBeforeOnDisableOrEnterPlayMode(bool _afterEnableCalled)
        {
            if (_afterEnableCalled)
            {
                _lastState = Encode().CfgData;
                sceneManager.ManagedOnDisable();
                tracerManager.ManagedOnDisable();
                lightsManager.ManagedOnDisable();
            }
        }

        public void SetBakingDirty(string reason = "?")
        {
            sceneManager.OnSetBakingDirty();
            _setDirtyReason = reason;
        }

        #region Encode & Decode

        public string TagForConfig => "RayTrc";

        public CfgEncoder Encode() => new CfgEncoder()
                .Add("tM", tracerManager.Configs)
                .Add("lM", lightsManager.Configs)
                .Add("qual", qualityManager)
               ;

        public void DecodeTag(string key, CfgData data)
        {
            switch (key) 
            {
                case "tM": tracerManager.Configs.Decode(data); break;
                case "lM": lightsManager.Configs.Decode(data); break;
                case "qual": qualityManager.Decode(data); break;
            }
        }
        #endregion

        #region Updates & Lerp

        public void Update()
        {
            if (!Application.isPlaying) 
                return;
            
            if (!lerpFinished)
            {
                _lerpData.Reset();
                Portion(_lerpData);
                Lerp(_lerpData, false);
            }

            sceneManager.ManagedUpdate(out int stableFrames);

            if (NeedScreenSpaceBaking && TargetIsScreenBuffer)
            {
                RenderTexture targetBuffer;

                if (Target == RayRenderingTarget.ProgressiveRayMarching && stableFrames == 0)
                {
                    targetBuffer = buffersManager.UseMarchingIntermadiateTexture();
                }
                else
                    buffersManager.OnSwap(out targetBuffer);

                sceneManager.OnSwap(currentTargetBuffer: targetBuffer);
            }

            buffersManager.ManagedUpdate(stableFrames: stableFrames);
            lightsManager.ManagedUpdate();

            if (VolumeTracingBaker)
            {
                VolumeTracingBaker.enabled = Target == RayRenderingTarget.Volume;// && (volumeTracingBaker.NeedBaking || NeedScreenSpaceBaking);

                if (VolumeTracingBaker.enabled) 
                {
                    if (stableFrames < 2)
                        VolumeTracingBaker.ClearBake();
                    else if (stableFrames < 16)
                        VolumeTracingBaker.BakeNewAreas();
                }
            
            }
        }

        private bool lerpFinished;
        private readonly LerpData _lerpData = new(unscaledTime: true);

        public void RequestLerps(string lerpSource)
        {
            lerpFinished = false;
            SetBakingDirty(reason: "Lerps Requested by "+lerpSource);
        }

        public void Portion(LerpData ld)
        {
            if (lerpFinished)
                return;

            tracerManager.Portion(ld);
            sceneManager.Portion(ld);
        }
        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (lerpFinished)
                return;

            tracerManager.Lerp(ld, canSkipLerp);
            sceneManager.Lerp(ld, canSkipLerp);

            SetBakingDirty("Lerping");

            if (ld.Done)
                lerpFinished = true;
            
        }

        #endregion

        #region Inspector

        public override string InspectedCategory => "";

        private string _setDirtyReason;

        private readonly pegi.EnterExitContext context = new(playerPrefId: "RtxInsp");

        public override void Inspect()
        {
            using (context.StartContext())
            {
                Singleton.Collector.InspectionWarningIfMissing<Singleton_SpecialEffectShaders>();
                Singleton.Collector.InspectionWarningIfMissing<Singleton_CameraOperatorGodMode>();

                Singleton.Try<Singleton_SpecialEffectShaders>(s =>
                {
                    if (s.NoiseTexture.EnableNoise == false)
                        "Noise Texture is disabled".PegiLabel().WriteWarning();
                    else
                    {
                        var m = s.NoiseTexture.NeedAttention();
                        if (m.IsNullOrEmpty() == false)
                            m.PegiLabel().WriteWarning();
                    }
                });

                string rendering = (int)sceneManager.StableFrames >= lightsManager.MaxRenderFrames ? "Done" : "frms: {0} / {1} | stability: {2}".F((int)sceneManager.StableFrames, lightsManager.MaxRenderFrames, sceneManager.CameraMotion);

                "RAY-INTERSECTION [{0}]".F(rendering).PegiLabel(style: pegi.Styles.ClippingText).Nl();

                var changed = pegi.ChangeTrackStart();

                pegi.Nl();

                tracerManager.Enter_Inspect_AsList(exitLabel: "Tracer Manager").Nl();

                lightsManager.Enter_Inspect_AsList(exitLabel: "Weather Manager").Nl();

                sceneManager.Enter_Inspect_AsList(exitLabel: "Scene Manager").Nl();

                qualityManager.Enter_Inspect_AsList(exitLabel: "Quality Manager").Nl();

                buffersManager.Enter_Inspect_AsList(exitLabel: "Buffers Manager").Nl();

                colorManager.Enter_Inspect().Nl();

                if ("Volume".PegiLabel().IsEntered().Nl_ifEntered())
                    VolumeTracingBaker.Nested_Inspect().Nl();

                if (context.IsAnyEntered == false)
                    Icon.Refresh.Click();

                pegi.Nl();

                if ("Dependencies".PegiLabel().IsEntered().Nl())
                {
                    Singleton.Try<Singleton_RayRenderingCameraAndOutput>(s => s.Nested_Inspect(), 
                        onFailed: () => "{0} Singleton not found".F(nameof(Singleton_RayRenderingCameraAndOutput)).PegiLabel().WriteWarning());

                    Singleton.Try<Singleton_RayRendering_UiScreenSpaceOutput>(s => s.Nested_Inspect(),
                        onFailed: () => "{0} Singleton not found".F(nameof(Singleton_RayRendering_UiScreenSpaceOutput)).PegiLabel().WriteWarning());
                }

                if (changed)
                {
                    if (VolumeTracingBaker)
                    {
                        VolumeTracingBaker.ClearBake();
                    }
                    lerpFinished = false;
                    SetBakingDirty(reason: "Inspector Changes");
                }

                if (context.IsAnyEntered == false && Application.isPlaying)
                {
                    if (!lerpFinished)
                    {
                        "Lerp is Active".PegiLabel().WriteWarning();
                        "Dominant: {0} [{1}]".F(_lerpData.dominantParameter, _lerpData.MinPortion).PegiLabel().Nl();
                        pegi.Nl();
                    }
                    else
                    {
                        if (Icon.Clear.Click("Restart Lerp & Rendering"))
                            RequestLerps("Manual Refresh");

                        "Lerp Done: {0} [{1}] | Dirty from: {2}".F(_lerpData.dominantParameter, _lerpData.MinPortion, _setDirtyReason).PegiLabel().Nl();
                    }
                }
            }
        }

        public override string ToString() => "RTX Manager";

        public override void InspectInList(ref int edited, int ind)
        {
            /* if (lightsManager.Configs)
             {
                 var ac = lightsManager.Configs.ActiveConfiguration;
                 if ("RTX".PegiLabel(40).Select(ref ac, lightsManager.Configs.configurations))
                     lightsManager.Configs.ActiveConfiguration = ac;
             }
             else
                 "RTX (No Cfgs)".PegiLabel().Write();*/

            // tracerManager.InspectInList_Nested(ref edited, ind); //exitLabel: "Tracer Manager").Nl();

            if (Icon.Enter.Click() | "RTX & Weather Root".PegiLabel().ClickLabel())
                edited = ind;

            pegi.ClickHighlight(this);

        }

        public override string NeedAttention()
        {
            if (sceneManager.TryGetAttentionMessage(out var msg))
                return msg;

            return base.NeedAttention();
        }

        #endregion

        public enum RayRenderingTarget { Disabled = 0, RayIntersection = 1, RayMarching = 2, Volume = 3, ProgressiveRayMarching = 4 }
    }



    [PEGI_Inspector_Override(typeof(Singleton_RayRendering))] internal class RayMarchingManagerDrawer : PEGI_Inspector_Override { }

}