using System;
using PlayerAndEditorGUI;
using QuizCannersUtilities;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace RayMarching
{

    [ExecuteAlways]
    public class RayRenderingManager : MonoBehaviour, IPEGI, ICfg, ILinkedLerping
    {


        //https://github.com/keijiro/ParticleMotionVector // Maybe just get previous _WorldToCamera matrix if object is expected to be static.
        // 

        public static RayRenderingManager instance;

        [Header("Common")]

        public Camera mainCamera;


        LinkedLerp.MaterialColor _sunLightColor = new LinkedLerp.MaterialColor("_RayMarchLightColor", Color.grey, 10);
        LinkedLerp.MaterialColor _skyColor = new LinkedLerp.MaterialColor("_RayMarchSkyColor", Color.grey, 10);
        LinkedLerp.ColorValue _fogColor = new LinkedLerp.ColorValue("Fog");
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
        LinkedLerp.MaterialFloat _RayTraceDepthOfField = new LinkedLerp.MaterialFloat("_RayTraceDofDist", 1f); // x - distance 
        [NonSerialized] private QcUtils.DynamicRangeFloat DOFdistance = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);

        [NonSerialized] private LinkedLerp.MaterialFloat DOFTargetStrength = new LinkedLerp.MaterialFloat("_RayTraceDOF", 0.0001f);


        ShaderProperty.FloatValue _RayTraceTraparency = new ShaderProperty.FloatValue("_RayTraceTransparency");

        ShaderProperty.ShaderKeyword _rayTraceUseDielecrtic = new ShaderProperty.ShaderKeyword("RT_USE_DIELECTRIC");



        public void SetDirty()
        {
            _stableFrames = 0;
        }

        void UpdateShadeVariables()
        {
            _maxStepsInShader.GlobalValue = _maxSteps;
            _maxDistanceInShader.GlobalValue = _maxDistance;
        }

        void OnEnable()
        {
            UpdateShadeVariables();
            instance = this;
        }

        #region Linked Lerp

        private float _stableFrames = 0;
        private Vector3 _previousCamPosition = Vector3.zero;
        private Quaternion _previousCamRotation = Quaternion.identity;

        public void Update()
        {
            ld.Reset();

            Portion(ld);

            Lerp(ld, false);

            
            if (mainCamera)
            {
                var tf = mainCamera.transform;

                float diff =(_previousCamPosition - tf.position).magnitude*10 +
                    Quaternion.Angle(_previousCamRotation, tf.rotation);
                    ;

                _previousCamRotation = tf.rotation;
                _previousCamPosition = tf.position;

                diff = 1 - Mathf.Clamp01(diff);

                _stableFrames = _stableFrames * diff + diff;

                _RayTraceTraparency.GlobalValue = _stableFrames < 2 ? 1f : Mathf.Clamp(2f/_stableFrames, 0.01f, 0.5f); 
            }

        }

        [SerializeField] private RayMarchingConfigs configs;
        
        LerpData ld = new LerpData();
        
        public void Portion(LerpData ld)
        {
            _rayMarchSmoothness.Portion(ld, smoothness.Value);
            _sunLightColor.Portion(ld);
            _rayMarchShadowSoftness.Portion(ld, shadowSoftness.Value);
            _skyColor.Portion(ld);
            _fogColor.Portion(ld);
            _RayTraceDepthOfField.Portion(ld, DOFdistance.Value);
            DOFTargetStrength.Portion(ld);
        }

        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            _rayMarchSmoothness.Lerp(ld, canSkipLerp || useRayTracing);
            _rayMarchShadowSoftness.Lerp(ld, canSkipLerp || useRayTracing);

            _sunLightColor.Lerp(ld, canSkipLerp);
            _skyColor.Lerp(ld, canSkipLerp);

            _fogColor.Lerp(ld, canSkipLerp);
            RenderSettings.fogColor = _fogColor.CurrentValue;

            _RayTraceDepthOfField.Lerp(ld, canSkipLerp);
            DOFTargetStrength.Lerp(ld, canSkipLerp);
        }

        

        #endregion
        
        #region Inspector
        public static RayRenderingManager inspected;
        
        public bool Inspect()
        {

            var changed = false;

            inspected = this;

            pegi.toggleDefaultInspector(this);

            if (!mainCamera)
                "Main Camera".edit(ref mainCamera).nl();

            if (useRayTracing)
            {
                "RAY-TRACING [frms: {0}]".F((int)_stableFrames).write(PEGI_Styles.ListLabel);
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
                if ("DOF Strength".edit(90, ref trg, 0.0001f, 0.1f).nl(ref changed))
                    DOFTargetStrength.TargetValue = trg;


                DOFTargetStrength.Inspect().nl();

                _rayTraceUseDielecrtic.Inspect().nl(ref changed);
            }

            "Light Color".edit(ref _sunLightColor.targetValue).nl(ref changed);
            "Sky Color".edit(ref _skyColor.targetValue).nl(ref changed);
            "Fog Color".edit(ref _fogColor.targetValue).nl(ref changed);
            
            ConfigurationsListBase.Inspect(ref configs).changes(ref changed);

            if (changed)
            {
                UpdateShadeVariables();
                _stableFrames = 0;
                this.SkipLerp(ld);
            }

            return changed;
        }
        #endregion

        #region Encode & Decode

        public CfgEncoder Encode()
        {
            var cody = new CfgEncoder()
                .Add_Bool("useRT", useRayTracing)
                .Add("col", _sunLightColor.TargetValue)
                .Add("sky", _skyColor.TargetValue)
                .Add("fog", _fogColor.TargetValue);

            if (!useRayTracing) cody
                .Add("sm", smoothness)
                .Add("shSo", shadowSoftness);
                    
            if (useRayTracing) cody
                .Add("dofD", DOFdistance)
                .Add("dofPow", DOFTargetStrength.TargetValue);

            return cody;
        }

        public bool Decode(string tg, string data)
        {
            switch (tg)
            {
                case "sm": smoothness.Decode(data); break;
                case "col": _sunLightColor.TargetValue = data.ToColor(); break;
                case "shSo": shadowSoftness.Decode(data); break;
                case "sky": _skyColor.TargetValue = data.ToColor(); break;
                case "fog": _fogColor.TargetValue = data.ToColor(); break;
                case "dofD": DOFdistance.Decode(data); break;
                case "dofPow": DOFTargetStrength.TargetValue = data.ToFloat(); break;
                case "useRT": useRayTracing = data.ToBool(); break;
                default: return false;
            }

            return true;
        }

        public void Decode(string data) => new CfgDecoder(data).DecodeTagsFor(this);
        
        #endregion
    }





#if UNITY_EDITOR
    [CustomEditor(typeof(RayRenderingManager))]
    public class RayMarchingManagerDrawer : PEGI_Inspector_Mono<RayRenderingManager> { }
#endif

}