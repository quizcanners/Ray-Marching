using System;
using PlayerAndEditorGUI;
using PlaytimePainter.Examples;
using QuizCannersUtilities;
using UnityEngine;
using NodeNotes_Visual;
using UnityEngine.UI;
using static NodeNotes.NodeNotesAssetGroup;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace NodeNotes.RayTracing
{
    
    public class RayRenderingManager : PresentationSystemsAbstract, IPEGI, ICfg, ILinkedLerping
    {
        public override string ClassTag => "RtxMgmt";

        public static RayRenderingManager instance;

        public enum RayRenderingTarget { Disabled = 0, Screen = 1, Volume = 2}
        private RayRenderingTarget _target;
        public RayRenderingTarget Target
        {
            get { return _target; }
            set
            {
                _target = value;
            }
        }

        [Header("Common")]

        public GodMode godModeCamera;
        public LayerMask rayTracingResultMask;
        public LayerMask volumeTracingCameraMask;
        public VolumeTracingBaker volumeTracingBaker;
        public Camera MainCamera => godModeCamera ? godModeCamera.MainCam : null;
        public GameObject rayTracingScreenBakingPlane;
        public RawImage rayTracingScreenOutputPlane;
        public GameObject rayTracingOutputGo;

        public RayTracingSceneBase sceneConfiguration;
        

        LinkedLerp.MaterialColor _sunLightColor = new LinkedLerp.MaterialColor("_RayMarchLightColor", Color.grey, 10);
        LinkedLerp.MaterialColor _skyColor = new LinkedLerp.MaterialColor("_RayMarchSkyColor", Color.grey, 10);
        LinkedLerp.ColorValue _fogColor = new LinkedLerp.ColorValue("Fog", speed: 10);

        private bool UseRayTracing
        {
            get { return !_usingRayMarching.Enabled; }
            set { _usingRayMarching.Enabled = !value; }
        }
        
        ShaderProperty.ShaderKeyword _usingRayMarching = new ShaderProperty.ShaderKeyword("_IS_RAY_MARCHING");

        [Header("Ray-Marthing")]
        ShaderProperty.FloatValue _maxStepsInShader = new ShaderProperty.FloatValue("_maxRayMarchSteps");
        [SerializeField] private float _maxSteps = 50;

        ShaderProperty.FloatValue _maxDistanceInShader = new ShaderProperty.FloatValue("_MaxRayMarchDistance");
        [SerializeField] private float _maxDistance = 10000;

        LinkedLerp.MaterialFloat _rayMarchSmoothness = new LinkedLerp.MaterialFloat("_RayMarchSmoothness", 1, 30);
        LinkedLerp.MaterialFloat _rayMarchShadowSoftness = new LinkedLerp.MaterialFloat("_RayMarchShadowSoftness", 1, 30);

        [NonSerialized] private QcUtils.DynamicRangeFloat smoothness = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);
        [NonSerialized] private QcUtils.DynamicRangeFloat shadowSoftness = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);

        [Header("Ray-Tracing")]

        [NonSerialized] private QcUtils.DynamicRangeFloat DOFdistance = new QcUtils.DynamicRangeFloat(min: 0.01f, max: 50, value: 1);
        [NonSerialized] LinkedLerp.MaterialFloat _RayTraceDepthOfField = new LinkedLerp.MaterialFloat("_RayTraceDofDist", startingValue: 1f, startingSpeed: 100f); // x - distance 
        
        [NonSerialized] private LinkedLerp.MaterialFloat DOFTargetStrength = new LinkedLerp.MaterialFloat("_RayTraceDOF", startingValue: 0.0001f, startingSpeed: 10);
        
        ShaderProperty.ShaderKeyword _rayTraceUseDielecrtic = new ShaderProperty.ShaderKeyword("RT_USE_DIELECTRIC");
        ShaderProperty.ShaderKeyword _rayTraceUseCheckerboard = new ShaderProperty.ShaderKeyword("RT_USE_CHECKERBOARD");

        private bool firstIsSourceBuffer;
        public RenderTexture[] twoBuffers;

        [Header("PROCESS CONTROLLERS")]
        ShaderProperty.FloatValue _RayTraceTraparency = new ShaderProperty.FloatValue("_RayTraceTransparency");
        private readonly ShaderProperty.ShaderKeyword MOTION_TRACING = new ShaderProperty.ShaderKeyword("RT_MOTION_TRACING");
        private readonly ShaderProperty.ShaderKeyword DENOISING = new ShaderProperty.ShaderKeyword("RT_DENOISING");
        private readonly ShaderProperty.TextureValue PathTracingSourceBuffer = new ShaderProperty.TextureValue("_RayTracing_SourceBuffer", set_ScreenFillAspect: true);
        private readonly ShaderProperty.TextureValue PathTracingTargetBuffer = new ShaderProperty.TextureValue("_RayTracing_TargetBuffer", set_ScreenFillAspect: true);


        private void Swap()
        {
            firstIsSourceBuffer = !firstIsSourceBuffer;

            var targBuff = TargetBuffer;

            PathTracingSourceBuffer.GlobalValue = SourceBuffer;
            PathTracingTargetBuffer.GlobalValue = targBuff;
            if (MainCamera)
                MainCamera.targetTexture = targBuff;
            if (rayTracingScreenOutputPlane)
                rayTracingScreenOutputPlane.texture = targBuff;
        }
        private RenderTexture SourceBuffer => firstIsSourceBuffer ? twoBuffers[0] : twoBuffers[1];
        private RenderTexture TargetBuffer => firstIsSourceBuffer ? twoBuffers[1] : twoBuffers[0];

        
        public void OnEnable()
        {
            ManagedOnEnable();
        }

        public override void ManagedOnEnable()
        {
            UpdateShaderVariables();
            instance = this;
        }

        public void SetDirty(string reason = "?")
        {
            _stableFrames = 0;
            _setDirtyReason = reason;
        }

        void UpdateShaderVariables()
        {
            _maxStepsInShader.GlobalValue = _maxSteps;
            _maxDistanceInShader.GlobalValue = _maxDistance;
        }

        #region Updates & Lerp

        [SerializeField] protected int stopUpdatingAfter = 500;
        private float _stableFrames = 0;
        private Vector3 _previousCamPosition = Vector3.zero;
        private Quaternion _previousCamRotation = Quaternion.identity;
        public bool playLerpAnimation;
        private bool lerpFinished;

        public void Update()
        {
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

            var isScreen = Target == RayRenderingTarget.Screen;

            if (rayTracingScreenBakingPlane)
                rayTracingScreenBakingPlane.SetActive(isScreen);

            if (rayTracingScreenOutputPlane)
                rayTracingScreenOutputPlane.gameObject.SetActive(isScreen);

            if (rayTracingOutputGo)
                rayTracingOutputGo.SetActive(isScreen);

            if (MainCamera)
            {
                var tf = MainCamera.transform;

                if (Target == RayRenderingTarget.Screen)
                {
                    cameraShakeDebug = (_previousCamPosition - tf.position).magnitude * 10 +
                                       Quaternion.Angle(_previousCamRotation, tf.rotation);

                    _previousCamPosition = tf.position;
                    _previousCamRotation = tf.rotation;
                    
                    cameraShakeDebug = 1 - Mathf.Clamp01(cameraShakeDebug);

                    if (_pauseAccumulation)
                        _stableFrames = 0;
                    else
                        _stableFrames = _stableFrames * cameraShakeDebug + cameraShakeDebug;
                }
                else
                    _stableFrames += 1;
                
                _RayTraceTraparency.GlobalValue = _stableFrames < 2 ? 1f : Mathf.Clamp(2f/_stableFrames, 0.001f, 0.5f);

                DENOISING.Enabled = _stableFrames < 16;//(_stopUpdatingAfter * 0.25f);

                MOTION_TRACING.Enabled = _stableFrames < 2;

                bool baked = _stableFrames > stopUpdatingAfter;

                if (Target == RayRenderingTarget.Volume)
                {
                    MainCamera.cullingMask = volumeTracingCameraMask;

                    if (!baked && volumeTracingBaker)
                        volumeTracingBaker.SetBakeDirty();
                }

                if (Target == RayRenderingTarget.Screen)
                {
                    MainCamera.cullingMask = rayTracingResultMask ;

                    MainCamera.clearFlags = CameraClearFlags.Nothing;
                    
                    MainCamera.enabled = !baked;

                    if (MainCamera.enabled)
                    {
                        Swap();
                    }
                }
                else
                {
                    MainCamera.clearFlags = CameraClearFlags.SolidColor;
                    MainCamera.targetTexture = null;
                    MainCamera.enabled = true;
                }
            }
        }

        private float cameraShakeDebug;

        [SerializeField] private RayMarchingConfigs configs;
        
        LerpData lerpData = new LerpData();
        
        public void Portion(LerpData ld)
        {
            if (lerpFinished)
                return;

            _rayMarchSmoothness.Portion(ld, smoothness.Value);
            _rayMarchShadowSoftness.Portion(ld, shadowSoftness.Value);
            _sunLightColor.Portion(ld);
            _skyColor.Portion(ld);
            _fogColor.Portion(ld);
            _RayTraceDepthOfField.Portion(ld, DOFdistance.Value);
            DOFTargetStrength.Portion(ld);

            if (godModeCamera)
                godModeCamera.Portion(ld);

            if (sceneConfiguration)
                sceneConfiguration.Portion(ld);
        }

        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (lerpFinished)
                return;

            _rayMarchSmoothness.Lerp(ld, canSkipLerp || UseRayTracing);
            _rayMarchShadowSoftness.Lerp(ld, canSkipLerp || UseRayTracing);
            _sunLightColor.Lerp(ld, canSkipLerp);
            _skyColor.Lerp(ld, canSkipLerp);
            _fogColor.Lerp(ld, canSkipLerp);
            RenderSettings.fogColor = _fogColor.CurrentValue;

            _RayTraceDepthOfField.Lerp(ld, canSkipLerp);
            DOFTargetStrength.Lerp(ld, canSkipLerp);

            if (godModeCamera)
                godModeCamera.Lerp(ld, canSkipLerp);

            if (sceneConfiguration)
                sceneConfiguration.Lerp(ld, canSkipLerp);
            
            if (ld.MinPortion == 1)
            {
                lerpFinished = true;
                playLerpAnimation = false;

                if (godModeCamera && godModeCamera.mode != GodMode.Mode.FPS)
                    godModeCamera.mode = GodMode.Mode.FPS;
            }
        }

        #endregion

        #region Inspector
        private bool _pauseAccumulation;

        private string _setDirtyReason;

        public static RayRenderingManager inspected;

        public override bool SaveOnEdit => false;

        private bool _showSavedConfigs;
        private bool _showDependencies;

        public override bool Inspect()
        {
            var changed = false;

            inspected = this;

            pegi.toggleDefaultInspector(this);

            if (!MainCamera)
            {
                "God Mode".edit(ref godModeCamera);

                if (icon.Search.Click().nl())
                    godModeCamera = FindObjectOfType<GodMode>();

                return false;
            }

            pegi.toggle(ref _pauseAccumulation, icon.Play, icon.Pause);

            var trg = Target;
            if ("Target".editEnum(60, ref trg).nl())
                Target = trg;

            if ("Dependencies".foldout(ref _showDependencies).nl())
            {

                if (Target == RayRenderingTarget.Volume)
                {
                    "VOL Camera Mask".edit_Property(() => volumeTracingCameraMask, this).nl();

                    if (!volumeTracingBaker)
                        "Volume".edit(60, ref volumeTracingBaker).nl();
                }

                if (Target == RayRenderingTarget.Screen)
                {
                    "SS Camera Mask".edit_Property(() => rayTracingResultMask, this).nl();
                }

                if (MainCamera)
                {
                    var depthMode = MainCamera.depthTextureMode;

                    if ("Depth Mode".editEnumFlags(90, ref depthMode).nl())
                        MainCamera.depthTextureMode = depthMode;
                }

                if (!rayTracingScreenBakingPlane)
                    "Ray Tracing Screen Baking".edit(ref rayTracingScreenBakingPlane).nl();

                if (!rayTracingScreenOutputPlane)
                    "Ray Tracing Screen Output Plane".edit(ref rayTracingScreenOutputPlane).nl();

                if (!rayTracingOutputGo)
                    "Output".edit(ref rayTracingOutputGo).nl();

                "Scene config".edit(ref sceneConfiguration).nl();
            }

            if (UseRayTracing)
            {
                "RAY-TRACING [frms: {0} | stability: {1}]".F((int)_stableFrames, cameraShakeDebug).write(PEGI_Styles.ListLabel);
                if (icon.PreviewShader.Click("Switch to Ray-Marching").nl())
                    _usingRayMarching.Enabled = true;
            }
            else
            {
                "RAY-MARCHING".write(PEGI_Styles.ListLabel);
                if (icon.OriginalShader.Click("Switch to Ray-Tacing").nl())
                    UseRayTracing = true;
            }

            if (_usingRayMarching.Enabled)
            {
                "Max Steps".edit(ref _maxSteps, 1, 400).nl(ref changed);

                "Max Distance".edit(ref _maxDistance, 1, 50000).nl(ref changed);

                "Smoothness:".nl();
                smoothness.Inspect().nl(ref changed);

                "Shadow Softness".nl();
                shadowSoftness.Inspect().nl(ref changed);
            }
            else
            {
                _rayTraceUseDielecrtic.Inspect().nl(ref changed);
                _rayTraceUseCheckerboard.Inspect().nl(ref changed);
            }

            "DOF".nl();
            DOFdistance.Inspect().nl(ref changed);
            var targ = DOFTargetStrength.TargetValue;
            if ("DOF Strength".edit(90, ref targ, 0.0001f, 3f).nl(ref changed))
                DOFTargetStrength.TargetValue = targ;

            "Light Color".edit(ref _sunLightColor.targetValue).nl(ref changed);
            "Sky Color".edit(ref _skyColor.targetValue).nl(ref changed);
            "Fog Color".edit(ref _fogColor.targetValue).nl(ref changed);
            
            if (changed)
            {
                lerpFinished = false;
                this.SkipLerp(lerpData);
                lerpFinished = true;
            }

            if ("Configs".foldout(ref _showSavedConfigs).nl())
                ConfigurationsListBase.Inspect(ref configs).changes(ref changed);

            if (changed)
            {
                UpdateShaderVariables();
                _stableFrames = 0;
            }

            if (playLerpAnimation)
            {
                "Lerp is Active".writeWarning();
                "Dominant: {0} [{1}]".F(lerpData.dominantParameter, lerpData.MinPortion).nl();
                pegi.nl();
            }
            else
                "Lerp Done: {0} [{1}] | Dirty from: {2}".F(lerpData.dominantParameter, lerpData.MinPortion, _setDirtyReason).nl();

            if (godModeCamera && godModeCamera.mode == GodMode.Mode.STATIC && "Edit Camera".Click().nl())
                godModeCamera.mode = GodMode.Mode.FPS;

            return changed;
        }

        public override string NameForDisplayPEGI() => "Ray Rendering";

        #endregion

        #region Encode & Decode

        public override CfgEncoder Encode()
        {
            var cody = new CfgEncoder()
                .Add_Bool("useRT", UseRayTracing)
                .Add("col", _sunLightColor.TargetValue)
                .Add("sky", _skyColor.TargetValue)
                .Add("fog", _fogColor.TargetValue)
                .Add("gm", godModeCamera)
                .Add("targ", (int)Target)
                .Add("sc", sceneConfiguration)
                .Add("dofD", DOFdistance)
                .Add("dofPow", DOFTargetStrength.TargetValue);

            if (MainCamera)
                cody.Add("depth", (int)MainCamera.depthTextureMode);

            if (_usingRayMarching.Enabled) cody
                .Add("sm", smoothness)
                .Add("shSo", shadowSoftness);
                    
            if (UseRayTracing) cody
                .Add_Bool("diEl", _rayTraceUseDielecrtic.Enabled)
                .Add_Bool("rtCB", _rayTraceUseCheckerboard.Enabled);

            return cody;
        }

        public override bool Decode(string tg, string data)
        {
            switch (tg)
            {
                case "sm": smoothness.Decode(data); break;
                case "col": _sunLightColor.TargetValue = data.ToColor(); break;
                case "shSo": shadowSoftness.Decode(data); break;
                case "sky": _skyColor.TargetValue = data.ToColor(); break;
                case "fog": _fogColor.TargetValue = data.ToColor(); break;
                case "gm": godModeCamera.Decode(data); break;
                case "targ": Target = (RayRenderingTarget)data.ToInt(); break;
                case "depth": MainCamera.depthTextureMode = (DepthTextureMode)data.ToInt(); break;
                case "dofD": DOFdistance.Decode(data); break;
                case "dofPow": DOFTargetStrength.TargetValue = data.ToFloat(); break;
                case "useRT": UseRayTracing = data.ToBool(); break;
                case "sc": sceneConfiguration.Decode(data); break;
                case "diEl": _rayTraceUseDielecrtic.Enabled = data.ToBool(); break;
                case "rtCB": _rayTraceUseCheckerboard.Enabled = data.ToBool(); break;
                default: return sceneConfiguration.Decode(tg, data);
            }
            return true;
        }

        public override void Decode(string data)
        {
            new CfgDecoder(data).DecodeTagsFor(this);
            playLerpAnimation = true;
            lerpFinished = false;
            if (godModeCamera)
                godModeCamera.mode = GodMode.Mode.LERP;
        }

        #endregion
    }

#if UNITY_EDITOR
    [CustomEditor(typeof(RayRenderingManager))]
    public class RayMarchingManagerDrawer : PEGI_Inspector_Mono<RayRenderingManager> { }
#endif

}