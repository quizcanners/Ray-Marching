using UnityEngine;

using System;

namespace QuizCanners.VolumeBakedRendering
{
    using SpecialEffects;
    using static QcRender;
    using Migration;
    using Inspect;
    using Lerp;
    using Utils;

    [ExecuteAlways]
    [AddComponentMenu(QcUtils.QUIZCANNERS + "/Qc Rendering/Renderer Controller")]
    public class Singleton_QcRendering : Singleton.BehaniourBase, IPEGI, ILinkedLerping, ICfg, ITaggedCfg
    {
        [Header("Submanagers")]
        [SerializeField] internal BuffersManager buffersManager = new();
        [SerializeField] internal TracerManager tracerManager = new();
        [SerializeField] internal TracingPrimitivesManager sceneManager = new();
        [SerializeField] internal QualityManager qualityManager = new();
        [SerializeField] internal ColorManager colorManager = new();
        [SerializeField] internal SDFVolume sdfVolume = new();
                           public WeatherManager lightsManager = new();
        [SerializeField] internal LowResolutionDepth lowResolutionDepth;
        [SerializeField] internal Shadowmap shadowmap = new();

        [Header("Dependencies")]
        [SerializeField] internal ConstantValues Constants = new();

        [Serializable]
        public class ConstantValues
        {
            public int TransparentFrames = 16;
        }

       

        Singleton_VolumeTracingBaker VolumeTracingBaker => Singleton.Get<Singleton_VolumeTracingBaker>();
        internal RayRenderingTarget Target => tracerManager.Target;
        public bool NeedScreenSpaceBaking => lightsManager.MaxRenderFrames > sceneManager.StableFrames;
        internal bool TargetIsScreenBuffer => Target == RayRenderingTarget.RayIntersection || Target == RayRenderingTarget.RayMarching || Target == RayRenderingTarget.ProgressiveRayMarching;
       
        protected override void OnAfterEnable()
        {
           // this.Decode(_lastState);
            qualityManager.ManagedOnEnable();
            tracerManager.OnConfigurationChanged();
            sceneManager.ManagedOnEnable();
            lightsManager.ManagedOnEnable();
            colorManager.ManagedOnEnable();
            sdfVolume.ManagedOnEnable();
            shadowmap.ManagedOnEnable();
            SetBakingDirty(reason: "Scene reloaded", invalidateResult: true);
        }

        protected override void OnBeforeOnDisableOrEnterPlayMode(bool _afterEnableCalled)
        {
            if (_afterEnableCalled)
            {
                //_lastState = Encode().CfgData;
                sceneManager.ManagedOnDisable();
                tracerManager.ManagedOnDisable();
                lightsManager.ManagedOnDisable();
                sdfVolume.ManagedOnDisable();
                shadowmap.ManagedOnDisable();
            }
        }

        private readonly LogicWrappers.Request _clearBakeRequest = new();

        public void SetBakingDirty(string reason = "?", bool invalidateResult = false)
        {
            _setDirtyReason = reason;
            VolumeTracing.Version++;

            if (invalidateResult) 
                _clearBakeRequest.CreateRequest();
        }

        #region Encode & Decode

        public string TagForConfig => "RayTrc";

        public CfgEncoder Encode() => new CfgEncoder()
                .Add("tM", tracerManager.Configs)
                .Add("lM", lightsManager.Configs)
               ;

        public void DecodeTag(string key, CfgData data)
        {
            switch (key) 
            {
                case "tM": tracerManager.Configs.Decode(data); break;
                case "lM": lightsManager.Configs.Decode(data); break;
            }
        }
        #endregion

        #region Updates & Lerp

        private readonly Gate.Integer _generalVersionGate = new();
        private readonly Gate.Bool _initializationFrameCompleted = new();// readonly Gate.Frame _initialBakeDelay = new();

        public void Update()
        {
            if (QcScenes.IsAnyLoading)
                return;

           

            if (_clearBakeRequest.TryUseRequest()) 
            {
                sceneManager.OnSetBakingDirty();
                if (VolumeTracingBaker)
                {
                    VolumeTracingBaker.ClearBake(eraseResult: true);
                }

                return;
            }

            if (_initializationFrameCompleted.TryChange(true))
                return;

            lightsManager.ManagedUpdate();

            //   if (!Application.isPlaying) 
            //     return;

            sceneManager.ManagedUpdate(out int stableFrames);


            if (!lerpFinished)
            {
                _lerpData.Reset();
                Portion(_lerpData);
                Lerp(_lerpData, false);
            }

       
            sdfVolume.ManagedUpdate();

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
          
            if (VolumeTracingBaker)
            {
                VolumeTracingBaker.enabled = Target == RayRenderingTarget.Volume;
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
        }
        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (lerpFinished)
                return;

            tracerManager.Lerp(ld, canSkipLerp);

            if (ld.IsDone)
                lerpFinished = true;
            
        }

