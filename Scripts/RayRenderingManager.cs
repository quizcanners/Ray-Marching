using System;
using PlayerAndEditorGUI;
using PlaytimePainter.Examples;
using QuizCannersUtilities;
using UnityEngine;
using NodeNotes_Visual;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace RayMarching
{
    
    public class RayRenderingManager : NodeNodesNeedEnableAbstract, IPEGI, ICfg, ILinkedLerping
    {

        public override string ClassTag => "RtxMgmt";

        public static RayRenderingManager instance;

        [Header("Common")]

        public GodMode godModeCamera;
        public Camera MainCamera => godModeCamera ? godModeCamera.MainCam : null;

        public PrimitiveObject cube0, cube1, cube2, cube3, cube4, cube5, sphere0, sphere1;
        
        LinkedLerp.MaterialColor _sunLightColor = new LinkedLerp.MaterialColor("_RayMarchLightColor", Color.grey, 10);
        LinkedLerp.MaterialColor _skyColor = new LinkedLerp.MaterialColor("_RayMarchSkyColor", Color.grey, 10);
        LinkedLerp.ColorValue _fogColor = new LinkedLerp.ColorValue("Fog", speed: 10);
        [NonSerialized] private bool useRayTracing = true;
        
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
            PathTracingSourceBuffer.GlobalValue = SourceBuffer;
            PathTracingTargetBuffer.GlobalValue = TargetBuffer;
            if (MainCamera)
                MainCamera.targetTexture = TargetBuffer;
        }
        private RenderTexture SourceBuffer => firstIsSourceBuffer ? twoBuffers[0] : twoBuffers[1];
        private RenderTexture TargetBuffer => firstIsSourceBuffer ? twoBuffers[1] : twoBuffers[0];

        
        public void OnEnable()
        {
            ManagedOnEnable();
        }

        public override void ManagedOnEnable()
        {
            UpdateShadeVariables();
            instance = this;
        }

        public void SetDirty()
        {
            _stableFrames = 0;
        }

        void UpdateShadeVariables()
        {
            _maxStepsInShader.GlobalValue = _maxSteps;
            _maxDistanceInShader.GlobalValue = _maxDistance;
        }

        #region Linked Lerp

        [SerializeField] private int _stopUpdatingAfter = 100;
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
            
            if (MainCamera)
            {
                var tf = MainCamera.transform;

                cameraShakeDebug = (_previousCamPosition - tf.position).magnitude * 10 +
                    Quaternion.Angle(_previousCamRotation, tf.rotation);

                _previousCamPosition = tf.position;
                _previousCamRotation = tf.rotation;
               

                cameraShakeDebug = 1 - Mathf.Clamp01(cameraShakeDebug);

                if (_pauseAccumulation)
                    _stableFrames = 0;
                else
                    _stableFrames = _stableFrames * cameraShakeDebug + cameraShakeDebug;

                _RayTraceTraparency.GlobalValue = _stableFrames < 2 ? 1f : Mathf.Clamp(2f/_stableFrames, 0.001f, 0.5f);

                DENOISING.Enabled = _stableFrames < 16;//(_stopUpdatingAfter * 0.25f);

                MOTION_TRACING.Enabled = _stableFrames < 2;  

                MainCamera.enabled = _stableFrames < _stopUpdatingAfter;

                if (MainCamera.enabled)
                {
                    Swap();
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


            cube0.Portion(ld);
            cube1.Portion(ld);
            cube2.Portion(ld);
            cube3.Portion(ld);
            cube4.Portion(ld);
            cube5.Portion(ld);
            sphere0.Portion(ld);
            sphere1.Portion(ld);
        }

        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (lerpFinished)
                return;

            _rayMarchSmoothness.Lerp(ld, canSkipLerp || useRayTracing);
            _rayMarchShadowSoftness.Lerp(ld, canSkipLerp || useRayTracing);
            _sunLightColor.Lerp(ld, canSkipLerp);
            _skyColor.Lerp(ld, canSkipLerp);
            _fogColor.Lerp(ld, canSkipLerp);
            RenderSettings.fogColor = _fogColor.CurrentValue;

            _RayTraceDepthOfField.Lerp(ld, canSkipLerp);
            DOFTargetStrength.Lerp(ld, canSkipLerp);

            if (godModeCamera)
                godModeCamera.Lerp(ld, canSkipLerp);

            cube0.Lerp(ld, canSkipLerp);
            cube1.Lerp(ld, canSkipLerp);
            cube2.Lerp(ld, canSkipLerp);
            cube3.Lerp(ld, canSkipLerp);
            cube4.Lerp(ld, canSkipLerp);
            cube5.Lerp(ld, canSkipLerp);
            sphere0.Lerp(ld, canSkipLerp);
            sphere1.Lerp(ld, canSkipLerp);

            if (ld.MinPortion == 1)
            {
                lerpFinished = true;
                playLerpAnimation = false;

                if (godModeCamera)
                    godModeCamera.mode = GodMode.Mode.STATIC;
                
            }
        }

        #endregion

        #region Inspector
        private bool _pauseAccumulation;

        public static RayRenderingManager inspected;
        
        public bool Inspect()
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

            if (useRayTracing)
            {
                pegi.toggle(ref _pauseAccumulation, icon.Play, icon.Pause);

                "RAY-TRACING [frms: {0} | {1}]".F((int)_stableFrames, cameraShakeDebug).write(PEGI_Styles.ListLabel);
                if (icon.PreviewShader.Click("Switch to Ray-Marching").nl())
                    useRayTracing = false;
            }
            else
            {
                "RAY-MARCHING".write(PEGI_Styles.ListLabel);
                if (icon.OriginalShader.Click("Switch to Ray-Tacing").nl())
                    useRayTracing = true;
            }

            if (!useRayTracing)
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

                "DOF".nl();
                DOFdistance.Inspect().nl(ref changed);
                var trg = DOFTargetStrength.TargetValue;
                if ("DOF Strength".edit(90, ref trg, 0.0001f, 3f).nl(ref changed))
                    DOFTargetStrength.TargetValue = trg;

                _rayTraceUseDielecrtic.Inspect().nl(ref changed);
                _rayTraceUseCheckerboard.Inspect().nl(ref changed);
            }

            "Light Color".edit(ref _sunLightColor.targetValue).nl(ref changed);
            "Sky Color".edit(ref _skyColor.targetValue).nl(ref changed);
            "Fog Color".edit(ref _fogColor.targetValue).nl(ref changed);
            
            if (changed)
            {
                lerpFinished = false;
                this.SkipLerp(lerpData);
            }

            ConfigurationsListBase.Inspect(ref configs).changes(ref changed);

            if (changed)
            {
                UpdateShadeVariables();
                _stableFrames = 0;
            }

            if (playLerpAnimation)
            {
                "Lerp is Active".writeWarning();
                "Dominant: {0} [{1}]".F(lerpData.dominantParameter, lerpData.MinPortion).nl();
                pegi.nl();
            }
            else
                "Lerp Done: {0} [{1}]".F(lerpData.dominantParameter, lerpData.MinPortion).nl();

            if (godModeCamera && godModeCamera.mode == GodMode.Mode.STATIC && "Edit Camera".Click().nl())
                godModeCamera.mode = GodMode.Mode.FPS;

            return changed;
        }
        #endregion

        #region Encode & Decode

        public override CfgEncoder Encode()
        {
            var cody = new CfgEncoder()
                .Add_Bool("useRT", useRayTracing)
                .Add("col", _sunLightColor.TargetValue)
                .Add("sky", _skyColor.TargetValue)
                .Add("fog", _fogColor.TargetValue)
                .Add("gm", godModeCamera);

            if (!useRayTracing) cody
                .Add("sm", smoothness)
                .Add("shSo", shadowSoftness);
                    
            if (useRayTracing) cody
                .Add("dofD", DOFdistance)
                .Add("dofPow", DOFTargetStrength.TargetValue)
                .Add_Bool("diEl", _rayTraceUseDielecrtic.Enabled)
                .Add_Bool("rtCB", _rayTraceUseCheckerboard.Enabled);

            cody.Add("c0", cube0)
                .Add("c1", cube1)
                .Add("c2", cube2)
                .Add("c3", cube3)
                .Add("c4", cube4)
                .Add("c5", cube5)
                .Add("s0", sphere0)
                .Add("s1", sphere1);

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
                case "dofD": DOFdistance.Decode(data); break;
                case "dofPow": DOFTargetStrength.TargetValue = data.ToFloat(); break;
                case "useRT": useRayTracing = data.ToBool(); break;
                case "c0": cube0.Decode(data); break;
                case "c1": cube1.Decode(data); break;
                case "c2": cube2.Decode(data); break;
                case "c3": cube3.Decode(data); break;
                case "c4": cube4.Decode(data); break;
                case "c5": cube5.Decode(data); break;
                case "s0": sphere0.Decode(data); break;
                case "s1": sphere1.Decode(data); break;
                case "diEl": _rayTraceUseDielecrtic.Enabled = data.ToBool(); break;
                case "rtCB": _rayTraceUseCheckerboard.Enabled = data.ToBool(); break;
                default: return false;
            }

            return true;
        }

        public override void Decode(string data)
        {
            new CfgDecoder(data).DecodeTagsFor(this);
            playLerpAnimation = true;
            lerpFinished = false;
            if (godModeCamera)
                godModeCamera.mode = GodMode.Mode.STATIC;
        }

        #endregion
    }

#if UNITY_EDITOR
    [CustomEditor(typeof(RayRenderingManager))]
    public class RayMarchingManagerDrawer : PEGI_Inspector_Mono<RayRenderingManager> { }
#endif

}