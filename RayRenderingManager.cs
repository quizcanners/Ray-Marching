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
    public class RayRenderingManager :MonoBehaviour , ICfgCustom, IPEGI, ILinkedLerping
    {

        public static RayRenderingManager instance;
        [SerializeField] private RayRendering_TracerConfigs configs;


        public RayRandering_SceneManager SceneManager = new RayRandering_SceneManager();

        public RayRandering_LightsManager LightsManager = new RayRandering_LightsManager();

        private RayRenderingTarget _target;
        public RayRenderingTarget Target
        {
            get { return _target; }
            set
            {
                _target = value;
                _usingRayMarching.Enabled = value == RayRenderingTarget.RayMarching;
            }
        }

        public bool TargetIsScreenBuffer => Target == RayRenderingTarget.RayIntersection || Target == RayRenderingTarget.RayMarching;

        [Header("Common")]
        public bool PauseAccumulation;
        [SerializeField] public LayerMask RayTracingResultMask;
        [SerializeField] public LayerMask VolumeTracingCameraMask;

        public VolumeTracingBaker volumeTracingBaker;

        [SerializeField] protected int stopUpdatingAfter = 500;


        private ShaderProperty.ShaderKeyword _usingRayMarching = new ShaderProperty.ShaderKeyword("_IS_RAY_MARCHING");

        [Header("Ray-Marthing")] private ShaderProperty.FloatValue _maxStepsInShader = new ShaderProperty.FloatValue("_maxRayMarchSteps");
        [SerializeField] private float _maxSteps = 50;

        private ShaderProperty.FloatValue _maxDistanceInShader = new ShaderProperty.FloatValue("_MaxRayMarchDistance");
        [SerializeField] private float _maxDistance = 10000;

        private LinkedLerp.MaterialFloat _rayMarchSmoothness = new LinkedLerp.MaterialFloat("_RayMarchSmoothness", 1, 30);
        private LinkedLerp.MaterialFloat _rayMarchShadowSoftness = new LinkedLerp.MaterialFloat("_RayMarchShadowSoftness", 1, 30);

        [NonSerialized] private QcUtils.DynamicRangeFloat smoothness = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);
        [NonSerialized] private QcUtils.DynamicRangeFloat shadowSoftness = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);

        [Header("Ray-Tracing")]
        [NonSerialized] private QcUtils.DynamicRangeFloat DOFdistance = new QcUtils.DynamicRangeFloat(min: 0.01f, max: 50, value: 1);
        [NonSerialized] private LinkedLerp.MaterialFloat _RayTraceDepthOfField = new LinkedLerp.MaterialFloat("_RayTraceDofDist", startingValue: 1f, startingSpeed: 100f); // x - distance 
        
        [NonSerialized] private LinkedLerp.MaterialFloat DOFTargetStrength = new LinkedLerp.MaterialFloat("_RayTraceDOF", startingValue: 0.0001f, startingSpeed: 10);

        private ShaderProperty.ShaderKeyword _rayTraceUseDielecrtic = new ShaderProperty.ShaderKeyword("RT_USE_DIELECTRIC");
        private ShaderProperty.ShaderKeyword _rayTraceUseCheckerboard = new ShaderProperty.ShaderKeyword("RT_USE_CHECKERBOARD");

        private bool firstIsSourceBuffer;
        public RenderTexture[] twoBuffers;
     

        [Header("PROCESS CONTROLLERS")]
        private readonly ShaderProperty.FloatValue _RayTraceTraparency = new ShaderProperty.FloatValue("_RayTraceTransparency");
        private readonly ShaderProperty.ShaderKeyword MOTION_TRACING = new ShaderProperty.ShaderKeyword("RT_MOTION_TRACING");
        private readonly ShaderProperty.ShaderKeyword DENOISING = new ShaderProperty.ShaderKeyword("RT_DENOISING");
        private readonly ShaderProperty.TextureValue PathTracingSourceBuffer = new ShaderProperty.TextureValue("_RayTracing_SourceBuffer", set_ScreenFillAspect: true);
        private readonly ShaderProperty.TextureValue PathTracingTargetBuffer = new ShaderProperty.TextureValue("_RayTracing_TargetBuffer", set_ScreenFillAspect: true);


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
            UpdateShaderVariables();
            instance = this;
        }

        public void SetDirty(string reason = "?")
        {
            SceneManager.SetDirty();
            _setDirtyReason = reason;
        }

        private void UpdateShaderVariables()
        {
            _maxStepsInShader.GlobalValue = _maxSteps;
            _maxDistanceInShader.GlobalValue = _maxDistance;
        }

        #region Updates & Lerp

        public void Update()
        {
            if (Application.isPlaying == false) 
            {
                return;
            }

            if (playLerpAnimation)
            {
                lerpData.Reset();
                Portion(lerpData);
                Lerp(lerpData, false);
            }

            if (volumeTracingBaker)
            {
                volumeTracingBaker.bakingEnabled = Target == RayRenderingTarget.Volume;
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

        public bool playLerpAnimation;
        private bool lerpFinished;

        public void RequestLerps()
        {
            playLerpAnimation = true;
            lerpFinished = false;
        }

        private LerpData lerpData = new LerpData();
        
        public void Portion(LerpData ld)
        {
            if (lerpFinished)
                return;

            _rayMarchSmoothness.Portion(ld, smoothness.Value);
            _rayMarchShadowSoftness.Portion(ld, shadowSoftness.Value);
           
            _RayTraceDepthOfField.Portion(ld, DOFdistance.Value);
            DOFTargetStrength.Portion(ld);

           

            LightsManager.Portion(ld);
            SceneManager.Portion(ld);

         
        }

        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (lerpFinished)
                return;

            var isMarching = Target == RayRenderingTarget.RayMarching;

            _rayMarchSmoothness.Lerp(ld, canSkipLerp || !isMarching);
            _rayMarchShadowSoftness.Lerp(ld, canSkipLerp || !isMarching);
            LightsManager.Lerp(ld, canSkipLerp);
           

            _RayTraceDepthOfField.Lerp(ld, canSkipLerp);
            DOFTargetStrength.Lerp(ld, canSkipLerp);

          

            SceneManager.Lerp(ld, canSkipLerp);
            
            if (ld.Done)
            {
                lerpFinished = true;
                playLerpAnimation = false;
            }
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

            var trg = Target;
            if ("Target".editEnum(60, ref trg).nl())
                Target = trg;

            if ("Tracer".IsEntered(ref _inspectedStuff, 0).nl())
            {

                if (Target == RayRenderingTarget.RayMarching)
                {
                    "RAY-MARCHING".nl(PEGI_Styles.ListLabel);

                    "Max Steps".edit(ref _maxSteps, 1, 400).nl();

                    "Max Distance".edit(ref _maxDistance, 1, 50000).nl();

                    "Smoothness:".nl();
                    pegi.Nested_Inspect(ref smoothness); //.Inspect();
                    pegi.nl();

                    "Shadow Softness".nl();
                    pegi.Nested_Inspect(ref shadowSoftness).nl();
                }
                else
                {
                    _rayTraceUseDielecrtic.Nested_Inspect().nl();
                    _rayTraceUseCheckerboard.Nested_Inspect().nl();
                    "RAY-INTERSECTION [frms: {0} | stability: {1}]".F((int)SceneManager.StableFrames, SceneManager.CameraShakeDebug)
                        .nl(PEGI_Styles.ListLabel);

                }

                "DOF".nl();
                pegi.Nested_Inspect(ref DOFdistance).nl();
                var targ = DOFTargetStrength.TargetValue;
                if ("DOF Strength".edit(90, ref targ, 0.0001f, 3f).nl())
                    DOFTargetStrength.TargetValue = targ;

                if (changed)
                {
                    lerpFinished = false;
                    this.SkipLerp(lerpData);
                    lerpFinished = true;
                }

                ConfigurationsListBase.Inspect(ref configs);
            }

            if ("Lights".IsEntered(ref _inspectedStuff, 1).nl())
                LightsManager.Nested_Inspect().nl();

            if ("Scene".IsEntered(ref _inspectedStuff, 2).nl())
                SceneManager.Nested_Inspect().nl();

            if ("Dependencies".IsEntered(ref _inspectedStuff, 4).nl())
            {

                if (!volumeTracingBaker)
                        "Volume".edit(60, ref volumeTracingBaker).nl();
                
                "Volume Trace Layer".edit_Property(() => VolumeTracingCameraMask, this).nl();
         
                "Ray Trace Result Layer".edit_Property(() => RayTracingResultMask, this).nl();         
            }

    
            if (changed)
            {
                UpdateShaderVariables();
                SceneManager.StableFrames = 0;
            }

            if (playLerpAnimation)
            {
                "Lerp is Active".writeWarning();
                "Dominant: {0} [{1}]".F(lerpData.dominantParameter, lerpData.MinPortion).nl();
                pegi.nl();
            }
            else
                "Lerp Done: {0} [{1}] | Dirty from: {2}".F(lerpData.dominantParameter, lerpData.MinPortion, _setDirtyReason).nl();

          

           
        }

        public string NameForDisplayPEGI() => "Ray Rendering";

        #endregion

        #region Encode & Decode

        public CfgEncoder Encode()
        {
            var cody = new CfgEncoder()
               
              
                .Add("targ", (int)Target)
                .Add("dofD", DOFdistance)
                .Add("dofPow", DOFTargetStrength.TargetValue);

          

            if (_usingRayMarching.Enabled) cody
                .Add("sm", smoothness)
                .Add("shSo", shadowSoftness);
                    
            if (Target != RayRenderingTarget.RayMarching) cody
                .Add_Bool("diEl", _rayTraceUseDielecrtic.Enabled)
                .Add_Bool("rtCB", _rayTraceUseCheckerboard.Enabled);

            return cody;
        }

        public void Decode(string tg, CfgData data)
        {
            switch (tg)
            {
                case "sm": smoothness.Decode(data); break;
                case "shSo": shadowSoftness.Decode(data); break;
               
               
                case "targ": Target = (RayRenderingTarget)data.ToInt(); break;
              
                case "dofD": DOFdistance.Decode(data); break;
                case "dofPow": DOFTargetStrength.TargetValue = data.ToFloat(); break;
                case "diEl": _rayTraceUseDielecrtic.Enabled = data.ToBool(); break;
                case "rtCB": _rayTraceUseCheckerboard.Enabled = data.ToBool(); break;
            }
        }

        public void Decode(CfgData data)
        {
            new CfgDecoder(data).DecodeTagsFor(this);

            RequestLerps();
        }

      

        #endregion
    }



    public enum RayRenderingTarget { Disabled = 0, RayIntersection = 1, RayMarching = 2, Volume = 3 }

#if UNITY_EDITOR
    [CustomEditor(typeof(RayRenderingManager))] internal class RayMarchingManagerDrawer : PEGI_Inspector_Mono<RayRenderingManager> { }
#endif

}