        #endregion

        #region Inspector

        public override string InspectedCategory => "";

        private string _setDirtyReason;

        private readonly pegi.EnterExitContext context = new(playerPrefId: "RtxInsp");

        public override void Inspect()
        {
            "v. {0}".F(VolumeTracing.Version).PegiLabel().Write();

            if (!context.IsAnyEntered)
                Icon.Refresh.Click();

            pegi.Nl();

            using (context.StartContext())
            {
                Singleton.Collector.InspectionWarningIfMissing<Singleton_SpecialEffectShaders>();
                Singleton.Collector.InspectionWarningIfMissing<Singleton_CameraOperatorGodMode>();

                if (Singleton.TryGet<Singleton_SpecialEffectShaders>(out var s))
                {
                    if (s.NoiseTexture.EnableNoise == false)
                        "Noise Texture is disabled".PegiLabel().WriteWarning();
                    else
                    {
                        var m = s.NoiseTexture.NeedAttention();
                        if (m.IsNullOrEmpty() == false)
                            m.PegiLabel().WriteWarning();
                    }
                };

                if (Application.isPlaying)
                {
                    string rendering = (int)sceneManager.StableFrames >= lightsManager.MaxRenderFrames ? "Done" : "frms: {0} / {1} | stability: {2}".F((int)sceneManager.StableFrames, lightsManager.MaxRenderFrames, sceneManager.CameraMotion);
                    "RAY-INTERSECTION [{0}]".F(rendering).PegiLabel(style: pegi.Styles.ClippingText).Nl();
                }

                var changed = pegi.ChangeTrackStart();

                pegi.Nl();

                tracerManager.Enter_Inspect_AsList(exitLabel: "Tracer Manager").Nl();
                lightsManager.Enter_Inspect_AsList(exitLabel: "Weather Manager").Nl();
                sceneManager.Enter_Inspect_AsList(exitLabel: "Scene Manager").Nl();
                qualityManager.Enter_Inspect_AsList(exitLabel: "Quality Manager").Nl();
                buffersManager.Enter_Inspect_AsList(exitLabel: "Buffers Manager").Nl();
                sdfVolume.Enter_Inspect_AsList(exitLabel: "SDF Manager").Nl();
                lowResolutionDepth.Enter_Inspect_AsList(exitLabel: "Low Res Depth").Nl();
                colorManager.Enter_Inspect().Nl();

                if ("Volume".PegiLabel().IsEntered().Nl_ifEntered())
                    VolumeTracingBaker.Nested_Inspect().Nl();

                pegi.Nl();

                if ("Dependencies".PegiLabel().IsEntered().Nl())
                {
                    Singleton.Try<Singleton_RayRenderingCameraAndOutput>(s => s.Nested_Inspect(), 
                        onFailed: () => "{0} Singleton not found".F(nameof(Singleton_RayRenderingCameraAndOutput)).PegiLabel().WriteWarning());

                    Singleton.Try<Singleton_RayRendering_UiScreenSpaceOutput>(s => s.Nested_Inspect(),
                        onFailed: () => "{0} Singleton not found".F(nameof(Singleton_RayRendering_UiScreenSpaceOutput)).PegiLabel().WriteWarning());

                    if (context.IsAnyEntered == false)
                    {
                        "Shadows:".PegiLabel(pegi.Styles.BaldText).Nl();
                        var sc = QualitySettings.shadowCascades;
                        "_ Cascades".PegiLabel().Edit(ref sc, 1, 4).Nl().OnChanged(() => QualitySettings.shadowCascades = sc);

                        var sd = QualitySettings.shadowDistance;
                        "_ Distance".PegiLabel().Edit(ref sd).Nl().OnChanged(() => QualitySettings.shadowDistance = sd);
                    }
                }

                if (changed)
                {
                    lerpFinished = false;
                    SetBakingDirty(reason: "Inspector Changes", invalidateResult: true);
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

             if (Icon.Enter.Click())
                edited = ind;

            "RTX".PegiLabel(40, pegi.Styles.EnterLabel).Write();

            tracerManager.Inspect_Select(); //InspectInList_Nested(ref edited, ind); //exitLabel: "Tracer Manager").Nl();

            lightsManager.Inspect_SelectConfig(); //InspectInList_Nested(ref edited, ind);



            pegi.ClickHighlight(this);
        }

        public override string NeedAttention()
        {
            if (sceneManager.TryGetAttentionMessage(out var msg))
                return msg;

            return base.NeedAttention();
        }

        #endregion

       
    }

    [PEGI_Inspector_Override(typeof(Singleton_QcRendering))] internal class RayMarchingManagerDrawer : PEGI_Inspector_Override { }

}