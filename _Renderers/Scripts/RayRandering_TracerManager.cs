using QuizCanners.CfgDecode;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    [Serializable]
    public class RayRandering_TracerManager : IPEGI, ILinkedLerping, ICfgCustom, IPEGI_ListInspect
    {
        [SerializeField] public RayRendering_TracerConfigs configs;
        [SerializeField] private RayRenderingTarget _target;

        private ShaderProperty.ShaderKeyword USING_RAY_MARCHING = new ShaderProperty.ShaderKeyword("_IS_RAY_MARCHING");

        public RayRenderingTarget Target
        {
            get { return _target; }
            set
            {
                _target = value;
                USING_RAY_MARCHING.Enabled = value == RayRenderingTarget.RayMarching;
            }
        }

        [Header("Ray-Marthing")]
        [SerializeField] private float _maxSteps = 50;
        [SerializeField] private float _maxDistance = 10000;
        [NonSerialized] private QcUtils.DynamicRangeFloat smoothness = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);
        [NonSerialized] private QcUtils.DynamicRangeFloat shadowSoftness = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);

        private ShaderProperty.FloatValue MAX_STEPS_IN_SHADER = new ShaderProperty.FloatValue("_maxRayMarchSteps");
        private ShaderProperty.FloatValue MAX_DISTANCE_IN_SHADER = new ShaderProperty.FloatValue("_MaxRayMarchDistance");
        private LinkedLerp.MaterialFloat RAY_MARCHSMOOTHNESS = new LinkedLerp.MaterialFloat("_RayMarchSmoothness", 1, 30);
        private LinkedLerp.MaterialFloat RAY_MARCH_SHADOW_SMOOTHNESS = new LinkedLerp.MaterialFloat("_RayMarchShadowSoftness", 1, 30);

        [Header("Ray-Tracing")]
        [NonSerialized] private QcUtils.DynamicRangeFloat DOFdistance = new QcUtils.DynamicRangeFloat(min: 0.01f, max: 50, value: 1);
        [NonSerialized] private LinkedLerp.MaterialFloat RAY_TRACE_DOF = new LinkedLerp.MaterialFloat("_RayTraceDofDist", startingValue: 1f, startingSpeed: 100f); // x - distance 
        [NonSerialized] private LinkedLerp.MaterialFloat DOF_STRENGTH = new LinkedLerp.MaterialFloat("_RayTraceDOF", startingValue: 0.0001f, startingSpeed: 10);
        [NonSerialized] private ShaderProperty.ShaderKeyword RAY_TRACE_DIALECTRIC = new ShaderProperty.ShaderKeyword("RT_USE_DIELECTRIC");
        [NonSerialized] private ShaderProperty.ShaderKeyword RAY_TRACE_CHECKERBOARD = new ShaderProperty.ShaderKeyword("RT_USE_CHECKERBOARD");

        public void OnConfigurationChanged()
        {
            MAX_STEPS_IN_SHADER.GlobalValue = _maxSteps;
            MAX_DISTANCE_IN_SHADER.GlobalValue = _maxDistance;
        }

        #region Encode & Decode
        public CfgEncoder Encode()
        {
            var cody = new CfgEncoder()
                .Add("targ", (int)Target)
                .Add("dofD", DOFdistance)
                .Add("dofPow", DOF_STRENGTH.TargetValue);

            if (USING_RAY_MARCHING.Enabled) cody
                .Add("sm", smoothness)
                .Add("shSo", shadowSoftness);

            if (Target != RayRenderingTarget.RayMarching) 
                cody
                .Add_Bool("diEl", RAY_TRACE_DIALECTRIC.Enabled)
                .Add_Bool("rtCB", RAY_TRACE_CHECKERBOARD.Enabled);

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
                case "dofPow": DOF_STRENGTH.TargetValue = data.ToFloat(); break;
                case "diEl": RAY_TRACE_DIALECTRIC.Enabled = data.ToBool(); break;
                case "rtCB": RAY_TRACE_CHECKERBOARD.Enabled = data.ToBool(); break;
            }
        }

        public void Decode(CfgData data)
        {
            new CfgDecoder(data).DecodeTagsFor(this);
        }

        #endregion

        #region Inspect
        public void Inspect()
        {

            pegi.nl();

            var changed = pegi.ChangeTrackStart();

            var trg = Target;
            if ("Target".editEnum(ref trg).nl())
                Target = trg;

            ConfigurationsSO_Base.Inspect(ref configs);


            if (Target == RayRenderingTarget.RayMarching || Target == RayRenderingTarget.Volume)
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
            
            if (Target == RayRenderingTarget.RayIntersection || Target == RayRenderingTarget.Volume)
            {
                "RAY-TRACING".nl(PEGI_Styles.ListLabel);

                RAY_TRACE_DIALECTRIC.Nested_Inspect().nl();
                RAY_TRACE_CHECKERBOARD.Nested_Inspect().nl();
            }

            if (Target != RayRenderingTarget.Volume)
            {
                "DOF".nl();
                pegi.Nested_Inspect(ref DOFdistance).nl();
                var targ = DOF_STRENGTH.TargetValue;
                if ("DOF Strength".edit(90, ref targ, 0.0001f, 3f).nl())
                    DOF_STRENGTH.TargetValue = targ;
            }

            if (changed)
                OnConfigurationChanged();
        }

        public void InspectInList(int ind, ref int edited)
        {
  
            if (icon.Enter.Click())
                edited = ind;

            var trg = Target;
            if (pegi.editEnum(ref trg))
                Target = trg;

            if (!configs)
                "CFG".edit(60, ref configs);
            else
                configs.InspectShortcut();

        }
        #endregion

        #region Lerps
        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            var isMarching = Target == RayRenderingTarget.RayMarching;

            RAY_MARCHSMOOTHNESS.Lerp(ld, canSkipLerp || !isMarching);
            RAY_MARCH_SHADOW_SMOOTHNESS.Lerp(ld, canSkipLerp || !isMarching);

            RAY_TRACE_DOF.Lerp(ld, canSkipLerp);
            DOF_STRENGTH.Lerp(ld, canSkipLerp);
        }

        public void Portion(LerpData ld)
        {
            RAY_MARCHSMOOTHNESS.Portion(ld, smoothness.Value);
            RAY_MARCH_SHADOW_SMOOTHNESS.Portion(ld, shadowSoftness.Value);

            RAY_TRACE_DOF.Portion(ld, DOFdistance.Value);
            DOF_STRENGTH.Portion(ld);
        }
        #endregion

    }
}
